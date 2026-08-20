# frozen_string_literal: true

class PostReplacement < ApplicationRecord
  class ProcessingError < StandardError; end
  # Raised instead of silently backing up from bare metadata - approving/transferring onto a post
  # whose file is already gone is destructive enough (no real backup possible) that it needs an
  # admin to explicitly opt in via force:, not just whoever happens to be approving.
  class MissingSourceFileError < ProcessingError; end

  TAGS_TO_REMOVE_AFTER_ACCEPT = %w[better_version_at_source].freeze
  HIGHLIGHTED_TAGS = %w[better_version_at_source avoid_posting conditional_dnp].freeze
  # Reason stamped on a backup created from the post's real file (see create_backup_replacement) -
  # reserved (see reason_is_not_reserved) so it can't be spoofed by something a user typed.
  ORIGINAL_FILE_REASON = "Original File"
  # Reason stamped on a backup created with no real file to copy (see create_backup_replacement)
  # - reserved so it reliably marks that state (see #metadata_only?) instead of colliding with
  # something a user typed.
  METADATA_ONLY_REASON = "Original Metadata (file missing)"
  has_media_asset(:post_replacement_media_asset)

  belongs_to(:post)
  belongs_to_user(:creator, ip: true, clones: :updater)
  resolvable(:updater)
  resolvable(:destroyer)
  belongs_to_user(:approver, optional: true)
  belongs_to_user(:rejector, optional: true)
  belongs_to_user(:uploader_on_approve, foreign_key: :uploader_id_on_approve, optional: true)
  attr_accessor(:file, :direct_url, :tags, :is_backup, :as_pending)

  validate(:user_is_not_limited, on: :create)
  validate(:post_is_valid, on: :create)
  validate(:set_file_name, on: :create, if: :is_direct?)
  validate(:direct_url_is_whitelisted, on: :create)
  validates(:reason, length: { minimum: 5, maximum: 150 }, presence: true, on: :create)
  validate(:reason_is_not_reserved, on: :create)
  validates(:rejection_reason, length: { maximum: 150 }, if: :rejected?)
  validate(:validate_media_asset_status, on: :create)

  before_create(:fill_sequence_number)
  after_create(-> { post.update_index })
  before_destroy(:log_destroy)
  after_destroy(-> { post.update_index })
  after_commit(:delete_files, on: :destroy)

  scope(:penalized, -> { where(penalize_uploader_on_approve: true) })
  scope(:not_penalized, -> { where(penalize_uploader_on_approve: false) })

  enum(:status, %w[uploading pending original rejected approved promoted].index_with(&:to_s))
  delegate(:storage_id, to: :media_asset)

  def delete_files
    media_asset&.expunge!(destroyer)
  end

  def validate_media_asset_status
    status = media_asset.status
    status_message = media_asset.pretty_status
    return unless %w[duplicate failed expunged].include?(status)
    errors.add(:base, status_message)
  end

  def direct_url_parsed
    return nil unless direct_url =~ %r{\Ahttps?://}i
    begin
      Addressable::URI.heuristic_parse(direct_url)
    rescue Addressable::URI::InvalidURIError
      nil
    end
  end

  def direct_url_is_whitelisted
    return true if direct_url_parsed.blank?
    valid, reason = UploadWhitelist.is_whitelisted?(direct_url_parsed, creator)
    unless valid
      errors.add(:source, "is not whitelisted: #{reason}")
      return false
    end
    true
  end

  def reason_is_not_reserved
    return if original?
    normalized = reason.to_s.strip.squeeze(" ")
    if normalized.casecmp(ORIGINAL_FILE_REASON) == 0 || normalized.casecmp(METADATA_ONLY_REASON) == 0
      errors.add(:base, "You cannot use '#{normalized}' as a reason.")
    end
  end

  def self.calculate_sequence_number(post_id)
    1 + where(post_id: post_id).maximum(:sequence_number).to_i
  end

  # The original backup is numbered 0 by its status marker; every other replacement gets
  # 1..N in creation order. Assigned once here and never touched again, including by
  # later status changes (e.g. "Reset To" re-approving the original backup in place).
  def fill_sequence_number
    self.sequence_number = original? ? 0 : self.class.calculate_sequence_number(post_id)
  end

  module PostMethods
    def post_is_valid
      if post.is_deleted?
        errors.add(:post, "is deleted")
        false
      end
    end
  end

  def user_is_not_limited
    return true if original?
    uploadable = creator.can_upload_with_reason
    if uploadable != true
      errors.add(:creator, User.upload_reason_string(uploadable))
      throw(:abort)
    end

    # Janitor bypass replacement limits
    return true if creator.is_janitor?

    if post.replacements.for_creator(creator_id).where.gt(created_at: 1.day.ago).count > Config.instance.post_replacement_per_day_limit
      errors.add(:creator, "has already suggested too many replacements for this post today")
      throw(:abort)
    end
    if post.replacements.pending.for_creator(creator_id).count > Config.instance.post_replacement_per_post_limit
      errors.add(:creator, "already has too many pending replacements for this post")
      throw(:abort)
    end
    true
  end

  def source_list
    source.split("\n").uniq.compact_blank
  end

  def log_destroy
    PostEvent.add!(post_id, destroyer, :replacement_deleted, post_replacement_id: id, md5: md5, storage_id: storage_id)
  end

  module StorageMethods
    def set_file_name
      if file.present?
        self.file_name = file.try(:original_filename) || File.basename(file.path)
      else
        if direct_url_parsed.blank? && direct_url.present?
          errors.add(:direct_url, "is invalid")
          throw(:abort)
        end
        if direct_url_parsed.blank?
          errors.add(:base, "No file or replacement URL provided")
          throw(:abort)
        end
        self.file_name = direct_url_parsed.basename
      end
    end

    def replacement_file_path
      media_asset.file_path
    end

    def replacement_thumb_path
      media_asset.find_variant!("thumb").file_path
    end

    def replacement_file_url(user)
      media_asset.file_url(user: user)
    end

    def replacement_thumb_url(user)
      media_asset.find_variant!("thumb").file_url(user: user)
    end
  end

  module ProcessingMethods
    # promoting
    def create_upload(replace: false)
      existing = UploadMediaAsset.duplicates_of(md5)
      if existing.any?
        existing.each do |asset|
          raise(ProcessingError, "UploadMediaAsset with md5=#{md5} and status=active already exists (id=#{asset.id}, post_id=#{asset.post.id})") if asset.post.present?
          asset.updater = creator
          asset.destroy # if the upload media asset has no post, it should be abandoned and not attached to anything
        end
      end
      Upload.create(new_upload_params(replace: replace))
    end

    # If the post's current file is already missing from storage, there's nothing to actually
    # back up. Rather than silently faking a backup from bare metadata (md5, dimensions, etc. -
    # none of which require reading the file itself), that's gated behind force: so it only
    # happens when an admin explicitly opts in (see approve!/transfer) - otherwise it raises
    # MissingSourceFileError so the caller can offer that choice instead of failing outright.
    def create_backup_replacement(force: false)
      source_asset = post.media_asset
      file_exists = source_asset.storage_manager.exists?(source_asset.file_path)
      if !file_exists && !force
        raise(MissingSourceFileError, "The post's original file is missing from storage - an admin must force this before it can be backed up.")
      end

      backup = nil
      begin
        if file_exists
          source_asset.open_file do |file|
            backup = post.replacements.new(checksum: post.md5, creator: post.uploader.resolvable(post.uploader_ip_addr), status: "original", file_name: "#{post.md5}.#{post.file_ext}", source: post.source, reason: ORIGINAL_FILE_REASON, is_backup: true)
            backup.media_asset.backup_post_id = post.id
            backup.media_asset.append_all!(file, save: false)
            backup.save!
          end
        else
          backup = post.replacements.new(checksum: post.md5, creator: post.uploader.resolvable(post.uploader_ip_addr), status: "original",
                                         file_name: "#{post.md5}.#{post.file_ext}", source: post.source,
                                         reason: METADATA_ONLY_REASON, is_backup: true)
          backup.media_asset.backup_post_id = post.id
          # skip_files stops the after_create variant-generation callback from trying (and failing) to
          # open a file that doesn't exist - it only affects this one save, not future loads of the record.
          backup.media_asset.skip_files = true
          backup.media_asset.assign_attributes(
            md5:              source_asset.md5,
            file_ext:         source_asset.file_ext,
            file_size:        source_asset.file_size,
            image_width:      source_asset.image_width,
            image_height:     source_asset.image_height,
            duration:         source_asset.duration,
            framecount:       source_asset.framecount,
            pixel_hash:       source_asset.pixel_hash,
            is_animated_png:  source_asset.is_animated_png,
            is_animated_gif:  source_asset.is_animated_gif,
            is_animated_webp: source_asset.is_animated_webp,
            status:           "active",
            status_message:   "metadata only (file missing)",
          )
          backup.save!
        end
      rescue Exception => e
        raise(ProcessingError, "Failed to create post file backup: #{e.message}")
      end
      raise(ProcessingError, "Could not create post file backup?") unless backup.present? && backup.valid?
      raise(ProcessingError, "Failed to create post file backup: #{backup.errors.full_messages.join('; ')}") unless backup.valid?(:status)
      backup
    end

    def approve!(approver, penalize_current_uploader:, force_missing_backup: false)
      unless %w[pending original rejected].include?(status)
        errors.add(:status, "must be pending, original, or rejected to approve")
        return
      end
      if metadata_only?
        errors.add(:status, "cannot be reset to - it's a metadata-only backup with no real file")
        return
      end
      errors.add(:post, "is deleted") if post.is_deleted?
      transaction do
        create_backup_replacement(force: force_missing_backup.to_s.truthy? && approver.is_admin?) if post.replacements.original.none?

        post.replacements.approved.find_each do |replacement|
          replacement.update_column(:status, replacement.sequence_number == 0 ? "original" : "rejected")
        end

        PostReplacement::TAGS_TO_REMOVE_AFTER_ACCEPT.each do |tag|
          post.remove_tag(tag)
        end

        previous_uploader = post.uploader
        previous_md5 = post.md5

        previous_media_asset = post.media_asset

        post.thumbnail_frame = nil
        post.source = "#{source}\n" + post.source
        post.uploader = creator.resolvable(creator_ip_addr)
        post.approver = approver
        post.save!

        self.previous_details = {
          width:  post.image_width,
          height: post.image_height,
          size:   post.file_size,
          ext:    post.file_ext,
          md5:    post.md5,
        }
        self.approver = approver
        self.updater = approver
        self.status = "approved"
        self.uploader_on_approve = previous_uploader
        self.penalize_uploader_on_approve = penalize_current_uploader.to_s.truthy?
        save!

        upload = create_upload(replace: true)
        raise(ProcessingError, "Failed to create upload: #{upload.errors.full_messages.join('; ')}") if upload.errors.any? || !upload.valid?
        raise(ProcessingError, "Failed to create media asset: #{upload.media_asset.errors.full_messages.join('; ')}") if upload.media_asset.errors.any? || !upload.media_asset.valid?

        post.update_column(:upload_media_asset_id, upload.upload_media_asset_id)
        post.reload_media_asset
        # update_all is used to avoid needing to load the user
        User.where(id: previous_uploader.id).update_all("own_post_replaced_count = own_post_replaced_count + 1")
        if penalize_current_uploader
          User.where(id: previous_uploader.id).update_all("own_post_replaced_penalize_count = own_post_replaced_penalize_count + 1")
        end

        x_scale = post.media_asset.image_width.to_f / previous_media_asset.image_width.to_f
        y_scale = post.media_asset.image_height.to_f / previous_media_asset.image_height.to_f

        post.notes.each do |note|
          note.rescale!(x_scale, y_scale, approver) # save! is called within each, and each loads the post
        end

        if post.md5 != previous_md5
          previous_media_asset.delete_all_files
          previous_media_asset.update(status: "replaced", updater: approver)
        end

        PostEvent.add!(post.id, approver, :replacement_accepted, post_replacement_id: id, old_md5: previous_md5, new_md5: md5)
      end
      creator.notify_for_upload(self, :replacement_approve) if creator_id != approver.id
      post.update_index
    end

    def toggle_penalize!(user)
      unless approved?
        errors.add(:status, "must be approved to penalize")
        return
      end

      if penalize_uploader_on_approve
        User.where(id: uploader_id_on_approve).update_all("own_post_replaced_penalize_count = own_post_replaced_penalize_count - 1")
      else
        User.where(id: uploader_id_on_approve).update_all("own_post_replaced_penalize_count = own_post_replaced_penalize_count + 1")
      end
      update(penalize_uploader_on_approve: !penalize_uploader_on_approve, updater: user)
    end

    def promote!(promoter)
      unless pending?
        errors.add(:status, "must be pending to promote")
        return
      end

      upload = transaction do
        upload = create_upload
        if upload.blank?
          raise(ProcessingError, "Failed to create upload")
        elsif upload.errors.any?
          raise(ProcessingError, "Failed to create upload: #{upload.errors.full_messages.join(', ')}")
        elsif upload.upload_media_asset.errors.any?
          raise(ProcessingError, "Failed to create media asset: #{upload.upload_media_asset.errors.full_messages.join(', ')}")
        elsif !upload.upload_media_asset.active?
          raise(ProcessingError, "Failed to create media asset: #{upload.upload_media_asset.status_message.presence || upload.upload_media_asset.status}")
        elsif upload.post.blank?
          raise(ProcessingError, "Failed to create post")
        elsif upload.post.errors.any?
          raise(ProcessingError, "Failed to create post: #{upload.post.errors.full_messages.join(', ')}")
        end

        update(status: "promoted", updater: promoter)
        PostEvent.add!(upload.post.id, promoter, :replacement_promoted, source_post_id: post_id, post_replacement_id: id)

        creator.notify_for_upload(self, :replacement_promote) if creator_id != promoter.id
        upload
      end
      upload.post.update_index
      upload
    end

    def reject!(user, reason = "")
      unless pending?
        errors.add(:status, "must be pending to reject")
        return
      end

      PostEvent.add!(post.id, user, :replacement_rejected, post_replacement_id: id)
      update(status: "rejected", rejector: user, rejection_reason: reason)
      User.where(id: creator_id).update_all("post_replacement_rejected_count = post_replacement_rejected_count + 1")
      creator.notify_for_upload(self, :replacement_reject) if creator_id != user.id
      post.update_index
    end

    # Moves this replacement to another post, preserving its status (a rejected replacement
    # stays rejected). Only pending/rejected replacements move; the destination must be a
    # different, non-deleted post that doesn't already hold this file. uploader_on_approve
    # isn't touched here - approve! always recomputes it from post.uploader at approval time,
    # so it naturally resolves against the destination post once post_id is reassigned.
    def transfer(new_post, user, force_missing_backup: false)
      unless pending? || rejected?
        errors.add(:status, "must be pending or rejected to transfer")
        return
      end
      if new_post.nil? || new_post.id == post_id
        errors.add(:post, "must be a different post")
        return
      end
      if new_post.is_deleted?
        errors.add(:post, "is deleted")
        return
      end
      if new_post.md5 == md5
        errors.add(:md5, "identical to the destination post's current file")
        return
      end
      if new_post.replacements.joins(:post_replacement_media_asset).exists?(post_replacement_media_assets: { md5: md5 })
        errors.add(:md5, "duplicate of existing replacement on post ##{new_post.id}")
        return
      end

      source_post = post

      transaction do
        # No-op if the destination already has one.
        if new_post.replacements.original.none?
          PostReplacement.new(post: new_post).create_backup_replacement(force: force_missing_backup.to_s.truthy? && user.is_admin?)
        end

        update_columns(post_id: new_post.id, sequence_number: self.class.calculate_sequence_number(new_post.id))
        reload # so `post` resolves to the destination for the caller (e.g. the redirect target)

        PostEvent.add!(new_post.id, user, :replacement_transferred, post_replacement_id: id, old_post: source_post.id, new_post: new_post.id)
        PostEvent.add!(source_post.id, user, :replacement_transferred, post_replacement_id: id, old_post: source_post.id, new_post: new_post.id)
      end

      source_post.update_index
      new_post.update_index
    rescue ActiveRecord::RecordNotUnique
      errors.add(:base, "Another replacement was transferred to that post at the same time; please retry") if errors.none?
    rescue ProcessingError => e
      errors.add(:base, "Failed to create backup on the destination post: #{e.message}") if errors.none?
    end
  end

  module PromotionMethods
    def new_upload_params(replace: false)
      {
        uploader:       creator.resolvable(creator_ip_addr),
        file:           media_asset.get_file,
        tag_string:     post.tag_string,
        rating:         post.rating,
        source:         "#{source}\n" + post.source,
        parent_id:      post.id,
        description:    post.description,
        locked_tags:    post.locked_tags,
        is_replacement: replace,
        replacement_id: id,
      }
    end
  end

  module SearchMethods
    def query_dsl
      super
        .field(:file_ext, "post_replacement_media_assets.file_ext") { |q| q.joins(:post_replacement_media_asset) }
        .field(:md5, "post_replacement_media_assets.md5") { |q| q.joins(:post_replacement_media_asset) }
        .field(:status)
        .field(:post_id)
        .field(:ip_addr, :creator_ip_addr)
        .user(%i[uploader_id_on_approve uploader_name_on_approve], :uploader_on_approve)
        .association(:creator)
        .association(:approver)
        .association(:rejector)
        .association(:uploader_on_approve) # no support for custom columns
    end

    def default_order
      order(arel_case(:status).when("pending").then(0)
                              .when("original").then(2)
                              .else(1)
                              .asc, id: :desc)
    end
  end

  def original_file_visible_to?(user)
    user.is_janitor?
  end

  def is_current?
    md5 == post.md5
  end

  # True for a backup created with no real file to copy (see create_backup_replacement) - reason
  # is reserved (see reason_is_not_reserved) so this can't be spoofed by a manually-typed reason.
  def metadata_only?
    original? && reason == METADATA_ONLY_REASON
  end

  def uploader_linked_artists
    @uploader_linked_artists ||= post.artist_tags.filter_map(&:artist).select { |artist| artist.linked_user_id == creator_id }
  end

  # Used by Ticket#can_create_for? (via MODELS[:create][:default]) to gate reporting a
  # specific replacement: staff and the submitter can always report/view it, everyone else
  # only if it isn't rejected and the underlying post is visible to them.
  def visible?(user)
    return false unless post.visible?(user)
    return true if user.is_staff? || user.id == creator_id
    !rejected?
  end

  def promoted_id
    return nil unless promoted?

    @promoted_id ||= begin
      id = nil
      if post.has_children?
        id = post.children.joins(:media_asset).find_by("upload_media_assets.md5": md5)&.id
      end

      # Fallback 1: md5 lookup
      if id.nil?
        found_post = Post.joins(:media_asset).find_by("upload_media_assets.md5": md5)
        id = found_post&.id
      end

      # Fallback 2: Backup lookup
      if id.nil?
        backup = PostReplacement.original.joins(:post_replacement_media_asset).find_by(post_replacement_media_assets: { md5: md5 })
        id = backup&.post_id
      end

      # Fallback 3: PostEvent lookup
      if id.nil?
        event = PostEvent.where(action: :replacement_promoted)
                         .where("extra_data->>'source_post_id' = ?", post_id.to_s)
                         .order(created_at: :desc)
                         .first
        id = event&.post_id
      end

      id
    end
  end

  def upload_as_pending?
    as_pending.to_s.truthy?
  end

  include(StorageMethods)
  include(FileMethods)
  include(ProcessingMethods)
  include(PromotionMethods)
  include(PostMethods)
  extend(SearchMethods)

  def file_url(user)
    if post.deleteblocked?(user)
      nil
    elsif post.visible?(user)
      if original_file_visible_to?(user)
        replacement_file_url(user)
      else
        replacement_thumb_url(user)
      end
    end
  end

  def apionly_file_url
    file_url(CurrentUser.user)
  end

  def post_details
    {
      width:  post.image_width,
      height: post.image_height,
      size:   post.file_size,
      ext:    post.file_ext,
      md5:    post.md5,
    }
  end

  def current_details
    {
      width:  image_width,
      height: image_width,
      size:   file_size,
      ext:    file_ext,
      md5:    md5,
    }
  end

  def show_current?
    post && (pending? || previous_details.blank?)
  end

  def details
    if pending? && post
      post_details
    elsif previous_details.blank?
      return post_details if post
      nil
    else
      previous_details.transform_keys(&:to_sym)
    end
  end

  def self.available_includes
    %i[creator approver rejector post uploader_on_approve]
  end
end

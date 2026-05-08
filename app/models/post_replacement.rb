# frozen_string_literal: true

class PostReplacement < ApplicationRecord
  class ProcessingError < StandardError; end

  TAGS_TO_REMOVE_AFTER_ACCEPT = %w[better_version_at_source].freeze
  HIGHLIGHTED_TAGS = %w[better_version_at_source avoid_posting conditional_dnp].freeze
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
  validates(:rejection_reason, length: { maximum: 150 }, if: :rejected?)
  validate(:validate_media_asset_status, on: :create)

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

    def create_backup_replacement
      backup = nil
      begin
        post.media_asset.open_file do |file|
          backup = post.replacements.new(checksum: post.md5, creator: post.uploader.resolvable(post.uploader_ip_addr), status: "original", file_name: "#{post.md5}.#{post.file_ext}", source: post.source, reason: "Original File", is_backup: true)
          backup.media_asset.backup_post_id = post.id
          backup.media_asset.append_all!(file, save: false)
          backup.save!
        end
      rescue Exception => e
        raise(ProcessingError, "Failed to create post file backup: #{e.message}")
      end
      raise(ProcessingError, "Could not create post file backup?") unless backup.present? && backup.valid?
      raise(ProcessingError, "Failed to create post file backup: #{backup.errors.full_messages.join('; ')}") unless backup.valid?(:status)
      backup
    end

    def approve!(approver, penalize_current_uploader:)
      unless %w[pending original rejected].include?(status)
        errors.add(:status, "must be pending, original, or rejected to approve")
        return
      end
      errors.add(:post, "is deleted") if post.is_deleted?
      transaction do
        create_backup_replacement if post.replacements.original.none?

        post.replacements.approved.find_each do |replacement|
          replacement.update_column(:status, replacement.sequence == 0 ? "original" : "rejected")
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

  def sequence
    post.replacement_ids.reverse.index(id)
  end

  def self.available_includes
    %i[creator approver rejector post uploader_on_approve]
  end
end

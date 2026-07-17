# frozen_string_literal: true

# Remember to update the posts_trigger_change_seq sql function if new fields which should be considered a change are added
class Post < ApplicationRecord
  class DeletionError < StandardError; end
  class TimeoutError < StandardError; end
  class EditRestrictedError < StandardError; end

  # Tags to copy when copying notes.
  NOTE_COPY_TAGS = %w[translated partially_translated translation_check translation_request].freeze
  ASPECT_RATIO_REGEX = /^\d+:\d+$/
  VIDEO_EXTENSIONS = ::FileMethods::VIDEO_EXTENSIONS
  IMAGE_EXTENSIONS = ::FileMethods::IMAGE_EXTENSIONS
  GIF_EXTENSIONS = ::FileMethods::GIF_EXTENSIONS
  EXTENSIONS = ::FileMethods::EXTENSIONS
  CHANGE_SEQ_IGNORED = %i[id created_at updated_at up_score down_score score uploader_id uploader_ip_addr fav_string pool_string last_comment_bumped_at fav_count tag_count change_seq original_tag_string upload_url vote_string upload_media_asset_id updater_id updater_ip_addr].freeze

  def self.get_change_seq_tracked
    Post.connection.select_one("SELECT prosrc FROM pg_proc WHERE proname = $1", nil, ["posts_trigger_change_seq"])["prosrc"].scan(/NEW\.([a-z_]+) IS DISTINCT FROM OLD\.([a-z_]+)/).flatten.uniq.map(&:to_sym)
  end

  def self.get_change_seq_missed
    Post.column_names.map(&:to_sym) - Post.get_change_seq_tracked - Post::CHANGE_SEQ_IGNORED
  end

  module Flags
    # HAS_CROPPED              = 1 << 0
    HIDE_FROM_ANONYMOUS      = 1 << 1
    HIDE_FROM_SEARCH_ENGINES = 1 << 2
    IS_TAKEN_DOWN            = 1 << 3

    def self.map
      constants.to_h { |name| [name.to_s.downcase, const_get(name)] }
    end

    def self.list
      map.keys.map(&:to_sym)
    end
  end

  has_bit_flags(Flags.map)

  before_validation(:merge_old_changes)
  before_validation(:apply_source_diff)
  before_validation(:apply_tag_diff, if: :should_process_tags?)
  before_validation(:normalize_tags, if: :should_process_tags?)
  before_validation(:tag_count_not_insane, if: :should_process_tags?)
  before_validation(:strip_source)
  before_validation(:fix_bg_color)
  before_validation(:blank_out_nonexistent_parents)
  before_validation(:remove_parent_loops)
  normalizes(:description, with: ->(desc) { desc.gsub("\r\n", "\n") })
  validates(:rating, inclusion: { in: %w[s q e], message: "rating must be s, q, or e" })
  validates(:bg_color, format: { with: /\A[A-Fa-f0-9]{6}\z/ }, allow_nil: true)
  validates(:description, length: { maximum: -> { Config.instance.post_description_max_size } }, if: :description_changed?)
  validate(:added_tags_are_valid, if: :should_process_tags?)
  validate(:removed_tags_are_valid, if: :should_process_tags?)
  validate(:has_artist_tag, if: :should_process_tags?)
  validate(:has_enough_tags, if: :should_process_tags?)
  validate(:post_is_not_its_own_parent)
  validate(:updater_can_change_rating)
  validate(:validate_thumbnail_frame)
  before_save(:update_tag_post_counts, if: :should_process_tags?)
  before_save(:update_qtags, if: :will_save_change_to_description?)
  after_create(:ai_check, if: -> { Config.flag_ai_posts? || Config.tag_ai_posts? })
  after_update(:regenerate_image_variants, if: :saved_change_to_thumbnail_frame?)
  after_save(:create_post_events)
  after_save(:create_version)
  after_save(:update_parent_on_save)
  after_save(:apply_post_metatags)
  after_commit(:update_pool_artists)
  after_commit(:update_tag_followers, on: %i[create update], if: :should_update_followers?)
  after_commit(:delete_files, on: :destroy)
  after_commit(:remove_iqdb_async, on: :destroy)
  after_commit(:update_iqdb_async, on: :create)

  belongs_to_user(:uploader, ip: true, clones: :updater, aliases: %i[creator], counter_cache: "post_count") # TODO: convert to creator?
  belongs_to_user(:updater, ip: true)
  belongs_to_user(:approver, optional: true)
  resolvable(:destroyer)
  belongs_to(:parent, class_name: "Post", optional: true)
  belongs_to(:media_asset, class_name: "UploadMediaAsset", foreign_key: :upload_media_asset_id)
  has_one(:upload, dependent: :destroy)
  has_many(:flags, class_name: "PostFlag", dependent: :destroy)
  has_many(:votes, class_name: "PostVote", dependent: :destroy)
  has_many(:notes, dependent: :destroy)
  has_many(:note_versions)
  has_many(:appeals, class_name: "PostAppeal", dependent: :destroy)
  has_many(:events, class_name: "PostEvent") # no dependent

  has_many(:comments, -> { includes(:creator, :updater).order("comments.is_sticky": :desc, "comments.id": :asc) }, dependent: :destroy)
  has_many(:children, -> { order("posts.id") }, class_name: "Post", foreign_key: "parent_id")
  has_many(:approvals, class_name: "PostApproval", dependent: :destroy)
  has_many(:disapprovals, class_name: "PostDisapproval", dependent: :destroy)
  has_many(:favorites)
  has_many(:replacements, -> { default_order }, class_name: "PostReplacement", dependent: :destroy)
  has_many(:pool_covers, class_name: "Pool", foreign_key: :cover_post_id, dependent: :nullify)
  revertible do |version|
    self.tag_string = version.tags
    self.rating = version.rating
    self.source = version.source
    self.parent_id = version.parent_id
    self.description = version.description
    self.edit_reason = "Revert to version #{version.version}"
  end

  attr_accessor(:old_tag_string, :old_parent_id, :old_source, :old_rating,
                :do_not_version_changes, :tag_string_diff, :source_diff, :edit_reason, :tag_string_before_parse,
                :automated_edit)

  has_many(:versions, -> { order("post_versions.id": :asc) }, class_name: "PostVersion", dependent: :destroy)

  scope(:pending, -> { where(is_pending: true) })
  scope(:not_pending, -> { where(is_pending: false) })
  scope(:deleted, -> { where(is_deleted: true) })
  scope(:not_deleted, -> { where(is_deleted: false) })
  scope(:flagged, -> { where(is_flagged: true) })
  scope(:not_flagged, -> { where(is_flagged: false) })
  scope(:appealed, -> { where(is_appealed: true) })
  scope(:not_appealed, -> { where(is_appealed: false) })
  scope(:unlisted, -> { where(is_unlisted: true) })
  scope(:not_unlisted, -> { where(is_unlisted: false) })
  scope(:pending_or_flagged, -> { pending.or(flagged) })
  scope(:has_notes, -> { where.not(last_noted_at: nil) })
  scope(:expired, -> { pending.where(posts: { created_at: ...PostPruner::MODERATION_WINDOW.days.ago }) })
  scope(:with_assets, -> { includes(:media_asset) })
  scope(:with_assets_and_metadata, -> { with_assets.includes(media_asset: :media_metadata) })

  class << self
    alias takedowns is_taken_down
  end

  IMAGE_TYPES = %i[original large preview crop].freeze

  def self.file_sizes
    results = Post.connection.execute(<<~SQL.squish).first
      SELECT
        AVG(file_size) as average_size,
        SUM(file_size) AS posts_size,
        SUM((row->>'size')::bigint) AS variants_size
      FROM upload_media_assets, LATERAL jsonb_array_elements(variants_data) row;
    SQL

    {
      total:    results["posts_size"] + results["variants_size"],
      average:  results["average_size"],
      posts:    results["posts_size"],
      variants: results["variants_size"],
    }
  end

  def ai_check
    AiCheckJob.perform_later(self)
  end

  def ai_check!
    is_ai_generated? => { score:, reason: }
    if score > Config.ai_confidence_threshold
      if Config.flag_ai_posts?
        flags.create!(
          creator:     User.system,
          reason_name: "uploading_guidelines",
          note:        "AI Score: #{score}\nReason: #{reason}",
        )
      end
      if Config.tag_ai_posts?
        self.updater = User.system
        self.edit_reason = "AI Generated"
        add_tag("ai_generated")
        self.locked_tags = (locked_tags.split + %w[ai_generated]).uniq.join(" ")
        save!
      end
    end
    { score: score, reason: reason }
  end

  module Ratings
    SAFE = "s"
    QUESTIONABLE = "q"
    EXPLICIT = "e"

    def self.map
      constants.to_h { |x| [x.to_s.downcase, const_get(x)] }
    end
  end

  module PostFileMethods
    extend(ActiveSupport::Concern)

    def delete_files
      media_asset&.expunge!(destroyer)
    end

    def move_files_on_delete(user)
      media_asset.delete!(user)
    end

    def move_files_on_undelete(user)
      media_asset.undelete!(user)
    end

    def file_path
      media_asset.original.file_path
    end

    def file_url(user)
      media_asset.original.file_url(user: user)
    end

    def file(&)
      media_asset.original.open_file(&)
    end

    def apionly_file_url
      file_url(CurrentUser.user)
    end

    def apionly_large_file_url
      large_file_url(CurrentUser.user)
    end

    def apionly_preview_file_url
      preview_file_url(CurrentUser.user)
    end

    GayFurCity.config.image.variants.keys.map(&:to_s).each do |name|
      define_method("#{name}_file_path") do
        variant_path(name)
      end

      define_method("#{name}_file_url") do |user|
        variant_url(name, user)
      end

      define_method("#{name}_file") do |&block|
        variant_file(name, &block)
      end

      alias_method("file_path_#{name}", "#{name}_file_path")
      alias_method("file_url_#{name}", "#{name}_file_url")
      alias_method("file_#{name}", "#{name}_file")
    end

    GayFurCity.config.video.variants.keys.map(&:to_s).each do |name|
      define_method("#{name}_webm_file_path") do
        variant_path(name, "webm")
      end

      define_method("#{name}_mp4_file_path") do
        variant_path(name, "mp4")
      end

      define_method("#{name}_webm_file_url") do |user|
        variant_url(name, user, "webm")
      end

      define_method("#{name}_mp4_file_url") do |user|
        variant_url(name, user, "mp4")
      end

      define_method("#{name}_webm_file") do |&block|
        variant_file(name, "webm", &block)
      end

      define_method("#{name}_mp4_file") do |&block|
        variant_file(name, "mp4", &block)
      end

      alias_method("file_path_#{name}_webm", "#{name}_webm_file_path")
      alias_method("file_path_#{name}_mp4", "#{name}_mp4_file_path")
      alias_method("file_url_#{name}_webm", "#{name}_webm_file_url")
      alias_method("file_url_#{name}_mp4", "#{name}_mp4_file_url")
      alias_method("file_#{name}_webm", "#{name}_webm_file")
      alias_method("file_#{name}_mp4", "#{name}_mp4_file")
    end

    def reverse_image_url(user)
      return large_file_url(user) if has_large?
      return preview_file_url(user) if has_preview?
      file_url(user)
    end

    def avatar_image_url(user)
      return large_file_url(user) if has_large?
      return preview_file_url(user) if has_preview?
      file_url(user)
    end

    def video_poster_url(user)
      return large_file_url(user) if has_large?
      file_url(user)
    end

    def find_variant(...)
      media_asset.find_variant(...)
    end

    def find_variant!(...)
      media_asset.find_variant!(...)
    end

    def variant_url(type, user, ext = nil)
      find_variant!(type, ext).file_url(user: user)
    end

    def variant_path(type, ext = nil)
      find_variant!(type, ext).file_path
    end

    def variant_file(type, ext = nil, &)
      find_variant!(type, ext).open_file(&)
    end

    def open_graph_video_url(user)
      if image_height > 720 && has_720p?
        return file_url_720p_mp4(user)
      end
      variant_url("original", "mp4")
    end

    def open_graph_image_url(user)
      if is_image?
        if has_large?
          large_file_url(user)
        else
          file_url(user)
        end
      elsif has_preview?
        preview_file_url(user)
      else
        file_url(user)
      end
    end

    def file_url_for(user)
      if user.default_image_size == "large" && has_large?
        large_file_url(user)
      else
        file_url(user)
      end
    end

    def file_url_ext_for(user, ext)
      if user.default_image_size == "large" && is_video? && has_720p?
        variant_url("720p", user, ext)
      else
        variant_url("original", user, ext)
      end
    end

    def display_class_for(user)
      if user.default_image_size == "original"
        ""
      else
        "fit-window"
      end
    end

    [*GayFurCity.config.image.variants.keys, *GayFurCity.config.video.variants.keys].map(&:to_s).uniq.each do |name|
      define_method("has_#{name}?") do
        has_variant_size?(name)
      end
    end

    def has_dimensions?
      image_width.present? && image_height.present?
    end

    def has_variant_size?(scale)
      media_asset.generated_variants.include?(scale)
    end

    delegate(:regenerate_video_variants, :regenerate_video_variants!, :regenerate_image_variants, :regenerate_image_variants!, to: :media_asset)
  end

  module ImageMethods
    def twitter_card_supported?
      image_width.to_i >= 280 && image_height.to_i >= 150
    end

    # @deprecated
    def has_large
      !!has_large? # TODO: remove
    end

    def large_image_width
      if has_large?
        [GayFurCity.config.image.large_width, image_width].min
      else
        image_width
      end
    end

    def large_image_height
      ratio = GayFurCity.config.image.large_width.to_f / image_width.to_f
      if has_large? && ratio < 1
        (image_height * ratio).to_i
      else
        image_height
      end
    end

    def resize_percentage
      100 * large_image_width.to_f / image_width.to_f
    end
  end

  module ApprovalMethods
    def is_approvable?
      !is_status_locked? && (is_pending? || is_appealed?) && approver.nil?
    end

    def is_appealable?
      is_deleted? && !is_appealed?
    end

    def is_active?
      !is_pending? && !is_deleted?
    end

    def unflag!(user)
      post_flag_id = flags.pending.last&.id
      flags.each { |f| f.resolve!(user) }
      update(is_flagged: false, updater: user)
      PostEvent.add!(id, user, :flag_removed, post_flag_id: post_flag_id)
    end

    def approved_by?(user)
      approver == user || approvals.exists?(user: user)
    end

    def unapprove!(user)
      PostEvent.add!(id, user, :unapproved)
      update(approver: nil, is_pending: true, updater: user)
      uploader.notify_for_upload(self, :post_unapprove) if uploader_id != user.id
    end

    def is_unapprovable?(user)
      # Allow unapproval only by the approver
      return false if approver.present? && approver != user
      # Prevent unapproving self approvals by someone else
      return false if approver.nil? && uploader != user
      # Allow unapproval when the post is not pending anymore and is not at risk of auto deletion
      !is_pending? && !is_deleted? && created_at.after?(PostPruner::MODERATION_WINDOW.days.ago)
    end

    def approve!(user)
      return unless approver.nil?

      if uploader_id == user.id
        update(is_pending: false)
      else
        PostEvent.add!(id, user, :approved)
        approvals.create(user: user)
        update(approver: user, is_pending: false, updater: user)
        uploader.notify_for_upload(self, :post_approve) if uploader_id != user.id
        appeals.pending.each { |a| a.accept!(user) }
        flags.pending.each { |f| f.resolve!(user) }
      end
    end
  end

  module SourceMethods
    def source_array
      return [] if source.blank?
      source.split("\n").compact_blank
    end

    def apply_source_diff
      if Config.instance.enable_autotagging? && !should_process_tags?
        tags = add_automatic_tags(tag_array)
        set_tag_string(tags.uniq.sort.join(" "))
      end

      return if source_diff.blank?

      diff = source_diff.gsub(/\r\n?/, "\n").gsub(/%0A/i, "\n").split(/(?:\r)?\n/)
      to_remove, to_add = diff.partition { |x| x =~ /\A-/i }
      to_remove = to_remove.map { |x| x[1..].starts_with?('"') && x.ends_with?('"') ? x[1..].delete_prefix('"').delete_suffix('"') : x[1..] }
      to_add = to_add.map { |x| x.starts_with?('"') && x.ends_with?('"') ? x.delete_prefix('"').delete_suffix('"') : x }

      current_sources = source_array
      current_sources += to_add
      current_sources -= to_remove
      self.source = current_sources.join("\n")
    end

    def strip_source
      self.source = "" if source.blank?

      source.gsub!(/\r\n?/, "\n") # Normalize newlines
      source.gsub!(/%0A/i, "\n")  # Handle accidentally-encoded %0As from api calls (which would normally insert a literal %0A into the source)
      sources = source.split(/(?:\r)?\n/)
      gallery_sources = []
      submission_sources = []
      direct_sources = []
      additional_sources = []

      alternate_processors = []
      if upload_url.present?
        alternate = Sources::Alternates.find(upload_url)
        alternate_processors << alternate
        gallery_sources << alternate.gallery_url if alternate.gallery_url
        direct_sources << alternate.submission_url if alternate.submission_url
        additional_sources += alternate.additional_urls if alternate.additional_urls
      end
      sources.map! do |src|
        src.unicode_normalize!(:nfc)
        src = src.try(:strip)
        alternate = Sources::Alternates.find(src)
        alternate_processors << alternate
        gallery_sources << alternate.gallery_url if alternate.gallery_url
        submission_sources << alternate.submission_url if alternate.submission_url
        direct_sources << alternate.direct_url if alternate.direct_url
        additional_sources += alternate.additional_urls if alternate.additional_urls
        alternate.original_url
      end
      sources = (sources + submission_sources + gallery_sources + direct_sources + additional_sources).compact.reject { |e| e.strip.empty? }.uniq
      alternate_processors.each do |alt_processor|
        sources = alt_processor.remove_duplicates(sources)
      end

      # Truncate sources to prevent abuse
      self.source = sources.pluck(0..2048).first(10).join("\n")
    end

    def copy_sources_to_parent
      return if parent_id.blank?
      parent.source += "\n#{source}"
      parent.updater = updater
    end
  end

  module PresenterMethods
    def presenter
      @presenter ||= PostPresenter.new(self)
    end

    def status_flags
      flags = []
      flags << "pending"  if is_pending?
      flags << "flagged"  if is_flagged?
      flags << "deleted"  if is_deleted?
      flags << "appealed" if is_appealed?
      flags << "unlisted" if is_unlisted?
      flags.join(" ")
    end

    def pretty_rating
      {
        "s" => "Safe",
        "q" => "Questionable",
        "e" => "Explicit",
      }[rating]
    end
  end

  module TagMethods
    def should_process_tags?
      @removed_tags ||= []

      tag_string_changed? || locked_tags_changed? || tag_string_diff.present? || !@removed_tags.empty? || !added_tags.empty?
    end

    def tag_array
      @tag_array ||= TagQuery.scan(tag_string)
    end

    def tag_array_was
      @tag_array_was ||= TagQuery.scan(tag_string_in_database.presence || tag_string_before_last_save || "")
    end

    def tags
      Tag.where(name: tag_array)
    end

    def tag_ids
      tags.pluck(:id)
    end

    def tags_was
      Tag.where(name: tag_array_was)
    end

    TagCategory.categories.each do |category|
      define_method("#{category.name}_tags") do
        Tag.where(name: send("#{category.name}_tag_array"))
      end

      define_method("#{category.name}_tags_was") do
        Tag.where(name: send("#{category.name}_tag_array_was"))
      end

      define_method("#{category.name}_tags_before_last_save") do
        Tag.where(name: send("#{category.name}_tag_array_before_last_save"))
      end

      define_method("#{category.name}_tag_array") do
        typed_tags(category.id)
      end

      define_method("#{category.name}_tag_array_was") do
        typed_tags_was(category.id)
      end

      define_method("#{category.name}_tag_array_before_last_save") do
        typed_tags_before_last_save(category.id)
      end
    end

    def added_tags
      tag_array - tag_array_was
    end

    def decrement_tag_post_counts
      Tag.decrement_post_counts(tag_array)
    end

    def increment_tag_post_counts
      Tag.increment_post_counts(tag_array)
    end

    def update_tag_post_counts
      return if is_deleted?

      decrement_tags = tag_array_was - tag_array
      increment_tags = tag_array - tag_array_was
      Tag.increment_post_counts(increment_tags)
      Tag.decrement_post_counts(decrement_tags)
    end

    def update_pool_artists
      return unless artist_tag_array != artist_tag_array_before_last_save
      UpdatePoolArtistsJob.perform_later(id)
    end

    def update_pool_artists!
      pools.each(&:update_artists!)
    end

    def update_tag_followers
      TagFollowerUpdateJob.perform_later(id)
    end

    def update_tag_followers!
      TagFollower.update_from_post!(self)
    end

    def should_update_followers?
      previously_new_record? || (saved_change_to_tag_string? && (tag_array - tag_array_was).any?)
    end

    def reset_followers_on_destroy
      TagFollower.where(last_post_id: id).find_each do |follower|
        success = follower.set_latest_post(exclude: id)
        follower.update(last_post_id: nil) unless success
      end
    end

    def set_tag_count(category, tagcount)
      send("tag_count_#{category}=", tagcount)
    end

    def inc_tag_count(category)
      set_tag_count(category, send("tag_count_#{category}") + 1)
    end

    def merge_old_changes
      if old_tag_string
        # If someone else committed changes to this post before we did,
        # then try to merge the tag changes together.
        current_tags = tag_array_was
        new_tags = tag_array
        old_tags = TagQuery.scan(old_tag_string)

        kept_tags = current_tags & new_tags
        @removed_tags = old_tags - kept_tags

        set_tag_string(((current_tags + new_tags) - old_tags + (current_tags & new_tags)).uniq.sort.join(" "))
      end

      if old_parent_id == ""
        old_parent_id = nil
      else
        old_parent_id = old_parent_id.to_i
      end
      if old_parent_id == parent_id
        self.parent_id = parent_id_before_last_save || parent_id_was
      end

      if old_source == source.to_s
        self.source = source_before_last_save || source_was
      end

      if old_rating == rating
        self.rating = rating_before_last_save || rating_was
      end
    end

    def apply_tag_diff
      return if tag_string_diff.blank?
      @tag_string_before_parse = remove_metatags(tag_string_diff.split).join(" ")

      current_tags = tag_array
      diff = TagQuery.scan(tag_string_diff)
      to_remove, to_add = diff.partition { |x| x =~ /\A-/i }
      to_remove = to_remove.pluck(1..-1)
      to_remove = TagAlias.to_aliased(to_remove)
      to_add = TagAlias.to_aliased(to_add)
      @removed_tags = to_remove
      current_tags += to_add
      current_tags -= to_remove
      set_tag_string(current_tags.uniq.sort.join(" "))
    end

    def reset_tag_array_cache
      @tag_array = nil
      @tag_array_was = nil
    end

    def set_tag_string(string, typed: true)
      self.tag_string = string
      reset_tag_array_cache
      update_typed_tags(string) if typed
    end

    def tag_count_not_insane
      return if do_not_version_changes || automated_edit

      max_count = Config.instance.max_tags_per_post
      if TagQuery.scan(tag_string).size > max_count
        errors.add(:tag_string, "tag count exceeds maximum of #{max_count}")
        throw(:abort)
      end
      true
    end

    def normalize_tags
      @tag_string_before_parse = remove_metatags(tag_array - tag_array_was).join(" ") if tag_string_diff.blank?
      if locked_tags.present?
        remove_invalid_category_locked_tags
        locked = TagQuery.scan(locked_tags.downcase)
        to_remove, to_add = locked.partition { |x| x =~ /\A-/i }
        to_remove = to_remove.pluck(1..-1)
        to_remove = TagAlias.to_aliased(to_remove)
        @locked_to_remove = to_remove + to_remove.map { |tag_name| TagImplication.cached_descendants(tag_name) }.flatten
        @locked_to_add = TagAlias.to_aliased(to_add)
      end

      normalized_tags = TagQuery.scan(tag_string)
      normalized_tags = apply_casesensitive_metatags(normalized_tags)
      normalized_tags = normalized_tags.map(&:downcase)
      normalized_tags = remove_aspect_ratio_tags(normalized_tags)
      normalized_tags = filter_metatags(normalized_tags)
      normalized_tags = remove_negated_tags(normalized_tags)
      normalized_tags = remove_dnp_tags(normalized_tags)
      normalized_tags = TagAlias.to_aliased(normalized_tags)
      normalized_tags = apply_locked_tags(normalized_tags, @locked_to_add, @locked_to_remove)
      normalized_tags = %w[tagme] if normalized_tags.empty?
      normalized_tags = add_automatic_tags(normalized_tags)
      normalized_tags = TagImplication.with_descendants(normalized_tags)
      add_dnp_tags_to_locked(normalized_tags)
      normalized_tags -= @locked_to_remove if @locked_to_remove # Prevent adding locked tags through implications or aliases.
      normalized_tags = normalized_tags.compact.uniq
      normalized_tags = Tag.find_or_create_by_name_list(normalized_tags, user: updater)
      normalized_tags = remove_invalid_tags(normalized_tags)
      normalized_tags = normalized_tags.map(&:name).uniq.sort.join(" ")
      set_tag_string(normalized_tags)
    end

    def remove_aspect_ratio_tags(tags)
      rejected = []
      tags = tags.reject do |tag|
        if tag =~ Post::ASPECT_RATIO_REGEX
          rejected << tag
          next true
        end
        false
      end
      warnings.add(:base, "Aspect ratios cannot be added to posts: #{rejected.join(', ')}") if rejected.any?
      tags
    end

    # Prevent adding these without an implication
    def remove_dnp_tags(tags)
      locked = locked_tags
      # Don't remove dnp tags here if they would be later added through locked tags
      # to prevent the warning message from appearing when they didn't actually get removed
      if locked.exclude?("avoid_posting")
        tags -= ["avoid_posting"]
      end
      if locked.exclude?("conditional_dnp")
        tags -= ["conditional_dnp"]
      end
      tags
    end

    def add_dnp_tags_to_locked(tags)
      locked = TagQuery.scan(locked_tags.downcase)
      if tags.include?("avoid_posting")
        locked << "avoid_posting"
      end
      if tags.include?("conditional_dnp")
        locked << "conditional_dnp"
      end
      self.locked_tags = locked.uniq.join(" ") unless locked.empty?
    end

    def apply_locked_tags(tags, to_add, to_remove)
      if to_remove
        overlap = tags & to_remove
        n = overlap.size
        if n > 0
          warnings.add(:base, "Forcefully removed #{n} locked #{n == 1 ? 'tag' : 'tags'}: #{overlap.join(', ')}")
        end
        tags -= to_remove
      end
      if to_add
        missing = to_add - tags
        n = missing.size
        if n > 0
          warnings.add(:base, "Forcefully added #{n} locked #{n == 1 ? 'tag' : 'tags'}: #{missing.join(', ')}")
        end
        tags += to_add
      end
      tags
    end

    def remove_invalid_category_locked_tags
      locked = locked_tags.downcase.split
      invalid = locked.select { |tag| Tag.category_for(tag.starts_with?("-") ? tag[1..] : tag) == TagCategory.invalid }
      unless invalid.empty?
        warnings.add(:base, "Forcefully removed #{invalid.length} invalid locked #{'tag'.pluralize(invalid.length)}: #{invalid.join(', ')}")
      end
      self.locked_tags = locked.reject { |tag| invalid.include?(tag) }.uniq.join(" ")
    end

    def remove_invalid_tags(tags)
      tags.select do |tag|
        unless tag.errors.empty?
          warnings.add(:base, "Can't add tag #{tag.name}: #{tag.errors.full_messages.join('; ')}")
        end
        tag.errors.empty?
      end
    end

    def remove_negated_tags(tags)
      @negated_tags, tags = tags.partition { |x| x =~ /\A-/i }
      @negated_tags = @negated_tags.pluck(1..-1)
      @negated_tags = TagAlias.to_aliased(@negated_tags)
      tags - @negated_tags
    end

    def add_automatic_tags(tags)
      return tags unless Config.instance.enable_autotagging?

      Autotagger.new(self).apply(tags)
    end

    # should_process_tags?
    def invalid_source?
      source_array.any? { |source| !%r{^-?https?://}.match(source) }
    end

    def bad_source?
      Sources::Bad.has_bad_source?(source_array)
    end

    def apply_casesensitive_metatags(tags)
      casesensitive_metatags, tags = tags.partition { |x| x =~ /\A(?:source):/i }
      # Reuse the following metatags after the post has been saved
      casesensitive_metatags += tags.grep(/\A(?:newpool):/i)
      unless casesensitive_metatags.empty?
        case casesensitive_metatags[-1]
        when /^source:none$/i
          self.source = ""

        when /^source:"?([^"]*)"?$/i
          self.source = $1

        when /^newpool:(.+)$/i
          pool = Pool.find_by(name: $1)
          if pool.nil?
            Pool.create(creator: updater, name: $1)
          end
        end
      end
      tags
    end

    def remove_metatags(tags)
      tags = tags.grep_v(/\A(?:-set|set|fav|-fav|upvote|downvote):/i)
      prefixed, unprefixed = tags.partition { |x| x =~ TagCategory.regexp }
      prefixed.map! { |tag| tag.sub(/\A#{TagCategory.regexp}:/, "") }
      prefixed + unprefixed
    end

    def filter_metatags(tags)
      @bad_type_changes = []
      @pre_metatags, tags = tags.partition { |x| x =~ /\A(?:rating|parent|-parent|-?locked):/i }
      tags = apply_categorization_metatags(tags)
      @post_metatags, tags = tags.partition { |x| x =~ /\A(?:-pool|pool|newpool|-set|set|fav|-fav|child|-child|upvote|downvote):/i }
      apply_pre_metatags
      unless @bad_type_changes.empty?
        bad_tags = @bad_type_changes.map { |x| "[[#{x}]]" }
        warnings.add(:base, "Failed to update the tag category for the following tags: #{bad_tags.join(', ')}. You can not edit the tag category of existing tags using prefixes. Please review usage of the tags, and if you are sure that the tag categories should be changed, then you can change them using the \"Tags\":/tags section of the website")
      end
      tags
    end

    def apply_categorization_metatags(tags)
      prefixed, unprefixed = tags.partition { |x| x =~ TagCategory.regexp }
      prefixed = Tag.find_or_create_by_name_list(prefixed, user: updater)
      prefixed.map! do |tag|
        @bad_type_changes << tag.name if tag.errors.include?(:category)
        tag.name
      end
      prefixed + unprefixed
    end

    def apply_post_metatags
      return unless @post_metatags

      @post_metatags.each do |tag| # rubocop:disable Metrics/BlockLength
        case tag
        when /^-pool:(\d+)$/i
          pool = Pool.find_by(id: $1.to_i)
          if pool
            pool.remove!(self, updater)
            if pool.errors.any?
              errors.add(:base, pool.errors.full_messages.join("; "))
            end
          end

        when /^-pool:(.+)$/i
          pool = Pool.find_by_name($1)
          if pool
            pool.remove!(self, updater)
            if pool.errors.any?
              errors.add(:base, pool.errors.full_messages.join("; "))
            end
          end

        when /^pool:(\d+)$/i
          pool = Pool.find_by(id: $1.to_i)
          if pool
            pool.add!(self, updater)
            if pool.errors.any?
              errors.add(:base, pool.errors.full_messages.join("; "))
            end
          end

        when /^(?:new)?pool:(.+)$/i
          pool = Pool.find_by_name($1)
          if pool
            pool.add!(self, updater)
            if pool.errors.any?
              errors.add(:base, pool.errors.full_messages.join("; "))
            end
          end

        when /^set:(\d+)$/i
          set = PostSet.find_by(id: $1.to_i)
          if set&.can_edit_posts?(updater)
            set.add!(self, updater)
            if set.errors.any?
              errors.add(:base, set.errors.full_messages.join("; "))
            end
          end

        when /^-set:(\d+)$/i
          set = PostSet.find_by(id: $1.to_i)
          if set&.can_edit_posts?(updater)
            set.remove!(self, updater)
            if set.errors.any?
              errors.add(:base, set.errors.full_messages.join("; "))
            end
          end

        when /^set:(.+)$/i
          set = PostSet.find_by(shortname: $1)
          if set&.can_edit_posts?(updater)
            set.add!(self, updater)
            if set.errors.any?
              errors.add(:base, set.errors.full_messages.join("; "))
            end
          end

        when /^-set:(.+)$/i
          set = PostSet.find_by(shortname: $1)
          if set&.can_edit_posts?(updater)
            set.remove!(self, updater)
            if set.errors.any?
              errors.add(:base, set.errors.full_messages.join("; "))
            end
          end

        when /^child:none$/i
          children.each do |post|
            post.update!(parent_id: nil)
          end

        when /^-child:(.+)$/i
          children.numeric_attribute_matches(:id, $1).each do |post|
            post.update!(parent_id: nil)
          end

        when /^child:(.+)$/i
          Post.numeric_attribute_matches(:id, $1).where.not(id: id).limit(10).each do |post|
            post.update!(parent_id: id)
          end
        end
      end
    end

    def apply_pre_metatags
      return unless @pre_metatags

      @pre_metatags.each do |tag|
        case tag
        when /^parent:none$/i, /^parent:0$/i
          self.parent_id = nil

        when /^-parent:(\d+)$/i
          if parent_id == $1.to_i
            self.parent_id = nil
          end

        when /^parent:(\d+)$/i
          if $1.to_i != id && Post.exists?(["id = ?", $1.to_i])
            self.parent_id = $1.to_i
            remove_parent_loops
          end

        when /^rating:([qse])/i
          self.rating = $1

        when /^(-?)locked:notes?$/i
          self.is_note_locked = ($1 != "-") if updater.is_janitor?

        when /^(-?)locked:rating$/i
          self.is_rating_locked = ($1 != "-") if updater.is_janitor?

        when /^(-?)locked:status$/i
          self.is_status_locked = ($1 != "-") if updater.is_admin?

        end
      end
    end

    def has_tag?(*)
      TagQuery.has_tag?(tag_array, *)
    end

    def fetch_tags(*)
      TagQuery.fetch_tags(tag_array, *)
    end

    def add_tag(tag)
      set_tag_string("#{tag_string} #{tag}", typed: false)
      update_typed_tag(tag, Tag.category_for(tag))
    end

    def remove_tag(tag)
      set_tag_string((tag_array - Array(tag)).join(" "), typed: false)
      delete_typed_tag(tag)
    end

    def tag_categories
      @tag_categories ||= Tag.categories_for(tag_array)
    end

    def typed_tags(category_id = nil)
      @typed_tags ||= typed_tag_string.split.map { |t| t.split("|").reverse }.uniq(&:first).to_h.transform_values(&:to_i)
      return @typed_tags.select { |_k, v| category_id == v }.keys if category_id
      @typed_tags
    end

    def typed_tags_was(category_id)
      @typed_tags_was ||= typed_tag_string_was.split.map { |t| t.split("|").reverse }.uniq(&:first).to_h.transform_values(&:to_i)
      return @typed_tags_was.select { |_k, v| category_id == v }.keys if category_id
      @typed_tags_was
    end

    def typed_tags_before_last_save(category_id)
      @typed_tag_string_before_last_save ||= (typed_tag_string_before_last_save || "").split.map { |t| t.split("|").reverse }.uniq(&:first).to_h.transform_values(&:to_i)
      return @typed_tag_string_before_last_save.select { |_k, v| category_id == v }.keys if category_id
      @typed_tag_string_before_last_save
    end

    def copy_tags_to_parent
      return if parent_id.blank?
      parent.tag_string += " #{tag_string}"
      parent.updater = updater
    end

    def update_typed_tags(tags = tag_string)
      self.typed_tag_string = Tag.where(name: tags.split).select(:name, :category).map { |t| "#{t.category}|#{t.name}" }.join(" ")
      reset_typed_tags_cache
      clean_typed_tag_string!
    end

    def reset_typed_tags_cache
      @typed_tags = nil
      @typed_tags_was = nil
      @typed_tag_string_before_last_save = nil
    end

    def update_typed_tag(name, category)
      return delete_typed_tag(name) if category.nil?
      typed = typed_tag_string
      if typed.match(/(?:\A| )(\d+)\|#{name}(?:\Z| )/)
        return if $1.to_i == category
        typed.gsub!(/(?:\A| )\d+\|#{name}(?:\Z| )/, " ")
      end
      typed += " #{category}|#{name}"
      self.typed_tag_string = typed.strip
      clean_typed_tag_string!
    end

    def delete_typed_tag(name)
      typed = typed_tag_string
      typed.gsub!(/(?:\A| )\d+\|#{name}(?:\Z| )/, " ")
      self.typed_tag_string = typed.strip
      clean_typed_tag_string!
    end

    def clean_typed_tag_string!
      array = typed_tag_string.split.uniq { |t| t.split("|").last }
      self.typed_tag_string = array.join(" ")
      TagCategory.categories.each do |category|
        count = array.count { |t| t.start_with?("#{category.id}|") }
        send("tag_count_#{category.name}=", count)
      end
      self.tag_count = array.count
    end
  end

  module FavoriteMethods
    def clean_fav_string!
      array = fav_string.split.uniq
      self.fav_string = array.join(" ")
      self.fav_count = array.size
    end

    def is_favorited?(user)
      !!(fav_string =~ /(?:\A| )fav:#{u2id(user)}(?:\Z| )/)
    end

    def apionly_is_favorited?
      is_favorited?(CurrentUser.user)
    end

    def append_user_to_fav_string(user_id)
      self.fav_string = (fav_string + " fav:#{user_id}").strip
      clean_fav_string!
    end

    def delete_user_from_fav_string(user_id)
      self.fav_string = fav_string.gsub(/(?:\A| )fav:#{user_id}(?:\Z| )/, " ").strip
      clean_fav_string!
    end

    # users who favorited this post, ordered by users who favorited it first
    def favorited_users(user)
      favorited_user_ids = fav_string.scan(/\d+/).map(&:to_i)
      visible_users = User.find(favorited_user_ids).reject { |u| u.hide_favorites?(user) }
      visible_users.index_by(&:id).slice(*favorited_user_ids).values
    end

    def remove_from_favorites
      Favorite.where(post_id: id).delete_all
      user_ids = fav_string.scan(/\d+/)
      User.where(id: user_ids).update_all("favorite_count = favorite_count - 1")
    end
  end

  module SetMethods
    def set_ids
      pool_string.scan(/set:(\d+)/).map { |set| set[0].to_i }
    end

    def post_sets
      @post_sets ||= if pool_string.blank?
                       PostSet.none
                     else
                       PostSet.where(id: set_ids)
                     end
    end

    def belongs_to_post_set(set)
      pool_string =~ /(?:\A| )set:#{set.id}(?:\z| )/
    end

    def add_set!(set, user, force: false)
      return if belongs_to_post_set(set) && !force
      with_lock do
        self.pool_string = "#{pool_string} set:#{set.id}".strip
        self.updater = user
      end
    end

    def remove_set!(set, user)
      with_lock do
        self.pool_string = (pool_string.split - ["set:#{set.id}"]).join(" ").strip
        self.updater = user
      end
    end

    def give_post_sets_to_parent(user)
      transaction do
        post_sets.find_each do |set|
          set.remove([id])
          set.add([parent.id]) if parent_id.present? && set.transfer_on_delete
          set.updater = user
          set.save!
        rescue StandardError
          # Ignore set errors due to things like set post count
        end
      end
    end

    def remove_from_post_sets
      post_sets.find_each do |set|
        set.remove!(self)
      end
    end
  end

  module PoolMethods
    def pool_ids
      pool_string.scan(/pool:(\d+)/).map { |pool| pool[0].to_i }
    end

    def pools
      @pools ||= if pool_string.blank?
                   Pool.none
                 else
                   Pool.where(id: pool_ids).series_first
                 end
    end

    def has_active_pools?
      pools.any?
    end

    def belongs_to_pool?(pool)
      pool_string =~ /(?:\A| )pool:#{pool.id}(?:\Z| )/
    end

    def add_pool!(pool, user)
      return if belongs_to_pool?(pool)

      with_lock do
        self.pool_string = "#{pool_string} pool:#{pool.id}".strip
        self.updater = user
      end
    end

    def remove_pool!(pool, user)
      return unless belongs_to_pool?(pool)
      return unless user.can_remove_from_pools?

      with_lock do
        self.pool_string = pool_string.gsub(/(?:\A| )pool:#{pool.id}(?:\Z| )/, " ").strip
        self.updater = user
      end
    end

    def remove_from_all_pools(user)
      pools.find_each do |pool|
        pool.remove!(self, user)
      end
    end
  end

  module VoteMethods
    def own_vote(user)
      return nil unless user
      v = vote_string.scan(/(?:\A| )(up|down|locked):#{u2id(user)}(?:\Z| )/).map { $1 }.first
      return nil if v.nil?
      %w[down locked up].index(v) - 1
    end

    def is_voted?(user)
      return false unless user
      own_vote(user).present?
    end

    def apionly_is_voted?
      is_voted?(CurrentUser.user)
    end

    def is_voted_down?(user)
      return false unless user
      own_vote(user) == -1
    end

    def apionly_is_voted_down?
      is_voted_down?(CurrentUser.user)
    end

    def is_voted_up?(user)
      return false unless user
      own_vote(user) == 1
    end

    def apionly_is_voted_up?
      is_voted_up?(CurrentUser.user)
    end

    def is_vote_locked?(user)
      return false unless user
      own_vote(user) == 0
    end

    def apionly_is_vote_locked?
      is_vote_locked?(CurrentUser.user)
    end

    def append_user_to_vote_string(user_id, type)
      if vote_string =~ /(?:\A| )(locked|up|down):#{user_id}(?:\Z| )/
        return if $1 == type
        self.vote_string = vote_string.gsub(/(?:\A| )(locked|up|down):#{user_id}(?:\Z| )/, " #{type}:#{user_id} ")
      else
        self.vote_string = vote_string + " #{type}:#{user_id}"
      end
      clean_vote_string!
    end

    def delete_user_from_vote_string(user_id)
      self.vote_string = vote_string.gsub(/(?:\A| )(locked|up|down):#{user_id}(?:\Z| )/, " ").strip
      clean_vote_string!
    end

    def clean_vote_string!
      array = vote_string.split.uniq { |x| x[/\d+/] }
      self.vote_string = array.join(" ")
      self.up_score = array.count { |x| x =~ /up/ }
      self.down_score = array.count { |x| x =~ /down/ }
      self.score = up_score - down_score
    end

    def voted_users(_user)
      voted_user_ids = vote_string.scan(/\d+/).map(&:to_i)
      User.find(voted_user_ids)
    end
  end

  module CountMethods
    def fast_count(user, tags = "", enable_safe_mode: user.safe_mode?, include_deleted: nil)
      tags = tags.to_s
      tags += " rating:s" if enable_safe_mode
      tags += " -status:deleted" if include_deleted != true && (include_deleted == false || !TagQuery.has_metatag?(tags, "status", "-status"))
      tags = TagQuery.normalize(tags)

      parts = %w[fc]
      parts << user.id if TagQuery.has_any_metatag?(tags, list: TagQuery::UNIQUE_METATAGS)
      parts << "safe" if enable_safe_mode
      parts << tags
      cache_key = parts.join(":")

      count = Cache.fetch(cache_key)
      if count.nil?
        count = Post.tag_match(tags, user).count_only
        expiry = count.seconds.clamp(3.minutes, 20.hours).to_i
        Cache.write(cache_key, count, expires_in: expiry)
      end
      count
    rescue TagQuery::CountExceededError
      0
    end

    def system_count(...)
      fast_count(User.system, ...)
    end
  end

  module ParentMethods
    # A parent has many children. A child belongs to a parent.
    # A parent cannot have a parent.
    #
    # After expunging a child:
    # - Move favorites to parent.
    # - Does the parent have any children?
    #   - Yes: Done.
    #   - No: Update parent's has_children flag to false.
    #
    # After expunging a parent:
    # - Move favorites to the first child.
    # - Reparent all children to the first child.

    def parent=(new_parent)
      self.parent_id = new_parent&.id
    end

    def parent_id=(new_parent_id)
      super

      # Allow reversing a parent-child relationship by making the child into the parent without creating a loop.
      if parent != self && parent&.parent == self
        parent.parent_id = nil
      end
    end

    # @return [Array<Post>] The list of this post's ancestors (its parent, grandparent, great-grandparent, etc).
    def ancestors
      ancestors = []
      parent = self.parent

      while parent.present? && !in?(ancestors)
        ancestors << parent
        parent = parent.parent
      end

      ancestors
    end

    # @return [Integer] The total number of levels in the entire parent-child tree. A post with no parent or
    # children has depth 1; a post with a parent but no children has depth 2; a post with a parent and one level of
    # children has depth 3; etc.
    def parent_hierarchy_depth
      ancestors.size + child_height + 1
    end

    # @return [Integer] The number of levels of child posts this post has. A post with no children has height 0; a post
    # with children but no grandchildren has height 1; a post with grandchildren but no great-grandchildren has height 2; etc.
    def child_height
      if children.present?
        children.map(&:child_height).max + 1
      else
        0
      end
    end

    def update_has_children_flag
      update(has_children: children.exists?, has_active_children: children.not_deleted.exists?)
    end

    def blank_out_nonexistent_parents
      if parent_id.present? && parent.nil?
        self.parent_id = nil
      end
    end

    def remove_parent_loops
      if parent.present? && parent.parent_id.present? && parent.parent_id == id
        parent.parent_id = nil
        parent.save
      end
    end

    def update_parent_on_destroy
      parent&.update_has_children_flag
    end

    def update_children_on_destroy(user)
      return if children.blank?

      eldest = children[0]
      siblings = children[1..]

      eldest.update(parent_id: nil)
      Post.where(id: siblings).update(parent_id: eldest.id, updater: user)
    end

    def update_parent_on_save
      return unless saved_change_to_parent_id? || saved_change_to_is_deleted?

      parent.presence&.update_has_children_flag
      Post.find(parent_id_before_last_save).update_has_children_flag if parent_id_before_last_save.present?
    end

    def give_favorites_to_parent(user)
      TransferFavoritesJob.perform_later(self, user)
    end

    def give_favorites_to_parent!(user)
      return if parent.nil?

      FavoriteManager.give_to_parent!(self)
      PostEvent.add!(id, user, :favorites_moved, parent_id: parent_id)
      PostEvent.add!(parent_id, user, :favorites_received, child_id: id)
    end

    def give_votes_to_parent(user)
      TransferVotesJob.perform_later(self, user)
    end

    def give_votes_to_parent!(_user)
      return if parent.nil?

      VoteManager::Posts.give_to_parent!(self)
    end

    def parent_exists?
      Post.exists?(parent_id)
    end

    def has_visible_children?(user)
      return true if has_active_children?
      return true if has_children? && user.is_approver?
      return true if has_children? && is_deleted?
      false
    end

    def apionly_has_visible_children
      has_visible_children?(CurrentUser.user)
    end

    def inject_children(ids)
      @children_ids = ids.map(&:id).join(" ")
    end

    def children_ids
      if has_children?
        @children_ids ||= children.map(&:id).join(" ")
      end
    end
  end

  module DeletionMethods
    def backup_post_data_destroy(destroyer, reason: "")
      post_data = {
        id:            id,
        description:   description,
        md5:           md5,
        tags:          tag_string,
        height:        image_height,
        width:         image_width,
        file_size:     file_size,
        sources:       source,
        approver_id:   approver_id,
        locked_tags:   locked_tags,
        rating:        rating,
        parent_id:     parent_id,
        change_seq:    change_seq,
        is_deleted:    is_deleted,
        is_pending:    is_pending,
        is_appealed:   is_appealed,
        duration:      duration,
        fav_count:     fav_count,
        comment_count: comment_count,
      }
      DestroyedPost.create!(post_id: id, post_data: post_data, md5: md5,
                            uploader_ip_addr: uploader_ip_addr, uploader_id: uploader_id,
                            destroyer: destroyer,
                            upload_date: created_at, reason: reason || "")
    end

    def expunge!(user, reason: "")
      if is_status_locked?
        errors.add(:is_status_locked, "; cannot delete post")
        return false
      end

      transaction do
        backup_post_data_destroy(user, reason: reason)
      end

      # transaction do
      Post.without_timeout do
        PostEvent.add!(id, user, :expunged)

        self.destroyer = user
        reset_followers_on_destroy
        update_children_on_destroy(user)
        decrement_tag_post_counts
        remove_from_all_pools(user)
        remove_from_post_sets
        remove_from_favorites
        destroy
        update_parent_on_destroy
      end
      # end
    end

    def protect_file?
      is_deleted?
    end

    def delete!(user, reason, options = {})
      if is_status_locked? && !options.fetch(:force, false)
        errors.add(:is_status_locked, "; cannot delete post")
        return false
      end

      if reason.blank?
        if pending_flag.blank?
          errors.add(:base, "Cannot delete with given reason when no active flag exists.")
          return
        end
        if pending_flag.reason =~ /uploading_guidelines/
          errors.add(:base, "Cannot delete with given reason when the flag is for uploading guidelines.")
          return
        end
        reason = pending_flag.reason
      end

      force_flag = options.fetch(:force, false)
      Post.with_timeout(30_000) do
        transaction do
          flag = flags.create(reason: reason, reason_name: "deletion", is_resolved: false, is_deletion: true, force_flag: force_flag, creator: user)

          if flag.errors.any? && !force_flag
            raise(PostFlag::Error, flag.errors.full_messages.join("; "))
          end

          self.is_deleted = true
          self.is_pending = false
          self.is_flagged = false
          self.is_appealed = false
          self.is_taken_down = options.fetch(:takedown, false)
          decrement_tag_post_counts
          save
          move_files_on_delete(user)
          PostEvent.add!(id, user, :deleted, reason: reason)
          appeals.pending.each { |a| a.reject!(user) }
          flags.pending.each { |f| f.resolve!(user) }
          uploader.notify_for_upload(self, :post_delete) if uploader_id != user.id
        end
      end

      # XXX This must happen *after* the `is_deleted` flag is set to true (issue #3419).
      # We don't care if these fail per-se so they are outside the transaction.
      User.where(id: uploader_id).update_all("post_deleted_count = post_deleted_count + 1")
      if options[:move_favorites]
        give_favorites_to_parent(user)
        give_votes_to_parent(user)
        give_post_sets_to_parent(user)
      end
      reject_pending_replacements(user)
    end

    def reject_pending_replacements(user)
      replacements.where(status: "pending").update(status: "rejected", rejector: user)
    end

    def undelete!(user, options = {})
      if is_status_locked? && !options.fetch(:force, false)
        errors.add(:is_status_locked, "; cannot undelete post")
        return
      end

      if is_taken_down? && !user.can_handle_takedowns? && !options.fetch(:force, false)
        errors.add(:is_taken_down, "; cannot undelete post")
        return
      end

      if !user.is_admin? && uploader_id == user.id
        raise(User::PrivilegeError, "You cannot undelete a post you uploaded")
      end

      unless is_deleted
        errors.add(:base, "Post is not deleted")
        return
      end

      transaction do
        self.is_deleted = false
        self.is_pending = false
        self.is_appealed = false
        self.is_taken_down = false
        self.approver = user
        flags.each { |f| f.resolve!(user) }
        increment_tag_post_counts
        save
        approvals.create(user: user)
        PostEvent.add!(id, user, :undeleted)
        appeals.pending.each { |a| a.accept!(user) }
        flags.pending.each { |f| f.resolve!(user) }
        uploader.notify_for_upload(self, :post_undelete) if uploader_id != user.id
      end
      move_files_on_undelete(user)
      User.where(id: uploader_id).update_all("post_deleted_count = post_deleted_count - 1")
    end

    def deletion_flag
      flags.order(id: :desc).first
    end

    def pending_flag
      flags.unresolved.order(id: :desc).first
    end
  end

  module VersionMethods
    def create_version(force: false)
      return if do_not_version_changes == true
      if new_record? || force
        create_new_version
      elsif automated_edit
        # the original tag string is not useful for automated edits
        self.original_tag_string = nil
        latest = versions.last
        if saved_change_to_mergable_attributes? && !saved_change_to_unmergable_attributes? && latest.updater_id == updater.id && latest.basic? && !latest.first?
          merge_post_version(versions.last)
          return
        end
      end
      if saved_change_to_watched_attributes?
        create_new_version
      end
    end

    def saved_change_to_watched_attributes?
      saved_change_to_unmergable_attributes? || saved_change_to_mergable_attributes?
    end

    def saved_change_to_unmergable_attributes?
      saved_change_to_rating? || saved_change_to_parent_id? || saved_change_to_description?
    end

    def saved_change_to_mergable_attributes?
      saved_change_to_source? || saved_change_to_tag_string? || saved_change_to_locked_tags?
    end

    def create_new_version
      # This function name is misleading, this directly creates the version.
      # Previously there was a  involved, now there isn't.
      PostVersion.queue(self, updater.resolvable(updater_ip_addr))
    end

    def merge_post_version(version)
      PostVersion.merge(version, self, updater.resolvable(updater_ip_addr))
    end
  end

  module NoteMethods
    def has_notes?
      last_noted_at.present?
    end

    def copy_notes_to(other_post, user, copy_tags: NOTE_COPY_TAGS)
      if id == other_post.id
        errors.add(:base, "Source and destination posts are the same")
        return false
      end
      unless has_notes?
        errors.add(:post, "has no notes")
        return false
      end

      transaction do
        notes.active.each do |note|
          note.copy_to(other_post, user)
        end

        PostEvent.add!(other_post.id, user, :copied_notes, source_post_id: id, note_count: notes.active.count)
        copy_tags.each do |tag|
          other_post.remove_tag(tag)
          other_post.add_tag(tag) if has_tag?(tag)
        end

        other_post.updater = user
        other_post.save
      end
    end
  end

  module ApiMethods
    def thumbnail_attributes(user)
      attributes = {
        id:           id,
        flags:        status_flags,
        tags:         tag_string,
        rating:       rating,
        file_ext:     file_ext,

        width:        image_width,
        height:       image_height,
        size:         file_size,

        created_at:   created_at,
        uploader:     uploader_name,
        uploader_id:  uploader_id,

        score:        score,
        fav_count:    fav_count,
        is_favorited: is_favorited?(user),
        own_vote:     own_vote(user),

        pools:        pool_ids,
      }

      if visible?(user)
        attributes[:md5] = md5
        attributes[:preview_url] = preview_file_url(user) if has_preview?
        attributes[:large_url] = large_file_url(user) if has_large?
        attributes[:file_url] = file_url(user)
        attributes[:cropped_url] = crop_file_url(user) if has_crop?
        attributes[:preview_width] = find_variant("preview")&.width
        attributes[:preview_height] = find_variant("preview")&.height
      end

      attributes
    end

    def variants(user)
      results = []
      media_asset.variants_images_first.without(media_asset.original).each do |variant|
        results << variant.cached_hash.merge(url: visible?(user) ? variant.file_url(user: user) : nil)
      end
      results
    end

    def status
      if is_pending?
        "pending"
      elsif is_deleted?
        "deleted"
      elsif is_flagged?
        "flagged"
      elsif is_unlisted?
        "unlisted"
      else
        "active"
      end
    end

    def serializable_hash(options = {})
      options ||= {}
      options[:user] ||= CurrentUser.user || User.anonymous
      user = options[:user]
      {
        id:              id,
        created_at:      created_at,
        updated_at:      updated_at,
        file:            {
          width:  image_width,
          height: image_height,
          ext:    file_ext,
          size:   file_size,
          md5:    md5,
          url:    visible?(user) ? file_url(user) : nil,
        },
        variants:        variants(user),
        score:           {
          up:    up_score,
          down:  down_score,
          total: score,
        },
        views:           {
          daily: daily_views,
          total: total_views,
        },
        tags:            TagCategory.category_names.index_with { |category| typed_tags(TagCategory.get(category).id) },
        locked_tags:     locked_tags.split,
        change_seq:      change_seq,
        flags:           {
          pending:       is_pending?,
          flagged:       is_flagged?,
          note_locked:   is_note_locked?,
          status_locked: is_status_locked?,
          rating_locked: is_rating_locked?,
          deleted:       is_deleted?,
          unlisted:      is_unlisted?,
          takedown:      is_taken_down?,
        },
        rating:          rating,
        fav_count:       fav_count,
        sources:         source.split("\n"),
        pools:           pool_ids,
        relationships:   {
          parent_id:           parent_id,
          has_children:        has_children,
          has_active_children: has_active_children,
          children:            children_ids&.split&.map(&:to_i) || [],
        },
        approver_id:     approver_id,
        approver_name:   approver_id.present? ? approver_name : nil,
        uploader_id:     uploader_id,
        uploader_name:   uploader_name,
        description:     description,
        comment_count:   visible_comment_count(user),
        is_favorited:    is_favorited?(user),
        own_vote:        own_vote(user),
        has_notes:       has_notes?,
        duration:        duration&.to_f,
        framecount:      framecount,
        thumbnail_frame: thumbnail_frame,
        qtags:           qtags,
        upload_url:      upload_url,
        min_edit_level:  min_edit_level,
      }
    end
  end

  module SearchMethods
    # returns one single post
    def random
      key = Digest::MD5.hexdigest(Time.now.to_f.to_s)
      random_up(key) || random_down(key)
    end

    def random_up(key)
      where(md5: ...key).reorder("md5 desc").first
    end

    def random_down(key)
      where(md5: key..).reorder("md5 asc").first
    end

    def sample(query, sample_size)
      tag_match_system("#{query} order:random", free_tags_count: 1).limit(sample_size).relation
    end

    # unflattens the tag_string into one tag per row.
    def with_unflattened_tags
      joins("CROSS JOIN unnest(string_to_array(tag_string, ' ')) AS tag")
    end

    def sql_raw_tag_match(tag)
      where("string_to_array(posts.tag_string, ' ') @> ARRAY[?]", tag)
    end

    def tag_match_system(query, **)
      tag_match(query, User.system, enable_safe_mode: false, always_show_deleted: true, **)
    end

    def tag_match_current(query, **)
      tag_match(query, CurrentUser.user, **)
    end

    def build_query(query, user, resolve_aliases: true, free_tags_count: 0, enable_safe_mode: user.safe_mode?, always_show_deleted: false)
      ElasticPostQueryBuilder.new(
        query,
        user,
        resolve_aliases:     resolve_aliases,
        free_tags_count:     free_tags_count,
        enable_safe_mode:    enable_safe_mode,
        always_show_deleted: always_show_deleted,
      )
    end

    # not using ... so required arguments can be determined
    def tag_match(query, user, **)
      build_query(query, user, **).search
    end

    def tag_match_sql(query, user)
      PostQueryBuilder.new(query, user).search
    end

    def search_uploaders(params, user)
      q = all
      QueryBuilder.new(uploaders_query_dsl.build, self, q, user)
                  .search(params)
                  .apply_uploaders_order(params)
    end

    def uploaders_query_dsl
      QueryDSL.new(self).user(:user, :uploader)
    end

    def apply_uploaders_order(_params)
      default_order
    end
  end

  module IqdbMethods
    extend(ActiveSupport::Concern)

    module ClassMethods
      def remove_iqdb(post_id)
        if IqdbProxy.enabled?
          IqdbRemoveJob.perform_later(post_id)
        end
      end
    end

    def update_iqdb_async
      if IqdbProxy.enabled? && has_preview?
        IqdbUpdateJob.perform_later(id)
      end
    end

    def remove_iqdb_async
      Post.remove_iqdb(id)
    end
  end

  module PostEventMethods
    def create_post_events
      if saved_change_to_is_rating_locked?
        action = is_rating_locked? ? :rating_locked : :rating_unlocked
        PostEvent.add!(id, updater, action)
      end
      if saved_change_to_is_status_locked?
        action = is_status_locked? ? :status_locked : :status_unlocked
        PostEvent.add!(id, updater, action)
      end
      if saved_change_to_is_note_locked?
        action = is_note_locked? ? :note_locked : :note_unlocked
        PostEvent.add!(id, updater, action)
      end
      if saved_change_to_is_comment_disabled?
        action = is_comment_disabled? ? :comment_disabled : :comment_enabled
        PostEvent.add!(id, updater, action)
      end
      if saved_change_to_is_comment_locked?
        action = is_comment_locked? ? :comment_locked : :comment_unlocked
        PostEvent.add!(id, updater, action)
      end
      if saved_change_to_bg_color?
        PostEvent.add!(id, updater, :changed_bg_color, bg_color: bg_color)
      end
      if saved_change_to_thumbnail_frame?
        PostEvent.add!(id, updater, :changed_thumbnail_frame, old_thumbnail_frame: thumbnail_frame_before_last_save, new_thumbnail_frame: thumbnail_frame)
      end
      if saved_change_to_min_edit_level?
        PostEvent.add!(id, updater, :set_min_edit_level, min_edit_level: min_edit_level)
      end
      if saved_change_to_is_unlisted?
        action = is_unlisted? ? :unlisted : :relisted
        PostEvent.add!(id, updater, action)
      end
    end
  end

  # noinspection ALL
  module ValidationMethods
    def fix_bg_color
      if bg_color.blank?
        self.bg_color = nil
      end
    end

    def post_is_not_its_own_parent
      if !new_record? && id == parent_id
        errors.add(:base, "Post cannot have itself as a parent")
        false
      end
    end

    def updater_can_change_rating
      # Don't forbid changes if the rating lock was just now set in the same update.
      if rating_changed? && is_rating_locked? && !is_rating_locked_changed?
        errors.add(:rating, "is locked and cannot be changed. Unlock the post first.")
      end
    end

    def added_tags_are_valid
      # Load this only once since it isn't cached
      added = Tag.where(name: added_tags)
      # noinspection RubyArgCount
      added_invalid_tags = added.select { |t| t.category == TagCategory.invalid }
      # noinspection RubyArgCount
      new_tags = added.select { |t| t.post_count <= 0 }
      # noinspection RubyArgCount
      new_general_tags = new_tags.select { |t| t.category == TagCategory.general }
      # noinspection RubyArgCount
      new_artist_tags = new_tags.select { |t| t.category == TagCategory.artist }
      # See https://github.com/e621ng/e621ng/issues/494
      # If the tag is fresh it's safe to assume it was created with a prefix
      # noinspection RubyArgCount
      repopulated_tags = new_tags.select { |t| t.category != TagCategory.general && t.category != TagCategory.meta && t.created_at < 10.seconds.ago }

      if added_invalid_tags.present?
        n = added_invalid_tags.size
        tag_wiki_links = added_invalid_tags.map { |tag| "[[#{tag.name}]]" }
        warnings.add(:base, "Added #{n} invalid #{'tag'.pluralize(n)}. See the wiki page for each tag for help on resolving these: #{tag_wiki_links.join(', ')}")
      end

      if new_general_tags.present?
        n = new_general_tags.size
        tag_wiki_links = new_general_tags.map { |tag| "[[#{tag.name}]]" }
        warnings.add(:base, "Created #{n} new #{'tag'.pluralize(n)}: #{tag_wiki_links.join(', ')}")
      end

      if repopulated_tags.present?
        n = repopulated_tags.size
        tag_wiki_links = repopulated_tags.map { |tag| "[[#{tag.name}]]" }
        warnings.add(:base, "Repopulated #{n} old #{'tag'.pluralize(n)}: #{tag_wiki_links.join(', ')}")
      end

      new_artist_tags.each do |tag|
        if tag.artist.blank?
          warnings.add(:base, "Artist [[#{tag.name}]] requires an artist entry. \"Create new artist entry\":[/artists/new?artist%5Bname%5D=#{CGI.escape(tag.name)}]")
        end
      end
    end

    def removed_tags_are_valid
      attempted_removed_tags = @removed_tags + @negated_tags
      unremoved_tags = tag_array & attempted_removed_tags

      if unremoved_tags.present?
        unremoved_tags_list = unremoved_tags.map { |t| "[[#{t}]]" }.to_sentence
        warnings.add(:base, "#{unremoved_tags_list} could not be removed. Check for implications and locked tags and try again")
      end

      @removed_tags = []
    end

    def has_artist_tag
      return unless new_record?
      return if tags.artist.any?

      warnings.add(:base, 'Artist tag is required. "Click here":/help/tags#categorychange if you need help changing the category of an tag. Ask on the forum if you need naming help')
    end

    def has_enough_tags
      return unless new_record?

      if tags.general.count < 10
        warnings.add(:base, "Uploads must have at least 10 general tags. Read the \"Tagging Checklist\":/help/tagging_checklist for information on tagging your uploads")
      end
    end
  end

  module ViewMethods
    def total_views
      ViewCountCache.get(id, :total)
    end

    def daily_views
      ViewCountCache.get(id, :daily)
    end
  end

  module QTagMethods
    def update_qtags
      self.qtags = DText.parse(description, qtags: true)[:qtags]
    end
  end

  include(MediaAsset::DelegateProperties)
  include(PostFileMethods)
  include(FileMethods)
  include(ImageMethods)
  include(ApprovalMethods)
  include(SourceMethods)
  include(PresenterMethods)
  include(TagMethods)
  include(FavoriteMethods)
  include(PoolMethods)
  include(SetMethods)
  include(VoteMethods)
  include(ParentMethods)
  include(DeletionMethods)
  include(VersionMethods)
  include(NoteMethods)
  include(ApiMethods)
  include(IqdbMethods)
  include(ValidationMethods)
  include(PostEventMethods)
  include(DocumentStore::Model)
  include(PostIndex)
  include(ViewMethods)
  include(QTagMethods)
  extend(CountMethods)
  extend(SearchMethods)

  def safeblocked?(user)
    return true if Config.instance.safe_mode? && rating != "s"
    (Config.instance.safe_mode? || user.enable_safe_mode?) && (rating != "s" || has_tag?(*Config.ary(:safeblocked_tags)))
  end

  def deleteblocked?(user)
    !GayFurCity.config.can_user_see_post?(user, self)
  end

  def loginblocked?(user)
    user.is_anonymous? && (hide_from_anonymous? || GayFurCity.config.user_needs_login_for_post?(self))
  end

  def visible?(user)
    return false if loginblocked?(user)
    return false if safeblocked?(user)
    return false if deleteblocked?(user)
    true
  end

  def allow_sample_resize?
    true
  end

  def force_original_size?
    false
  end

  def reupload_url(user)
    h = Rails.application.routes.url_helpers
    others = TagCategory.category_names - %w[artist character species]
    options = {
      "sources":        source_array.join(" "),
      "tags-artist":    artist_tag_array.join(" "),
      "tags-character": character_tags.join(" "),
      "tags-species":   species_tag_array.join(" "),
      "tags":           others.map { |type| public_send("#{type}_tags") }.flatten.join(" "),
      "rating":         rating,
      "rating_locked":  is_rating_locked? && policy(user).can_use_attribute?(:is_rating_locked, :update) ? true : nil,
      "description":    description,
      "parent":         parent_id || id,
    }.compact_blank
    h.new_upload_url(**options)
  end

  def reload(options = nil)
    super
    reset_tag_array_cache
    @locked_to_add = nil
    @locked_to_remove = nil
    @pools = nil
    @post_sets = nil
    @tag_categories = nil
    @typed_tags = nil
    self
  end

  def mark_as_translated(params, user)
    add_tag("translation_check") if params["translation_check"].to_s.truthy?
    remove_tag("translation_check") if params["translation_check"].to_s.falsy?

    add_tag("partially_translated") if params["partially_translated"].to_s.truthy?
    remove_tag("partially_translated") if params["partially_translated"].to_s.falsy?

    if has_tag?("translation_check", "partially_translated")
      add_tag("translation_request")
      remove_tag("translated")
    else
      add_tag("translated")
      remove_tag("translation_request")
    end

    self.updater = user
    save
  end

  def uploader_linked_artists
    artist_tags.filter_map(&:artist).select { |artist| artist.linked_user_id == uploader_id }
  end

  def uploader_name_matches_artists?
    return false if uploader_id.nil? || uploader_linked_artists.any?
    typed_tags(TagCategory.artist).include?(uploader_name.downcase)
  end

  def avoid_posting_artists
    AvoidPosting.active.joins(:artist).where("artists.name": artist_tag_array)
  end

  def followed_tags(user)
    user.followed_tags.joins(:tag).where("tags.name": tag_array)
  end

  def download_filename
    name = id.to_s
    artists = typed_tags(TagCategory.artist)
    copyrights = typed_tags(TagCategory.copyright)
    characters = typed_tags(TagCategory.character)
    species = typed_tags(TagCategory.species)
    name += "-#{artists.join('-')}" if artists.present?
    name += "-#{copyrights.join('-')}" if copyrights.present?
    name += "-#{characters.join('-')}" if characters.present?
    name += "-#{species.join('-')}" if species.present?
    "#{name}.#{file_ext}"
  end

  def self.validate_thumbnail_frame(post, frame)
    max = post.framecount > 1000 ? (post.framecount / 10).ceil : post.framecount
    return [false, max] if post.framecount.blank? || frame < 1 || frame > max
    [true, max]
  end

  def validate_thumbnail_frame
    return if thumbnail_frame.blank?
    valid, max = Post.validate_thumbnail_frame(self, thumbnail_frame)
    unless valid
      if framecount.blank? || framecount == 0
        errors.add(:thumbnail_frame, "cannot be used on posts without a framecount")
        return
      end
      errors.add(:thumbnail_frame, "must be in first 10% of video") if framecount > 1000 && thumbnail_frame > max
      errors.add(:thumbnail_frame, "must be between 1 and #{max}") if thumbnail_frame < 1 || thumbnail_frame > max
    end
  end

  def flaggable_for_guidelines?(_user)
    true
  end

  def is_edit_protected?
    min_edit_level != User::Levels::MEMBER
  end

  def can_edit?(user)
    return true if user == User.system
    user.level >= min_edit_level
  end

  def visible_comment_count(user)
    if user.is_moderator? || !is_comment_disabled?
      comment_count
    else
      comments.visible(user).count
    end
  end

  def self.available_includes
    %i[approver uploader children]
  end
end

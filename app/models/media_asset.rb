# frozen_string_literal: true

require("English")
class MediaAsset < ApplicationRecord
  class DeletionNotSupportedError < StandardError; end
  class ExpungedError < StandardError; end
  RESCALE_REGEX = /(?<name>[a-z\d]+)\s*\(\s*(?<width>\d+|null|nil)\s*,\s*(?<height>\d+|null|nil)\s*,\s*(?<method>none|exact|scaled)\s*\)/
  # method: :scaled, :exact, :none
  Rescale = Struct.new(:width, :height, :method, keyword_init: true) do
    def self.from_string(value)
      p = ->(v) { %w[null nil].include?(v) ? nil : v.to_i }
      value.split(/\s*;\s*/).to_h do |str|
        next unless str =~ RESCALE_REGEX
        method = $LAST_MATCH_INFO[:method].to_sym
        raise(ArgumentError, "Invalid method: #{method}") unless %i[none exact scaled].include?(method)
        [$LAST_MATCH_INFO[:name], new(width: p.call($LAST_MATCH_INFO[:width]), height: p.call($LAST_MATCH_INFO[:height]), method: method)]
      end
    end
  end
  include(ChunkedUpload) # must be near the top due to callbacks

  self.abstract_class = true

  belongs_to_user(:creator, ip: true, clones: :updater)
  resolvable(:updater)
  belongs_to(:media_metadata, dependent: :destroy)

  after_initialize(:build_media_metadata, unless: -> { association(:media_metadata).loaded? || media_metadata_id.present? })
  after_create(:remove_tempfile, if: :file_now?)
  before_destroy(:delete_all_files, if: -> { active? || deleted? }) # check statuses to ensure we don't obliterate existing files
  after_finalize(:remove_tempfile, if: :file_later?)
  after_finalize(:set_file_attributes)
  after_finalize(:check_expunged_duplicates)
  after_finalize(:store_file_finalize, unless: -> { expunged? || duplicate? })
  validates(:md5, uniqueness: { conditions: -> { duplicate_relevant } }, if: :active?)
  validates(:md5, :file_ext, presence: true, if: :active?)
  validates(:is_animated_png, :is_animated_gif, :is_animated_webp, inclusion: { in: [true, false] }, if: :active?)
  validates(:file_size, :image_width, :image_height, presence: true, comparison: { greater_than: 0 }, if: :active?)
  # noinspection RubyArgCount
  validates(:duration, presence: true, comparison: { greater_than: 0 }, if: -> { active? && is_video? })
  validates(:checksum, length: { is: 32 }, if: -> { checksum.present? })
  # noinspection RubyArgCount
  validates(:pixel_hash, presence: true, if: -> { active? && is_image? && !is_animated? })
  validates(:checksum, presence: true, if: -> { in_progress? && file.present? })

  scope(:in_progress, -> { where(status: %w[pending uploading]) })
  scope(:expired, -> { in_progress.where(created_at: ..4.hours.ago) })
  scope(:duplicate_relevant, -> { active })
  scope(:duplicates_of, ->(md5) { duplicate_relevant.where(md5: md5) })
  scope(:expunged_duplicates_of, ->(md5) { expunged.where(md5: md5) })
  scope(:with_metadata, -> { includes(:media_metadata) })
  scope(:images_only, -> { where(file_ext: ::FileMethods::IMAGE_EXTENSIONS) })
  scope(:gifs_only, -> { where(file_ext: ::FileMethods::GIF_EXTENSIONS) })
  scope(:videos_only, -> { where(file_ext: ::FileMethods::VIDEO_EXTENSIONS) })
  scope(:for_creator, ->(user) { where(creator_id: u2id(user)) })

  enum(:status, %i[pending uploading active deleted cancelled expunged replaced failed duplicate].index_with(&:to_s))

  after_initialize { @is_direct = false unless instance_variable_defined?(:@is_direct) }
  attr_accessor(:file, :is_direct, :skip_files)

  class_attribute(:deletion_supported, default: false) # soft deletion
  alias is_direct? is_direct

  def self.prune_expired!
    types = [UploadMediaAsset, PostReplacementMediaAsset]
    types.each do |klass|
      klass.expired.update_all(status: :failed, status_message: "expired after 4 hours")
      klass.expired.find_each(&:remove_tempfile!)
    end
  end

  def file_now?
    !skip_files && active?
  end

  def file_later?
    !skip_files && persisted? && active?
  end

  def is_animated?
    is_animated_png? || !is_animated_gif? || !is_animated_webp?
  end

  def link_to_duplicate
    nil
  end

  def check_expunged_duplicates
    assets = PostReplacementMediaAsset.expunged_duplicates_of(md5) + UploadMediaAsset.expunged_duplicates_of(md5)
    return if assets.empty?
    expunge(User.system)
    # if self.class.connection.transaction_open?
    # CreateExpungedTicketJob.perform_later(self.class.name, id, assets.map(&:id))
    # else
    MediaAsset.notify_expunged_reupload(self, assets)
    # end
  end

  def self.notify_expunged_reupload(asset, duplicates)
    # TODO: reimplement ability to disable notifications
    # return if notify == false
    reason = "User tried to re-upload previously expunged media asset:"
    duplicates.each do |d|
      reason += "\n * \"#{d.class.name.underscore.humanize.downcase} #{d.id}\":/media_assets/#{d.class.name.gsub('MediaAsset', '').underscore}s?search[id]=#{d.id}"
    end

    if asset.is_post_replacement? && asset.post_replacement.present?
      reason += " as a replacement for post ##{asset.post_replacement.post_id}"
      reason += "\n* \"post replacement ##{asset.post_replacement.id}\":/posts/replacements/#{asset.post_replacement.id}"
      reason += "\n* post ##{asset.post_replacement.post_id}"
    elsif asset.is_upload?
      reason += "\n* \"upload ##{asset.upload.id}\":/uploads/#{asset.upload.id}" if asset.upload.present?
      reason += "\n* post ##{asset.post.id}" if asset.post.present?
    end
    NotifyExpungedMediaAssetReuploadJob.perform_later(asset.creator, reason)
  end

  def is_post_replacement?
    is_a?(PostReplacementMediaAsset)
  end

  def is_upload?
    is_a?(UploadMediaAsset)
  end

  def is_mascot?
    is_a?(MascotMediaAsset)
  end

  def has_variants?
    is_a?(MediaAssetWithVariants)
  end

  def self.model
    name.delete_suffix("MediaAsset").constantize
  end

  def in_progress?
    %w[pending uploading].include?(status)
  end

  module FileMethods
    # get_file is in ::FileMethods

    def open_file(&)
      storage_manager.open(file_path, &)
    end

    def load_file!
      self.file ||= open_file
    end

    def is_protected?
      # avoid circular lookups to the post, not ideal but it's better than loading each post twice and causing N+1 queries
      is_upload? && ((association(:post).loaded? && post&.protect_file?) || deleted?)
    end

    def hierarchical?
      is_upload? || is_post_replacement? ? :default : false
    end

    def validate_file
      FileValidator.new(self, file.path).validate
    end

    def set_file_attributes
      self.file_ext = self.class.file_header_to_file_ext(file.path)
      self.file_size = file.size
      self.md5 = file_md5
      self.pixel_hash = file_pixel_hash
      self.is_animated_png = MediaAsset.is_animated_png?(file.path)
      self.is_animated_gif = MediaAsset.is_animated_gif?(file.path)
      self.is_animated_webp = MediaAsset.is_animated_webp?(file.path)
      update_metadata

      self.duration = media_metadata.duration
      self.framecount = media_metadata.duration.present? ? media_metadata.duration * media_metadata.frame_rate : nil
      self.image_width = media_metadata.width
      self.image_height = media_metadata.height
    end

    def reset_file_attributes!
      load_file!
      set_file_attributes
      media_metadata.save!
      save!
    end

    def metadata(file = self.file)
      if is_video?
        file.present? ? self.class.video_metadata(file.path) : video_metadata
      elsif is_gif?
        file.present? ? self.class.gif_metadata(file.path) : gif_metadata
      elsif is_webp?
        file.present? ? self.class.webp_metadata(file.path) : webp_metadata
      elsif is_image?
        file.present? ? self.class.image_metadata(file.path) : image_metadata
      end
    end

    def update_metadata
      media_metadata.metadata = metadata
    end

    def update_metadata!
      update_metadata
      media_metadata.save!
    end
  end

  module StorageMethods
    def store_file_finalize
      raise(StandardError, "file not present") if file.nil?
      check_duplicates
      return if duplicate?
      store(file)
    end

    def check_post_and_replacement_duplicates
      posts = UploadMediaAsset.duplicates_of(md5)
      replacements = PostReplacementMediaAsset.duplicates_of(md5)
      if is_upload? && upload.present? && upload.replacement_id.present?
        replacements = replacements.where.not("post_replacements.id": upload.replacement_id)
      elsif is_post_replacement? && backup_post_id.present?
        posts = posts.where.not("posts.id": backup_post_id)
      end
      duplicates = posts + replacements
      return if duplicates.none?
      self.status = "duplicate"
      items = []
      duplicates.each do |dup|
        if dup.is_upload? && dup.post.present?
          items << "post ##{dup.post.id}"
        elsif dup.is_upload? && dup.upload.present?
          items << "upload ##{dup.upload.id}"
        elsif dup.is_post_replacement? && dup.post_replacement.present?
          items << "post replacement ##{dup.post_replacement.id}"
        else
          items << "#{dup.class.name.underscore.humanize.downcase} ##{dup.id}"
        end
      end

      self.status_message = "duplicate of #{items.join(', ')}"
    end

    def check_duplicates
      return check_post_and_replacement_duplicates if [UploadMediaAsset, PostReplacementMediaAsset].include?(self.class)
      duplicates = self.class.duplicates_of(md5)
      return if duplicates.none?
      self.status = "duplicate"
      items = []
      case self
      when UploadMediaAsset
        items += duplicates.includes(:post).map { |d| d.post.present? ? "post ##{d.post.id}" : "upload media asset ##{d.id}" }
      when PostReplacementMediaAsset
        items += duplicates.includes(:post_replacement).map { |d| d.post_replacement.present? ? "post replacement ##{d.post_replacement.id}" : "post replacement media asset ##{d.id}" }
      when MascotMediaAsset
        items += duplicates.includes(:mascot).map { |d| d.mascot.present? ? "mascot ##{d.mascot.id}" : "mascot media asset ##{d.id}" }
      else
        items += duplicates.map { |d| "media asset ##{d.id}" }
      end

      self.status_message = "duplicate of #{items.join(', ')}" if items.any?
    end

    def delete_all_files
      expunge(nil, status: false)
    end

    def storage_manager
      GayFurCity.config.storage_manager.instance
    end

    def backup_storage_manager
      GayFurCity.config.backup_storage_manager.instance
    end

    def path_prefix
      ""
    end

    def protected_path_prefix
      ""
    end

    def protected_secret
      GayFurCity.config.protected_file_secret
    end

    def file_path(protected: is_protected?)
      storage_manager.file_path(md5, file_ext, :original, protected: protected, prefix: path_prefix, hierarchical: hierarchical?)
    end

    def backup_file_path(protected: is_protected?)
      backup_storage_manager.file_path(md5, file_ext, :original, protected: protected, prefix: path_prefix, hierarchical: hierarchical?)
    end

    def file_url(user:, protected: is_protected?)
      storage_manager.url(md5, file_ext, :original, protected: protected, prefix: path_prefix, hierarchical: hierarchical?, secret: protected_secret, user: user)
    end

    def store(user, file = self.file)
      self.file = file
      validate_file
      if errors.any?
        self.status = "failed"
        self.status_message = errors.full_messages.join("; ")
        self.updater = user
        return
      end
      set_file_attributes
      storage_manager.store(file, file_path)
      backup_storage_manager.store(file, backup_file_path)
    end

    def store!(...)
      store(...)
      save!
    end

    def delete(user)
      raise(MediaAsset::DeletionNotSupportedError, "deletion of #{self.class.name} is not supported") unless self.class.deletion_supported
      self.status = "deleted"
      self.updater = user
      storage_manager.move_file_delete(md5, file_ext, :original, prefix: path_prefix, protected_prefix: protected_path_prefix, hierarchical: hierarchical?)
      backup_storage_manager.move_file_delete(md5, file_ext, :original, prefix: path_prefix, protected_prefix: protected_path_prefix, hierarchical: hierarchical?)
    end

    def delete!(...)
      delete(...)
      save!
    end

    def undelete(user)
      raise(MediaAsset::DeletionNotSupportedError, "deletion of #{self.class.name} is not supported") unless self.class.deletion_supported
      self.status = "active"
      self.updater = user
      storage_manager.move_file_undelete(md5, file_ext, :original, prefix: path_prefix, protected_prefix: protected_path_prefix, hierarchical: hierarchical?)
      backup_storage_manager.move_file_undelete(md5, file_ext, :original, prefix: path_prefix, protected_prefix: protected_path_prefix, hierarchical: hierarchical?)
    end

    def undelete!(...)
      undelete(...)
      save!
    end

    def expunge(user, status: true)
      if status && !destroyed?
        self.status = "expunged"
        self.status_message = "has been deleted and cannot be reuploaded"
        self.updater = user
      end
      storage_manager.delete(file_path(protected: false))
      storage_manager.delete(file_path(protected: true))
      backup_storage_manager.delete(backup_file_path(protected: false))
      backup_storage_manager.delete(backup_file_path(protected: true))
    end

    def expunge!(...)
      expunge(...)
      save!
    end
  end

  module SearchMethodsnas
    def query_dsl
      super
        .field(:checksum)
        .field(:md5)
        .field(:file_ext)
        .field(:pixel_hash)
        .field(:status)
        .field(:status_message_matches, :status_message)
        .field(:ip_addr, :creator_ip_addr)
        .field(:"#{model.name.underscore}_id", "#{model.table_name}.id") { |q| q.joins(model.name.underscore.to_sym) }
        .association(:creator)
        .association(model.name.underscore.to_sym)
    end
  end

  include(StorageMethods)
  include(FileMethods)
  include(::FileMethods)
  extend(SearchMethods)

  def visible?(user)
    user.is_staff? || creator_id == user.id
  end

  def file_visible?(user)
    visible?(user) && (user.is_staff? || !is_protected?)
  end

  def pretty_status
    status_message.presence || status
  end

  def format_status
    return status if status_message.blank?
    "#{status}: #{status_message}"
  end

  DELEGATED = %i[is_png? is_jpeg? is_gif? is_webp? is_webm? is_mp4? is_image? is_video? is_animated_png? is_animated_gif? is_animated_webp? is_corrupt? is_ai_generated?
                 file_path file_url md5 file_ext file_size image_width image_height duration framecount pixel_hash checksum].freeze
  module DelegateProperties
    delegate(*DELEGATED, to: :media_asset)

    module Nullable
      delegate(*DELEGATED, to: :media_asset, allow_nil: true)
    end
  end
end

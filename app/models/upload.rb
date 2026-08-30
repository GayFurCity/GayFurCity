# frozen_string_literal: true

require("tmpdir")

class Upload < ApplicationRecord
  class Error < StandardError; end
  has_media_asset(:upload_media_asset)

  attr_accessor(:as_pending, :as_in_progress, :original_post_id, :locked_rating, :locked_tags, :is_replacement, :replacement_id,
                :ungrouped_tag_string, :character_groups_attributes)

  belongs_to_user(:uploader, ip: true, aliases: :creator)
  belongs_to(:post, optional: true)

  after_initialize(:set_locked_tags)
  before_validation(:assign_rating_from_tags)
  before_validation(:normalize_direct_url, on: :create)

  validate(:uploader_is_not_limited, on: :create)
  validate(:direct_url_is_whitelisted, on: :create)
  validate(:no_excessive_pending_uploads, on: :create)
  validates(:rating, inclusion: { in: %w[q e s] }, allow_nil: false)

  scope(:pending, -> { joins(:upload_media_asset).where("upload_media_asset.status": "pending") })
  scope(:uploading, -> { joins(:upload_media_asset).where("upload_media_asset.status": "uploading") })
  scope(:completed, -> { joins(:upload_media_asset).where("upload_media_asset.status": "active") })
  scope(:in_progress, -> { joins(:upload_media_asset).where("upload_media_asset.status": %w[pending uploading]) })

  delegate(:duplicate_post_id, :status, :status_message, :pretty_status,
           :pending?, :uploading?, :active?, :deleted?, :cancelled?, :expunged?, :failed?, :duplicate?, to: :media_asset, allow_nil: true)

  def set_locked_tags
    self.locked_tags ||= ""
  end

  module DirectURLMethods
    def normalize_direct_url
      return if direct_url.blank?
      self.direct_url = direct_url.unicode_normalize(:nfc)
      if direct_url =~ %r{\Ahttps?://}i
        self.direct_url = begin
          Addressable::URI.normalized_encode(direct_url)
        rescue StandardError
          direct_url
        end
      end
      self.direct_url = begin
        Sources::Strategies.find(direct_url).canonical_url
      rescue StandardError
        direct_url
      end
    end

    def direct_url_parsed
      return nil unless direct_url =~ %r{\Ahttps?://}i
      begin
        Addressable::URI.heuristic_parse(direct_url)
      rescue StandardError
        nil
      end
    end
  end

  module SearchMethods
    def post_tags_match(query, user)
      where(post_id: Post.tag_match_sql(query, user))
    end

    def query_dsl
      super
        .field(:source)
        .field(:source_matches, :source, like: true)
        .field(:rating)
        .field(:parent_id)
        .field(:post_id)
        .field(:status, "upload_media_assets.status") { |q| q.joins(:upload_media_asset) }
        .field(:ip_addr, :uploader_ip_addr)
        .present(:has_post, :post_id)
        .custom(:post_tags_match, ->(q, v, user) { q.post_tags_match(v, user) })
        .field(:backtrace, like: true)
        .field(:tag_string, like: true)
        .association(:uploader)
    end
  end

  include(DirectURLMethods)
  extend(SearchMethods)

  def uploader_is_not_limited
    return if replacement_id.present?
    uploadable = uploader.can_upload_with_reason
    if uploadable != true
      errors.add(:uploader, User.upload_reason_string(uploadable))
      return false
    end
    true
  end

  def no_excessive_pending_uploads
    if Upload.in_progress.where(uploader_id: uploader_id).count >= AdminConfig.instance.pending_uploads_limit
      errors.add(:base, "You have too many pending uploads. Finish or cancel your existing uploads and try again")
      return false
    end
    true
  end

  def direct_url_is_whitelisted
    return true if direct_url_parsed.blank?
    valid, reason = UploadWhitelist.is_whitelisted?(direct_url_parsed, uploader)
    unless valid
      errors.add(:source, "is not whitelisted: #{reason}")
      return false
    end
    true
  end

  def assign_rating_from_tags
    if (rating = TagQuery.fetch_metatag(tag_string, "rating"))
      self.rating = rating.downcase.first
    end
  end

  def presenter
    @presenter ||= UploadPresenter.new(self)
  end

  def upload_as_pending?
    as_pending.to_s.truthy?
  end

  def upload_as_in_progress?
    as_in_progress.to_s.truthy?
  end

  def visible?(user)
    user.is_janitor?
  end

  def convert_to_post
    Post.new.tap do |p|
      p.tag_string = tag_string
      p.ungrouped_tag_string = ungrouped_tag_string
      p.character_groups_attributes = character_groups_attributes
      p.original_tag_string = tag_string
      p.locked_tags = locked_tags
      p.is_rating_locked = locked_rating if locked_rating.present?
      p.description = description.strip
      p.rating = rating
      p.source = source
      p.uploader = uploader
      p.parent_id = parent_id
      p.upload_url = direct_url
      p.media_asset = media_asset

      if upload_as_in_progress? && uploader.can_upload_in_progress?
        p.is_in_progress = true
      elsif !uploader.unrestricted_uploads? || (!uploader.can_approve_posts? && p.avoid_posting_artists.any?) || upload_as_pending?
        p.is_pending = true
      end
    end
  end

  # this overrides a rails method, but we should never need it
  def create_post
    return post if reload_post.present?
    @post = convert_to_post
    @post.save!
    update(post_id: @post.id)
    reload_post
    @post.reload
  end

  def self.available_includes
    %i[post uploader]
  end
end

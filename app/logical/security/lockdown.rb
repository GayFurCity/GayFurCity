# frozen_string_literal: true

module Security
  module Lockdown
    module_function

    def add_boolean(name, redis = name)
      define_singleton_method("#{name}?") do
        Cache.redis.get(redis).to_s.truthy?
      rescue Redis::CannotConnectError
        true
      end

      define_singleton_method("#{name}=") do |value|
        Cache.redis.set(redis, value.to_s.truthy?)
      end
    end

    BOOLEAN_TYPES = %w[uploads post_replacements pools post_sets comments forums aiburs favorites votes discord].freeze
    BOOLEAN_TYPES.each { |t| add_boolean("#{t}_disabled") }

    # Uploader level override
    def uploads_min_level
      (Cache.redis.get("min_upload_level") || User::Levels::MEMBER).to_i
    rescue Redis::CannotConnectError
      User::Levels::LOCKED
    end

    def uploads_min_level=(min_upload_level)
      Cache.redis.set("min_upload_level", min_upload_level)
    end

    # Hiding pending posts
    def self.hide_pending_posts_for
      Cache.redis.get("hide_pending_posts_for").to_i
    rescue Redis::CannotConnectError
      PostPruner::MODERATION_WINDOW.days
    end

    def self.hide_pending_posts_for=(duration)
      Cache.redis.set("hide_pending_posts_for", duration)
    end

    def self.post_visible?(post, user)
      return true if hide_pending_posts_for <= 0
      post.uploader_id == user.id || user.is_staff? || !post.is_pending? || post.created_at.before?(hide_pending_posts_for.hours.ago)
    end
  end
end

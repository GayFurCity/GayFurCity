# frozen_string_literal: true

class TagFollower < ApplicationRecord
  class AliasedTagError < StandardError; end
  belongs_to(:tag)
  belongs_to_user(:user, counter_cache: "followed_tag_count")
  belongs_to(:last_post, class_name: "Post", optional: true)
  validate(:validate_user_can_follow_tags, on: :create)
  validate(:validate_tag_is_not_aliased, on: :create)
  after_create(:set_latest_post, unless: -> { last_post_id.present? })
  after_commit(:update_tag_follower_count, on: %i[create destroy])
  delegate(:name, to: :tag, prefix: true)
  scope(:unbanned, -> { joins(:user).where.gt("users.level": User::Levels::BANNED) })

  def set_latest_post(exclude: nil)
    post = Post.sql_raw_tag_match(tag_name).order(id: :asc)
    post = post.where.not(id: exclude) if exclude.present?
    post = post.last
    return false if post.nil?
    update(last_post: post) if post
    true
  end

  def update_tag_follower_count
    Tag.update(tag_id, follower_count: TagFollower.where(tag_id: tag_id).count)
  end

  def validate_tag_is_not_aliased
    if tag.antecedent_alias.present?
      errors.add(:tag, "cannot be aliased")
    end
  end

  def validate_user_can_follow_tags
    limit = AdminConfig.get_user(:followed_tag_limit, user)
    if user.followed_tags.count >= limit
      errors.add(:user, "cannot follow more than #{limit} tags")
    end
  end

  def self.recount_all!
    group(:tag_id).count.each do |tag_id, count|
      Tag.update(tag_id, follower_count: count)
    end
  end

  def self.update_from_post!(post)
    transaction do
      followers = where(tag_id: post.tag_ids).and(where.lt(last_post_id: post.id)).unbanned
      followers.each do |follower|
        follower.user.notifications.create!(category: :new_post, data: { post_id: post.id, tag_name: follower.tag_name }) unless follower.user_id == post.uploader_id
        follower.update!(last_post: post)
      end
    end
  end

  def self.available_includes
    %i[tag user]
  end

  def visible?(user)
    user.is_moderator? || !user.enable_privacy_mode? || user_id == user.id
  end
end

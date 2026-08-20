# frozen_string_literal: true

class ForumCategory < ApplicationRecord
  MAX_TOPIC_MOVE_COUNT = 1000
  has_many(:topics, -> { order(id: :desc) }, class_name: "ForumTopic", foreign_key: :category_id)
  has_many(:posts, through: :topics)
  has_one(:last_topic, -> { order(id: :desc) }, class_name: "ForumTopic", foreign_key: :category_id)
  has_one(:last_post, through: :last_topic)
  validates(:name, uniqueness: { case_sensitive: false }, length: { minimum: 3, maximum: 100 })
  validates(:description, length: { maximum: -> { Config.instance.forum_category_description_max_size } })
  belongs_to_user(:creator, ip: true, clones: :updater)
  belongs_to_user(:updater, ip: true)
  resolvable(:destroyer)

  after_create(:log_create)
  after_update(:log_update)
  before_destroy(:prevent_destroy_if_topics)
  after_destroy(:log_delete)

  before_validation(on: :create) do
    self.order = (ForumCategory.maximum(:order) || 0) + 1 if order.blank?
  end

  attr_accessor(:new_category_id) # technical bullshit

  scope(:viewable, ->(user) { where.lteq(can_view: user.level) })
  scope(:replyable, ->(user) { where.lteq(can_reply: user.level) })

  def can_create_within?(user)
    user.level >= can_create
  end

  def self.reverse_mapping
    order(:order).all.map { |rec| [rec.name, rec.id] }
  end

  def self.ordered_categories
    order(:order)
  end

  def prevent_destroy_if_topics
    if topics.any?
      errors.add(:base, "Forum category cannot be deleted because it has topics")
      throw(:abort)
    end
  end

  modactions(:forum_category)
    .add(:create, :creator, on: :create) { { forum_category_name: name, can_view: can_view, can_create: can_create } }
    .add(:update, :updater, on: :update) do
      {
        forum_category_name: name, old_forum_category_name: name_before_last_save,
        can_view: can_view, old_can_view: can_view_before_last_save,
        can_create: can_create, old_can_create: can_create_before_last_save,
      }
    end
    .add(:delete, :destroyer, on: :destroy) { { forum_category_name: name, can_view: can_view, can_create: can_create } }

  def self.log_reorder(total, user)
    ModAction.log!(user, :forum_categories_reorder, nil, total: total)
  end

  def visible?(user)
    user.level >= can_view
  end

  def can_move_topics?
    topics.count <= ForumCategory::MAX_TOPIC_MOVE_COUNT
  end

  def move_all_topics(new_category, user)
    return if topics.empty?
    MoveForumCategoryTopicsJob.perform_later(user, self, new_category)
  end

  def unread?(user)
    return false if user.is_anonymous?
    last_read_at = user.forum_category_visits.where(forum_category: self).first&.last_read_at
    max_updated_at = topics.visible(user).unmuted(user).reorder(last_post_created_at: :desc).pick(:last_post_created_at)
    return false if max_updated_at.nil?
    return true if last_read_at.nil?
    max_updated_at > last_read_at
  end

  def mark_topic_as_read!(user, topic)
    return if user.is_anonymous?
    visit = user.forum_category_visits.find_by(forum_category: self)
    return if visit && visit.last_read_at >= topic.last_post_created_at
    visit ||= user.forum_category_visits.create!(forum_category: self)
    visit.update!(last_read_at: topic.last_post_created_at)
  end

  def mark_as_read!(user)
    return if user.is_anonymous?
    user.forum_category_visits.find_or_create_by!(forum_category: self).update!(last_read_at: Time.now)
  end

  def self.mark_all_as_read!(user)
    ForumCategory.find_each do |category|
      category.mark_as_read!(user)
    end
  end

  def last_read_at_for(user)
    user.forum_category_visits.select(:last_read_at).find_by(forum_category: self)&.last_read_at
  end

  def self.available_includes
    %i[topics posts]
  end
end

# frozen_string_literal: true

class ForumPost < ApplicationRecord
  simple_versioning
  mentionable
  warnable
  has_dtext_links(:body)
  belongs_to_user(:creator, ip: true, clones: :updater, counter_cache: "forum_post_count")
  belongs_to_user(:updater, ip: true)
  resolvable(:destroyer)
  belongs_to(:topic, class_name: "ForumTopic")
  has_one(:category, through: :topic)
  belongs_to(:original_topic, class_name: "ForumTopic", optional: true)
  belongs_to_user(:warning_user, optional: true)
  has_many(:votes, class_name: "ForumPostVote")
  has_many(:tickets, as: :model)
  has_many(:versions, class_name: "EditHistory", as: :versionable, dependent: :destroy)
  has_one(:spam_ticket, -> { spam }, class_name: "Ticket", as: :model)
  has_one(:last_edit_version, -> { edit_type("edit").order(created_at: :desc) }, class_name: "EditHistory", as: :versionable)

  belongs_to(:tag_change_request, polymorphic: true, optional: true)
  before_validation(:initialize_is_hidden, on: :create)
  before_create(:auto_report_spam)
  after_create(:update_topic_updated_at_on_create)
  # no counter cache since we're more than one association away
  after_create(-> { category.increment!(:post_count) })
  before_destroy(:validate_topic_is_unlocked_on_destroy)
  after_destroy(:update_topic_updated_at_on_destroy)
  after_destroy(-> { category.decrement!(:post_count) })
  after_save(:log_voting_change, if: :saved_change_to_allow_voting?, unless: :destroyed?)
  normalizes(:body, with: ->(body) { body.gsub("\r\n", "\n") })
  validates(:body, :creator_id, presence: true)
  validates(:body, length: { minimum: 1, maximum: -> { AdminConfig.instance.forum_post_max_size } })
  validate(:validate_topic_is_unlocked)
  validate(:validate_topic_id_not_invalid)
  validate(:validate_topic_is_not_restricted, on: :create)
  validate(:validate_topic_is_not_stale, on: :create)
  validate(:validate_category_allows_replies, on: :create)
  validate(:validate_creator_is_not_limited, on: :create)
  validate(:validate_not_aibur, if: :will_save_change_to_is_hidden?)
  after_save(:hide_topic_if_original_post)

  attr_accessor(:bypass_limits, :is_merging)

  scope(:votable, -> { where(allow_voting: true) })

  modactions(:forum_post)
    .add(:hide, :updater, on: :update, if: -> { updater_id != creator_id && saved_change_to_is_hidden? && is_hidden? }) { { forum_topic_id: topic_id, user_id: creator_id } }
    .add(:unhide, :updater, on: :update, if: -> { saved_change_to_is_hidden? && !is_hidden? }) { { forum_topic_id: topic_id, user_id: creator_id } }
    .add(:update, :updater, on: :update, if: -> { updater_id != creator_id && !saved_change_to_is_hidden? && !is_merging }) { { forum_topic_id: topic_id, user_id: creator_id } }
    .add(:delete, :destroyer, on: :destroy) { { forum_topic_id: topic_id, user_id: creator_id } }

  def log_voting_change
    if allow_voting?
      save_version("enabled_voting")
    else
      save_version("disabled_voting")
    end
  end

  module SearchMethods
    def not_visible(user)
      where.not(id: visible(user))
    end

    def permitted(user)
      q = joins(topic: :category).merge(ForumCategory.viewable(user))
      q = q.joins(:topic).where("forum_topics.is_hidden": false).or(q.joins(:topic).where("forum_topics.creator_id": user.id)) unless user.is_moderator?
      q
    end

    def active(user)
      return all if user.is_moderator?
      where("forum_posts.is_hidden": false).or(where("forum_posts.creator_id": user.id))
    end

    def apply_order(params)
      order_with({
        rating: { percentage_score: :desc },
        score:  { total_score: :desc },
      }, params[:order])
    end

    def query_dsl
      super
        .field(:topic_id)
        .field(:body_matches, :body)
        .field(:is_hidden)
        .field(:topic_title_matches, "forum_topics.title") { |q| q.joins(:topic) }
        .field(:topic_category_id, "forum_topics.category_id") { |q| q.joins(:topic) }
        .field(:ip_addr, :creator_ip_addr)
        .field(:updater_ip_addr)
        .custom(:linked_to, ->(q, v) { q.linked_to(v) })
        .custom(:not_linked_to, ->(q, v) { q.not_linked_to(v) })
        .association(:creator)
        .association(:updater)
        .association(:topic)
    end
  end

  extend(SearchMethods)

  def has_voting?
    allow_voting?
  end

  def voting_active?
    has_voting? && (!is_aibur? || tag_change_request.is_pending?)
  end

  def is_aibur?
    tag_change_request.present?
  end

  def validate_topic_is_unlocked_on_destroy
    return if destroyer.is_moderator? || topic.nil?

    if topic.is_locked?
      errors.add(:topic, "is locked")
      throw(:abort)
    end
  end

  def validate_topic_is_unlocked
    return if updater.is_moderator? || topic.nil? || changes.blank?

    if topic.is_locked?
      errors.add(:topic, "is locked")
      throw(:abort)
    end
  end

  def validate_creator_is_not_limited
    return if bypass_limits

    allowed = creator.can_forum_post_with_reason
    if allowed != true
      errors.add(:creator, User.throttle_reason(allowed))
      throw(:abort)
    end
  end

  def validate_not_aibur
    return if updater.is_moderator? || !is_aibur?

    if is_hidden?
      errors.add(:post, "is for an alias, implication, or bulk update request. It cannot be hidden")
      throw(:abort)
    end
  end

  def validate_topic_is_not_stale
    return if !topic&.is_stale_for?(creator) || bypass_limits
    errors.add(:topic, "is stale. New posts cannot be created")
    throw(:abort)
  end

  def validate_topic_id_not_invalid
    if topic_id && !topic
      errors.add(:topic_id, "is invalid")
      throw(:abort)
    end
  end

  def validate_topic_is_not_restricted
    if topic && !topic.visible?(creator)
      errors.add(:topic, "is restricted")
      throw(:abort)
    end
  end

  def validate_category_allows_replies
    if topic && !topic.can_reply?(creator)
      errors.add(:topic, "does not allow replies")
      throw(:abort)
    end
  end

  def editable_by?(user)
    return true if user.is_admin?
    return false if was_warned? || (is_aibur? && !tag_change_request.is_pending?)
    return false if topic && !topic.can_reply?(user) # prevent editing if the category can_create level was changed after creation
    creator_id == user.id && visible?(user)
  end

  def can_hide?(user)
    return true if user.is_moderator?
    return false if is_aibur?
    return false if topic && !topic.can_reply?(user) # prevent hiding if the category can_create level was changed after creation
    user.id == creator_id
  end

  def can_delete?(user)
    user.is_admin?
  end

  def update_topic_updated_at_on_create
    if topic
      # need to do this to bypass the topic's original post from getting touched
      # reloading the topic in any way will cause undoing merges to fail due to force validating the original post
      ForumTopic.where(id: topic.id).update_all(updated_at: created_at, last_post_created_at: created_at)
      unless is_original_post?
        topic.response_count += 1
        ForumTopic.where(id: topic.id).update_all("response_count = response_count + 1")
      end
    end
  end

  def hide!(user)
    update(is_hidden: true, updater: user)
    update_topic_updated_at_on_hide
  end

  def unhide!(user)
    update(is_hidden: false, updater: user)
    update_topic_updated_at_on_hide
  end

  def update_topic_updated_at_on_hide
    max = ForumPost.where(topic_id: topic.id, is_hidden: false).order(updated_at: :desc).first
    if max
      ForumTopic.where(id: topic.id).update_all(["updated_at = ?, updater_id = ?", max.updated_at, max.updater_id])
    end
  end

  def update_topic_updated_at_on_destroy
    max = ForumPost.where(topic_id: topic.id, is_hidden: false).order(updated_at: :desc).first
    if max
      ForumTopic.where(id: topic.id).update_all(["response_count = response_count - 1, updated_at = ?, updater_id = ?", max.updated_at, max.updater_id])
    else
      ForumTopic.where(id: topic.id).update_all("response_count = response_count - 1")
    end
    topic.response_count -= 1
  end

  def initialize_is_hidden
    self.is_hidden = false if is_hidden.nil?
  end

  def forum_topic_page
    Cache.fetch("fp_topic_page:#{id}", expires_in: 12.hours) do
      (ForumPost.where("topic_id = ? and created_at <= ?", topic_id, created_at).count / AdminConfig.instance.records_per_page.to_f).ceil
    end
  end

  def is_original_post?(original_post_id = nil)
    if original_post_id
      id == original_post_id
    else
      ForumPost.exists?(["id = ? and id = (select _.id from forum_posts _ where _.topic_id = ? order by _.id asc limit 1)", id, topic_id])
    end
  end

  def hide_topic_if_original_post
    if is_hidden? && is_original_post?
      topic.update_attribute(:is_hidden, true)
    end

    true
  end

  def hidden_at
    return nil unless is_hidden?
    versions.hidden.last&.created_at
  end

  def warned_at
    return nil unless was_warned?
    versions.marked.last&.created_at
  end

  def edited_at
    last_edit_version&.created_at
  end

  def auto_report_spam
    if SpamDetector.new(self, user_ip: creator_ip_addr.to_s).spam?
      self.is_spam = true
      tickets << Ticket.new(creator: User.system, creator_ip_addr: "127.0.0.1", reason: "Spam.")
    end
  end

  def mark_spam!(user)
    return if is_spam?
    update!(is_spam: true, updater: user)
    return if spam_ticket.present?
    SpamDetector.new(self, user_ip: creator_ip_addr.to_s).spam!
  end

  def mark_not_spam!(user)
    return unless is_spam?
    update!(is_spam: false, updater: user)
    return if spam_ticket.blank?
    SpamDetector.new(self, user_ip: creator_ip_addr.to_s).ham!
  end

  def self.available_includes
    %i[creator updater topic dtext_links tag_change_request]
  end

  def visible?(user)
    topic.visible?(user) && (user.is_moderator? || !is_hidden? || user.id == creator_id)
  end

  def is_merged?
    merged_at.present?
  end

  def self.update_scores(id: nil)
    if id.present? && ForumPostVote.for_forum_post(id).none?
      ForumPost.where(id: id).update_all("total_score = 0, percentage_score = 0, total_votes = 0, up_votes = 0, down_votes = 0, meh_votes = 0")
      return
    end
    # yes, I spent far too long on this
    query = <<~SQL.squish.strip
      UPDATE forum_posts
      SET total_score = votes.total_score,
          percentage_score = CASE
              WHEN votes.total_count > 0
              THEN (votes.up_count * 100.0) / votes.total_count
              ELSE 0
          END,
          total_votes = votes.total_count,
          up_votes = votes.up_count,
          down_votes = votes.down_count,
          meh_votes = votes.meh_count
      FROM (
          SELECT forum_post_id,
                 SUM(score) AS total_score,
                 COUNT(*) AS total_count,
                 COUNT(*) FILTER (WHERE score = 1) AS up_count,
                 COUNT(*) FILTER (WHERE score = -1) AS down_count,
                 COUNT(*) FILTER (WHERE score = 0) AS meh_count
          FROM forum_post_votes
          #{"WHERE forum_post_id = #{id}" if id}
          GROUP BY forum_post_id
      ) AS votes
      WHERE forum_posts.id = votes.forum_post_id;
    SQL
    ForumPost.connection.execute(query)
  end

  def topic_link
    Routes.forum_topic_path(topic_id, page: forum_topic_page, anchor: "forum_post_#{id}")
  end
end

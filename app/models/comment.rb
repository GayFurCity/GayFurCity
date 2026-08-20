# frozen_string_literal: true

class Comment < ApplicationRecord
  RECENT_COUNT = 6

  simple_versioning
  mentionable
  warnable
  belongs_to_user(:creator, ip: true, clones: :updater, counter_cache: "comment_count")
  belongs_to_user(:updater, ip: true)
  belongs_to_user(:warning_user, optional: true)
  resolvable(:destroyer)
  normalizes(:body, with: ->(body) { body.gsub("\r\n", "\n") })
  validate(:validate_post_exists, on: :create)
  validate(:validate_creator_is_not_limited, on: :create)
  validate(:post_not_comment_restricted, on: :create)
  validates(:body, presence: { message: "has no content" })
  validates(:body, length: { minimum: 1, maximum: -> { Config.instance.comment_max_size } })

  before_create(:auto_report_spam)
  after_create(:update_last_commented_at_on_create)
  after_destroy(:update_last_commented_at_on_destroy)
  after_save(:update_last_commented_at_on_destroy, if: ->(rec) { rec.is_hidden? && rec.saved_change_to_is_hidden? })

  modactions(:comment)
    .add(:update, :updater, on: :update, if: -> { updater_id != creator_id && !saved_change_to_is_hidden? }) { { user_id: creator_id } }
    .add(:hide, :updater, on: :update, if: -> { updater_id != creator_id && saved_change_to_is_hidden? && is_hidden? }) { { user_id: creator_id } }
    .add(:unhide, :updater, on: :update, if: -> { saved_change_to_is_hidden? && !is_hidden? }) { { user_id: creator_id } }
    .add(:delete, :destroyer, on: :destroy) { { user_id: creator_id, post_id: post_id } }

  belongs_to(:post, counter_cache: :comment_count)
  has_many(:votes, class_name: "CommentVote", dependent: :destroy)
  has_many(:tickets, as: :model)
  has_many(:versions, class_name: "EditHistory", as: :versionable, dependent: :destroy)
  has_one(:spam_ticket, -> { spam }, class_name: "Ticket", as: :model)

  scope(:deleted, -> { where(is_hidden: true) })
  scope(:not_deleted, -> { where(is_hidden: false) })
  scope(:stickied, -> { where(is_sticky: true) })

  module SearchMethods
    def recent
      reorder(id: :desc).limit(RECENT_COUNT)
    end

    def hidden(user)
      if user.is_moderator?
        where("not(comments.score >= ? or comments.is_sticky = true)", user.comment_threshold)
      else
        where("not((comments.score >= ? or comments.is_sticky = true) and (comments.is_hidden = false or comments.creator_id = ?))", user.comment_threshold, user.id)
      end
    end

    def post_tags_match(query, user)
      return all if query.nil?
      joins(:post).merge(Post.tag_match_sql(query, user))
    end

    def apply_order(params)
      # Force a better query plan
      if params[:order].blank? && %i[body_matches creator_name creator_id].any? { |key| params[key].present? }
        order(created_at: :desc)
      else
        order_with(%i[post_id score], params[:order])
      end
    end

    def query_dsl
      super
        .field(:body_matches, :body)
        .field(:post_id)
        .field(:ip_addr, :creator_ip_addr)
        .field(:updater_ip_addr)
        .field(:is_hidden)
        .field(:is_sticky)
        .field(:is_spam)
        # Force a better query plan by ordering by created_at
        # .user(:poster, "posts.uploader_id") { |q| q.joins(:post).reorder(created_at: :desc) }
        .custom(:post_tags_match, ->(q, v, user) { q.post_tags_match(v, user) })
        .custom(:post_note_updater_id, ->(q, v) { q.where(post_id: NoteVersion.select(:post_id).where(updater_id: v.to_s.split(",").map(&:to_i))) })
        .custom(:post_note_updater_name, ->(q, v) { q.where(post_id: NoteVersion.select(:post_id).user_name_matches(:updater, v)) })
        .association(:creator)
        .association(:updater)
        .association(post: :uploader, as: :poster)
    end
  end

  extend(SearchMethods)

  def validate_post_exists
    errors.add(:post, "must exist") unless Post.exists?(post_id)
  end

  def validate_creator_is_not_limited
    allowed = creator.can_comment_with_reason
    if allowed != true
      errors.add(:creator, User.throttle_reason(allowed))
      return false
    end
    true
  end

  def post_not_comment_restricted
    errors.add(:base, "Post has comments disabled") if !updater.is_moderator? && Post.find_by(id: post_id)&.is_comment_disabled?
    return if updater.is_moderator?
    post = Post.find_by(id: post_id)
    return if post.blank?
    errors.add(:base, "Post has comments locked") if post.is_comment_locked?
    errors.add(:base, "Post has comments disabled") if post.is_comment_disabled?
  end

  def update_last_commented_at_on_create
    post = Post.find(post_id)
    return unless post
    post.update_column(:last_commented_at, created_at)
    if Comment.where(post_id: post_id).count <= Config.instance.comment_bump_threshold && !do_not_bump_post?
      post.update_column(:last_comment_bumped_at, created_at)
    end
    post.update_index
    true
  end

  def update_last_commented_at_on_destroy
    post = Post.find(post_id)
    return unless post
    other_comments = Comment.where("post_id = ? and id <> ?", post_id, id).order(id: :desc)
    if other_comments.none?
      post.update_columns(last_commented_at: nil)
    else
      post.update_columns(last_commented_at: other_comments.first.created_at)
    end

    if other_comments.none?
      post.update_columns(last_comment_bumped_at: nil)
    else
      post.update_columns(last_comment_bumped_at: other_comments.first.created_at)
    end
    post.update_index
    true
  end

  def below_threshold?(user)
    score < user.comment_threshold
  end

  def can_reply?(user)
    return false if is_sticky?
    return false if (post.is_comment_locked? || post.is_comment_disabled?) && !user.is_moderator?
    true
  end

  def editable_by?(user)
    return true if user.is_admin?
    return false if (post.is_comment_locked? || post.is_comment_disabled?) && !user.is_moderator?
    return false if was_warned?
    creator_id == user.id
  end

  def can_hide?(user)
    return true if user.is_moderator?
    return false if !visible_to?(user) || was_warned? || post&.is_comment_disabled?
    user.id == creator_id
  end

  def visible_to?(user)
    return true if user.is_moderator?
    return false if !is_sticky? && post&.is_comment_disabled? && creator_id != user.id
    return false if post.is_comment_disabled?
    return true if is_hidden? == false
    creator_id == user.id # Can always see your own comments, even if hidden.
  end

  def should_see?(user)
    return user.show_hidden_comments? if creator_id == user.id && is_hidden?
    visible_to?(user)
  end

  def hide!(user)
    update(is_hidden: true, updater: user)
  end

  def unhide!(user)
    update(is_hidden: false, updater: user)
  end

  def hidden_at
    return nil unless is_hidden?
    versions.hidden.last&.created_at
  end

  def warned_at
    return nil unless was_warned?
    versions.marked.last&.created_at
  end

  def edited_version
    versions.edited.last
  end

  def edited_at
    edited_version&.created_at
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
    %i[creator post updater]
  end

  def visible?(user)
    user.is_moderator? || !is_hidden? || creator_id == user.id
  end
end

# frozen_string_literal: true

class SpamDetector
  include(Rakismet::Model)

  AUTOBAN_THRESHOLD = 2
  AUTOBAN_WINDOW = 1.hour
  AUTOBAN_DURATION = -1
  BYPASS = ->(user) { user.is_trusted? || user.older_than!(1.month) }

  attr_accessor(:record, :post, :user, :user_ip, :content, :comment_type)

  delegate(:name, :email, to: :user, prefix: :author)

  # The attributes to pass to Akismet
  rakismet_attrs(user_ip:      :user_ip,
                 author:       proc { user.name },
                 author_email: proc { user.email },
                 blog_lang:    "en",
                 blog_charset: "UTF-8",
                 comment_type: :comment_type,
                 content:      :content,
                 permalink:    :permalink)
  def self.enabled?
    GayFurCity.config.rakismet_key.present? && GayFurCity.config.rakismet_url.present? && !Rails.env.test?
  end

  def self.working?
    Rakismet.validate_key
  rescue StandardError
    false
  end

  def self.is_spammer?(user)
    return false if BYPASS.call(user)

    ticket_count(user) >= AUTOBAN_THRESHOLD
  end

  def self.ticket_count(user)
    tickets = User.system.tickets.where("created_at > ?", AUTOBAN_WINDOW.ago)

    dmails = tickets.where(model: Dmail.sent_by(user))
    comments = tickets.where(model: user.comments)
    forum_posts = tickets.where(model: user.forum_posts)
    dmails.or(comments).or(forum_posts).count
  end

  def self.ban_spammer!(spammer)
    tickets = User.system.tickets.where(accused: spammer, status: "pending")
    tickets.update_all(status: "approved", response: "Automatically Banned", handler_id: User.system.id, handler_ip_addr: "127.0.0.1", claimant_id: User.system.id)
    tickets.each { |ticket| ticket.reload.push_pubsub("update") }
    spammer.bans.create!(reason: "Spammer", duration: AUTOBAN_DURATION, creator: User.system)
  end

  def initialize(record, user_ip:)
    case record
    when Dmail
      @record = record
      @user = record.from
      @content = record.body
      @comment_type = "message"
      @user_ip = user_ip
    when ForumPost
      @record = record
      @post = record.topic
      @user = record.creator
      @content = record.body
      @comment_type = record.is_original_post? ? "forum-post" : "reply"
      @user_ip = user_ip
    when Comment
      @record = record
      @post = record.post
      @user = record.creator
      @content = record.body
      @comment_type = "comment"
      @user_ip = user_ip
    else
      raise(ArgumentError)
    end
  end

  def spam?
    return false unless SpamDetector.enabled?
    return false if BYPASS.call(user)

    is_spam = super

    if is_spam
      Rails.logger.info("Spam detected: user_name=#{user.name} comment_type=#{comment_type} content=#{content.dump} record=#{record.as_json}")
    end

    is_spam
  rescue StandardError => e
    GayFurCity::Logger.log(e)
    false
  end

  def permalink
    return nil if post.nil?
    Rails.application.routes.url_helpers.url_for(post)
  end
end

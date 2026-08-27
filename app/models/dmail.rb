# frozen_string_literal: true

class Dmail < ApplicationRecord
  soft_deletable
  normalizes(:body, with: ->(body) { body.gsub("\r\n", "\n") })
  validates(:title, :body, presence: { on: :create })
  validates(:title, length: { minimum: 1, maximum: 250 })
  validates(:body, length: { minimum: 1, maximum: -> { AdminConfig.instance.dmail_max_size } })
  validate(:recipient_accepts_dmails, on: :create)
  validate(:user_not_limited, on: :create)
  validate(:user_can_send_to, on: :create)
  has_secure_token(:key)

  belongs_to_user(:owner)
  belongs_to_user(:to)
  belongs_to_user(:from, ip: true)
  belongs_to_user(:respond_to, optional: true)
  resolvable(:updater)
  has_many(:tickets, as: :model)
  has_one(:spam_ticket, -> { spam }, class_name: "Ticket", as: :model)

  before_create(:auto_report_spam)
  before_create(:auto_read_if_filtered)
  after_create(:update_recipient)
  after_commit(:send_email, on: :create, unless: :no_email_notification)

  attr_accessor(:bypass_limits, :no_email_notification, :original)

  scope(:from_user, ->(user) { where(from_id: u2id(user)) })
  scope(:to_user, ->(user) { where(to_id: u2id(user)) })
  scope(:owned_by, ->(user) { where(owner_id: u2id(user)) })
  scope(:not_owned_by, ->(user) { where.not(owner_id: u2id(user)) })
  scope(:sent_by, ->(user) { from_user(user).and(not_owned_by(user)) })
  scope(:received_by, ->(user) { to_user(user).and(owned_by(user)) })
  scope(:active, -> { where(is_deleted: false) })
  scope(:deleted, -> { where(is_deleted: true) })
  scope(:read, -> { where(is_read: true) })
  scope(:unread, -> { where(is_read: false).and(active) })

  singleton_class.class_eval do
    alias_method(:from_user_id, :from_user)
    alias_method(:to_user_id, :to_user)
    alias_method(:owned_by_id, :owned_by)
    alias_method(:not_owned_by_id, :not_owned_by)
    alias_method(:sent_by_id, :sent_by)
    alias_method(:received_by_id, :received_by)
  end

  module FactoryMethods
    extend(ActiveSupport::Concern)

    module ClassMethods
      def create_split(params)
        copy = nil

        Dmail.transaction do
          # recipient's copy
          copy = Dmail.new(params)
          copy.owner = copy.to
          copy.save unless copy.to_id == copy.from_id
          raise(ActiveRecord::Rollback) if copy.errors.any?

          # sender's copy
          copy = Dmail.new(params)
          copy.bypass_limits = true
          copy.owner = copy.from
          copy.is_read = true
          copy.save
        end

        copy
      end

      def create_split!(...)
        create_split(...).tap do |dmail|
          raise(ActiveRecord::RecordInvalid, dmail) if dmail.errors.any?
        end
      end

      def create_automated(params)
        Dmail.new(from: User.system, **params).tap do |dmail|
          dmail.owner = dmail.to
          dmail.save
        end
      end

      def create_automated!(...)
        create_automated(...).tap do |dmail|
          raise(ActiveRecord::RecordInvalid, dmail) if dmail.errors.any?
        end
      end
    end

    def build_response(options = {})
      Dmail.new do |dmail|
        if title =~ /Re:/
          dmail.title = title
        else
          dmail.title = "Re: #{title}"
        end
        dmail.owner_id = from_id
        dmail.original = self
        dmail.body = quoted_body
        dmail.to_id = respond_to_id || from_id unless options[:forward]
        dmail.from_id = to_id
      end
    end
  end

  module SearchMethods
    def for_folder(folder, user)
      return all if folder.nil?
      case folder
      when "all"
        owned_by(user)
      when "sent"
        sent_by(user)
      when "received"
        received_by(user)
      end
    end

    def query_dsl
      super
        .field(:title_matches, :title)
        .field(:message_matches, :body)
        .field(:is_read)
        .field(:is_deleted)
        .field(:is_spam)
        .field(:ip_addr, :from_ip_addr)
        .custom(:read, ->(q, v) { q.if(v, q.read).else(q.unread) })
        .association(:to)
        .association(:from)
        .association(:owner)
    end
  end

  include(FactoryMethods)
  extend(SearchMethods)

  def user_not_limited
    return true if bypass_limits == true
    return true if User.system.is?(from_id)
    return true if from.is_janitor?

    # different throttle for restricted users, no newbie restriction & much more restrictive total limit
    if from.is_pending?
      allowed = from.can_dmail_restricted_with_reason
      errors.add(:base, "You #{User.throttle_reason(allowed, 'daily')}.") if allowed != true
    else
      allowed = from.can_dmail_with_reason
      if allowed != true
        errors.add(:base, "Sender #{User.throttle_reason(allowed)}")
        return
      end
      minute_allowed = from.can_dmail_minute_with_reason
      if minute_allowed != true
        errors.add(:base, "Please wait a bit before trying to send again")
        return
      end
      day_allowed = from.can_dmail_day_with_reason
      if day_allowed != true
        errors.add(:base, "Sender #{User.throttle_reason(day_allowed, 'daily')}")
        nil
      end
    end
  end

  def user_can_send_to
    return true unless from.is_rejected? || from.is_restricted?
    unless to.is_admin?
      errors.add(:to_name, "is not a valid recipient. You may only message admins")
      return false
    end
    true
  end

  def recipient_accepts_dmails
    unless to
      errors.add(:to_name, "not found")
      return false
    end
    return true if User.system.is?(from_id)
    return true if from.is_janitor?
    if to.disable_user_dmails?
      errors.add(:to_name, "has disabled DMails")
      return false
    end
    if from.disable_user_dmails? && !to.is_janitor?
      errors.add(:to_name, "is not a valid recipient while blocking DMails from others. You may only message janitors and above")
      return false
    end
    if to.is_blocking_messages_from?(from)
      errors.add(:to_name, "does not wish to receive DMails from you")
      false
    end
  end

  def quoted_body
    "[quote]\n@#{from_name} said:\n\n#{body}\n[/quote]\n\n"
  end

  def send_email
    if to.receive_email_notifications? && to.email =~ /@/ && is_owner?(to)
      UserMailer.dmail_notice(self).deliver_now
    end
  end

  def mark_as_read!(user)
    update(is_read: true, updater: user)
    owner.update(unread_dmail_count: owner.dmails.unread.count)
    owner.notifications.unread.where(category: "dmail").and(owner.notifications.where("data->>'dmail_id' = ?", id.to_s)).each { |n| n.mark_as_read!(user) }
  end

  def mark_as_unread!(user)
    update(is_read: false, updater: user)
    owner.update(unread_dmail_count: owner.dmails.unread.count)
    owner.notifications.read.where(category: "dmail").and(owner.notifications.where("data->>'dmail_id' = ?", id.to_s)).each { |n| n.mark_as_unread!(user) }
  end

  def is_automated?
    User.system.is?(from_id)
  end

  def is_sender?
    owner.is?(from_id)
  end

  def is_recipient?
    owner.is?(to_id)
  end

  def filtered?
    owner.dmail_filter.try(:filtered?, self) || false
  end

  def auto_read_if_filtered
    if owner_id != from_id && to.dmail_filter.try(:filtered?, self)
      self.is_read = true
    end
  end

  def auto_report_spam
    if is_recipient? && !is_sender? && SpamDetector.new(self, user_ip: from_ip_addr.to_s).spam?
      self.is_deleted = true
      self.is_spam = true
      tickets << Ticket.new(creator: User.system, reason: "Spam.")
    end
  end

  def mark_spam!(user)
    return if is_spam?
    update!(is_spam: true, updater: user)
    return if spam_ticket.present?
    SpamDetector.new(self, user_ip: from_ip_addr.to_s).spam!
  end

  def mark_not_spam!(user)
    return unless is_spam?
    update!(is_spam: false, updater: user)
    return if spam_ticket.blank?
    SpamDetector.new(self, user_ip: from_ip_addr.to_s).ham!
  end

  def update_recipient
    if owner_id != from_id && !is_deleted? && !is_read?
      to.update(unread_dmail_count: to.dmails.unread.count)
      to.notifications.create!(category: "dmail", data: { user_id: from_id, dmail_id: id, dmail_title: title })
    end
  end

  def visible_to?(user, key = nil)
    return true if user.is_owner?
    return true if user.is_moderator? && (User.system.is?(from_id) || Ticket.exists?(model: self) || key == self.key)
    return true if user.is_admin? && (to.is_admin? || from.is_admin?)
    is_owner?(user)
  end

  def is_owner?(user)
    u2id(user) == owner_id
  end

  def apionly_is_owner?
    is_owner?(CurrentUser.user)
  end

  def self.available_includes
    %i[from to owner]
  end

  def visible?(user)
    visible_to?(user)
  end
end

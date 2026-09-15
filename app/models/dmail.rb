# frozen_string_literal: true

class Dmail < ApplicationRecord
  normalizes(:body, with: ->(body) { body.gsub("\r\n", "\n") })
  validates(:title, :body, presence: { on: :create })
  validates(:title, length: { minimum: 1, maximum: 250 })
  validates(:body, length: { minimum: 1, maximum: -> { AdminConfig.instance.dmail_max_size } })
  validate(:recipient_accepts_dmails, on: :create)
  validate(:user_not_limited, on: :create)
  validate(:user_can_send_to, on: :create)
  validate(:parent_is_own_conversation, on: :create)
  has_secure_token(:key)

  belongs_to_user(:to)
  belongs_to_user(:from, ip: true)
  belongs_to_user(:respond_to, optional: true)
  resolvable(:updater)
  belongs_to(:parent, class_name: "Dmail", optional: true)
  has_many(:replies, -> { order(created_at: :asc) }, class_name: "Dmail", foreign_key: "parent_id", inverse_of: :parent)
  has_many(:tickets, as: :model)
  has_one(:spam_ticket, -> { spam }, class_name: "Ticket", as: :model)

  before_create(:auto_report_spam)
  before_create(:auto_read_if_filtered)
  after_create(:update_recipient)
  after_commit(:send_email, on: :create, unless: :no_email_notification)

  attr_accessor(:bypass_limits, :no_email_notification, :original)

  scope(:from_user, ->(user) { where(from_id: u2id(user)) })
  scope(:to_user, ->(user) { where(to_id: u2id(user)) })
  scope(:sent_by, ->(user) { from_user(user) })
  scope(:received_by, ->(user) { to_user(user) })
  scope(:involving, ->(user) { from_user(user).or(to_user(user)) })
  # A non-party (e.g. staff browsing broadly) has no deletion state of their own to speak of, so
  # they see the row either way - only excluded if the viewer IS specifically the side that
  # deleted it.
  scope(:not_deleted_for, ->(user) {
    uid = u2id(user)
    where.not(from_id: uid, is_deleted_by_sender: true).where.not(to_id: uid, is_deleted_by_recipient: true)
  })
  scope(:read, -> { where(is_read: true) })
  scope(:unread, -> { where(is_read: false) })

  singleton_class.class_eval do
    alias_method(:from_user_id, :from_user)
    alias_method(:to_user_id, :to_user)
    alias_method(:sent_by_id, :sent_by)
    alias_method(:received_by_id, :received_by)
  end

  module FactoryMethods
    extend(ActiveSupport::Concern)

    module ClassMethods
      def create_automated(params)
        Dmail.create(from: User.system, **params)
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
        dmail.original = self
        dmail.parent_id = id
        dmail.to_id = respond_to_id || from_id unless options[:forward]
        dmail.from_id = to_id
      end
    end
  end

  module SearchMethods
    def for_folder(folder, user)
      scope = case folder
              when nil
                all
              when "sent"
                sent_by(user)
              when "received"
                received_by(user)
              else
                involving(user)
              end
      scope.not_deleted_for(user)
    end

    def query_dsl
      super
        .field(:title_matches, :title)
        .field(:message_matches, :body)
        .field(:is_read)
        .field(:is_spam)
        .field(:ip_addr, :from_ip_addr)
        .custom(:read, ->(q, v) { q.if(v, q.read).else(q.unread) })
        .association(:to)
        .association(:from)
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

  # parent_id is client-suppliable (the reply form round-trips it through a hidden field), so
  # without this a tampered value could chain onto an arbitrary dmail the sender was never party
  # to - both fabricating a reply chain and leaking that dmail's content to anyone who later views
  # this one's thread_ancestors. Requiring the sender to have actually received the parent (i.e.
  # they could legitimately reply to or forward it) closes both holes.
  def parent_is_own_conversation
    return if parent_id.blank?
    errors.add(:parent, "must be a message you received") unless parent&.to_id == from_id
  end

  def send_email
    if to.receive_email_notifications? && to.email =~ /@/
      UserMailer.dmail_notice(self).deliver_now
    end
  end

  def mark_as_read!(user)
    update(is_read: true, updater: user)
    to.update(unread_dmail_count: to.received_dmails.unread.where(is_deleted_by_recipient: false).count)
    to.notifications.unread.where(category: "dmail").and(to.notifications.where("data->>'dmail_id' = ?", id.to_s)).each { |n| n.mark_as_read!(user) }
  end

  def mark_as_unread!(user)
    update(is_read: false, updater: user)
    to.update(unread_dmail_count: to.received_dmails.unread.where(is_deleted_by_recipient: false).count)
    to.notifications.read.where(category: "dmail").and(to.notifications.where("data->>'dmail_id' = ?", id.to_s)).each { |n| n.mark_as_unread!(user) }
  end

  def is_automated?
    User.system.is?(from_id)
  end

  # Every message in this conversation before this one, oldest first - so a chain A -> B -> C -> D
  # can render as a whole conversation (A, B, C) leading up to D, the same way a ticket's messages
  # all render as one thread. Guards against a cycle (shouldn't happen - parent_id can only ever
  # point to an earlier row - but nothing stops parent_id from being reassigned later) by bailing
  # out the moment an id repeats.
  def thread_ancestors
    ancestors = []
    seen = Set.new([id])
    current = self
    while (p = current.parent) && seen.add?(p.id)
      ancestors << p
      current = p
    end
    ancestors.reverse
  end

  def involves?(user)
    uid = u2id(user)
    from_id == uid || to_id == uid
  end

  def not_deleted_for?(user)
    uid = u2id(user)
    return !is_deleted_by_sender? if from_id == uid
    return !is_deleted_by_recipient? if to_id == uid
    true
  end

  def soft_delete_for!(user)
    uid = u2id(user)
    if from_id == uid
      update!(is_deleted_by_sender: true, updater: user)
    elsif to_id == uid
      update!(is_deleted_by_recipient: true, updater: user)
    end
  end

  # "filtered" means filtered by the viewing user's own filter, whichever side of the
  # conversation they're on (matches the old owner.dmail_filter check, since owner used to always
  # be whichever party a given copy's row belonged to).
  def filtered?(user)
    user.dmail_filter.try(:filtered?, self) || false
  end

  def auto_read_if_filtered
    if to.dmail_filter.try(:filtered?, self)
      self.is_read = true
    end
  end

  def auto_report_spam
    if SpamDetector.new(self, user_ip: from_ip_addr.to_s).spam?
      self.is_deleted_by_recipient = true
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
    if !is_deleted_by_recipient? && !is_read?
      to.update(unread_dmail_count: to.received_dmails.unread.where(is_deleted_by_recipient: false).count)
      to.notifications.create!(category: "dmail", data: { user_id: from_id, dmail_id: id, dmail_title: title })
    end
  end

  def visible_to?(user, key = nil)
    return true if user.is_owner?
    return true if user.is_moderator? && (User.system.is?(from_id) || Ticket.exists?(model: self) || key == self.key)
    return true if user.is_admin? && (to.is_admin? || from.is_admin?)
    involves?(user)
  end

  # apionly_* methods are the exposed-via-API pattern for a computed value (see api_attributes in
  # DmailPolicy) - is_deleted_by_sender/is_deleted_by_recipient are per-party, so what "is_deleted"
  # means depends on who's asking. CurrentUser.user, not an argument, since serializable_hash calls
  # methods with no arguments.
  def apionly_is_deleted?
    if from_id == u2id(CurrentUser.user)
      is_deleted_by_sender?
    elsif to_id == u2id(CurrentUser.user)
      is_deleted_by_recipient?
    end
  end

  # Drives the unread-row bold styling (dmails.scss) - is_read now means "has the recipient read
  # this", so it can be false for a message sitting in the *sender's* own Sent folder (the
  # recipient just hasn't read it yet), which isn't something the sender's own view should bold.
  def apionly_is_recipient?
    to_id == u2id(CurrentUser.user)
  end

  def self.available_includes
    %i[from to]
  end

  def visible?(user)
    visible_to?(user)
  end
end

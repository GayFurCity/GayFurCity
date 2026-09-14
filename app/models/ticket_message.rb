# frozen_string_literal: true

class TicketMessage < ApplicationRecord
  belongs_to(:ticket, touch: true)
  belongs_to_user(:creator, ip: true)
  normalizes(:body, with: ->(body) { body.gsub("\r\n", "\n") })
  validates(:body, presence: true)
  validates(:body, length: { minimum: 2, maximum: -> { AdminConfig.instance.ticket_max_size } })
  after_create(:apply_reply_effects)
  after_destroy(:broadcast_deletion)

  # Set by Ticket#respond! (the staff response form) - that flow already applies its own status
  # change and sends its own richer notification, so the generic "plain reply" side effects below
  # would otherwise double up, and reopening could even fight the status the form just set.
  attr_accessor(:skip_reply_effects)

  def from_creator?
    creator_id == ticket.creator_id
  end

  def self.available_includes
    %i[creator ticket]
  end

  delegate(:visible?, to: :ticket)

  def apply_reply_effects
    return if skip_reply_effects
    reopen_ticket_if_needed
    ticket.notify_of_reply!(self)
    ticket.push_pubsub("update")
  end

  # A resolved ticket the creator replies to goes back to pending, unless a moderator has locked
  # it - locking is the only way to keep a closed ticket closed against further replies from them.
  def reopen_ticket_if_needed
    return unless from_creator?
    return if ticket.is_locked? || ticket.pending? || ticket.partial?
    ticket.update_column(:status, "pending")
  end

  def broadcast_deletion
    ticket.push_pubsub("update")
  end
end

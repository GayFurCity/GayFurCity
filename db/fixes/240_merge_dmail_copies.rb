#!/usr/bin/env ruby
# frozen_string_literal: true

# Merges each sender/recipient split-copy pair back into a single row. The two copies of one
# logical send share everything except owner_id and (down to clock precision) created_at -
# Dmail.create_split saved them via two separate Time.current calls in the same request, so match
# on (from_id, to_id, title, body) and pick whichever untagged candidate has the closest
# created_at, rather than requiring an exact timestamp match that was never actually guaranteed.

require(File.expand_path(File.join(File.dirname(__FILE__), "..", "..", "config", "environment")))

Dmail.without_timeout do
  merged = 0
  solo = 0

  Dmail.where(is_deleted_by_recipient: nil).where("owner_id = to_id").find_each do |recipient_copy|
    next if recipient_copy.reload.is_deleted_by_recipient.present? # claimed as someone else's sibling below

    # A self-message (create_split only ever saves one row when to_id == from_id) is both its own
    # sender and recipient copy - nothing to merge, both flags come from its single is_deleted.
    if recipient_copy.from_id == recipient_copy.to_id
      recipient_copy.update_columns(is_deleted_by_recipient: recipient_copy.is_deleted, is_deleted_by_sender: recipient_copy.is_deleted)
      solo += 1
      next
    end

    sender_copy = Dmail.where(
      is_deleted_by_sender: nil,
      owner_id:             recipient_copy.from_id,
      from_id:              recipient_copy.from_id,
      to_id:                recipient_copy.to_id,
      title:                recipient_copy.title,
      body:                 recipient_copy.body,
    ).where.not(id: recipient_copy.id).to_a.min_by { |c| (c.created_at - recipient_copy.created_at).abs }

    if sender_copy
      recipient_copy.update_columns(is_deleted_by_recipient: recipient_copy.is_deleted, is_deleted_by_sender: sender_copy.is_deleted)
      sender_copy.destroy
      merged += 1
    else
      # recipient copy with no matching sender copy left (sender copy already gone) - solo row,
      # nothing sent from this account's own perspective to merge in
      recipient_copy.update_columns(is_deleted_by_recipient: recipient_copy.is_deleted, is_deleted_by_sender: false)
      solo += 1
    end
  end

  # any remaining untagged row is a sender's own copy with no recipient copy left (e.g. the
  # recipient copy was already destroyed by some other process) - keep it, tagged as sent
  remaining = Dmail.where(is_deleted_by_sender: nil).update_all("is_deleted_by_sender = is_deleted, is_deleted_by_recipient = false")

  puts("Merged #{merged} dmail pair(s) into one row, #{solo} recipient copies had no matching sender copy, #{remaining} other rows were tagged solo")
end

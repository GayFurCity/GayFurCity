#!/usr/bin/env ruby
# frozen_string_literal: true

# Best-effort backfill for Dmail#reference_data (see db/migrate/*_add_reference_data_to_dmails.rb)
# on dmails that predate the column. Ticket#notify_creator!/#notify_of_reply! are the only sources
# that set it today, and both always open their body with the same dtext link back to the ticket -
# `"Your ticket":#{ticket_path(ticket)}` - so that's the one reliable signal to key off of; nothing
# else about the dmail (title, sender) is consistent enough between the two call sites to match on.
#
# Matching the specific TicketMessage a dmail was about is a second, best-effort pass on top of
# that - both call sites put the message's own body on its own paragraph after the ticket link, so
# look for a message with that exact body from that sender, closest in time to the dmail. If none
# is found (no matching text, or the dmail predates messages ever being attached, e.g. a plain
# status-change notice with no reply text), the dmail still gets tagged with just its ticket_id.

require(File.expand_path(File.join(File.dirname(__FILE__), "..", "..", "config", "environment")))

ticket_link_pattern = %r{"Your ticket":#{Regexp.escape(Rails.application.routes.url_helpers.tickets_path)}/(\d+)}

tagged_with_message = 0
tagged_ticket_only = 0
skipped = 0

Dmail.without_timeout do
  Dmail.where(reference_data: {}).find_each do |dmail|
    match = dmail.body.match(ticket_link_pattern)
    next(skipped += 1) unless match

    ticket_id = match[1].to_i
    reference_data = { "type" => "ticket", "ticket_id" => ticket_id }

    remainder = dmail.body.split("\n\n", 2)[1]
    if remainder.present?
      candidates = TicketMessage.where(ticket_id: ticket_id, creator_id: dmail.from_id, body: remainder).to_a
      message = candidates.min_by { |m| (m.created_at - dmail.created_at).abs }
      if message
        reference_data["ticket_message_id"] = message.id
        tagged_with_message += 1
      else
        tagged_ticket_only += 1
      end
    else
      tagged_ticket_only += 1
    end

    dmail.update_column(:reference_data, reference_data)
  end
end

puts("Tagged #{tagged_with_message} dmail(s) with a matched ticket message, #{tagged_ticket_only} with just a ticket_id, #{skipped} had no ticket link to match")

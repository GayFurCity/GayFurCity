#!/usr/bin/env ruby
# frozen_string_literal: true

# Tickets used to store a single overwritable `response` column instead of a message thread -
# carries the last response any ticket has on file (only the last one; earlier responses were
# never kept) forward as the first TicketMessage, so it still shows up in the new chat view.

require(File.expand_path(File.join(File.dirname(__FILE__), "..", "..", "config", "environment")))

count = 0
Ticket.without_timeout do
  Ticket.where.not(response: [nil, ""]).find_each do |ticket|
    handler = ticket.handler || ticket.claimant || User.system
    TicketMessage.create!(
      ticket:             ticket,
      creator_id:         handler.id,
      creator_ip_addr:    ticket.handler_ip_addr || "127.0.0.1",
      body:               ticket.response,
      created_at:         ticket.updated_at,
      updated_at:         ticket.updated_at,
      # a one-time historical backfill shouldn't notify anyone, reopen resolved tickets, or spam
      # the pubsub channel for every row it inserts
      skip_reply_effects: true,
    )
    count += 1
  end
end

puts("Backfilled #{count} ticket response messages")

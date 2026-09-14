# frozen_string_literal: true

require("test_helper")
require_relative("helper")

module ModActions
  class TicketsTest < ActiveSupport::TestCase
    include(Helper)
    include(Rails.application.routes.url_helpers)

    context("mod actions for tickets") do
      setup do
        @ticket = create(:ticket, model: @user, creator: @admin)
        set_count!
      end

      should("format ticket_claim correctly") do
        @ticket.ticket_messages.create!(creator: @admin, body: "test")
        @ticket.claim!(@admin)

        assert_matches(
          actions: %w[ticket_claim],
          text:    "Claimed ticket ##{@ticket.id}",
          subject: @ticket,
        )
      end

      should("format ticket_unclaim correctly") do
        @ticket.ticket_messages.create!(creator: @admin, body: "test")
        @ticket.update_columns(claimant_id: @admin.id)
        @ticket.unclaim!(@admin)

        assert_matches(
          actions: %w[ticket_unclaim],
          text:    "Unclaimed ticket ##{@ticket.id}",
          subject: @ticket,
        )
      end

      should("format ticket_update correctly") do
        @ticket.ticket_messages.create!(creator: @admin, body: "xxx")
        @ticket.log_update

        assert_matches(
          actions: %w[ticket_update],
          text:    "Modified ticket ##{@ticket.id}",
          subject: @ticket,
        )
      end
    end
  end
end

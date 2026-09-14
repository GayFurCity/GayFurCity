# frozen_string_literal: true

require("test_helper")

class TicketTest < ActiveSupport::TestCase
  context("A ticket's response accessor") do
    setup do
      @reporter = create(:user)
      @mod = create(:moderator_user)
    end

    should("create a ticket message when used on create") do
      ticket = nil
      assert_difference("TicketMessage.count", 1) do
        ticket = create(:ticket, creator: @reporter, model: create(:comment), handler: @mod, response: "handled on create")
      end

      assert_equal("handled on create", ticket.ticket_messages.last.body)
      assert_equal(@mod.id, ticket.ticket_messages.last.creator_id)
    end

    should("create a ticket message when used on update") do
      ticket = create(:ticket, creator: @reporter, model: create(:comment))

      assert_difference("TicketMessage.count", 1) do
        ticket.update!(handler: @mod, response: "handled on update")
      end

      assert_equal("handled on update", ticket.ticket_messages.last.body)
      assert_equal(@mod.id, ticket.ticket_messages.last.creator_id)
    end

    should("attribute the message to the claimant if there's no handler") do
      ticket = create(:ticket, creator: @reporter, model: create(:comment), claimant: @mod)

      ticket.update!(response: "handled via claim")

      assert_equal(@mod.id, ticket.ticket_messages.last.creator_id)
    end

    should("attribute the message to System if there's no handler or claimant") do
      ticket = create(:ticket, creator: @reporter, model: create(:comment))

      ticket.update!(response: "automated")

      assert_equal(User.system.id, ticket.ticket_messages.last.creator_id)
    end

    should("do nothing when blank") do
      ticket = create(:ticket, creator: @reporter, model: create(:comment))

      assert_no_difference("TicketMessage.count") do
        ticket.update!(response: "")
      end
    end
  end
end

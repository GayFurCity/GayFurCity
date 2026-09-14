# frozen_string_literal: true

require("test_helper")

class TicketMessageTest < ActiveSupport::TestCase
  context("A ticket message") do
    setup do
      @reporter = create(:user)
      @mod = create(:moderator_user)
      @ticket = create(:ticket, creator: @reporter, model: create(:comment))
    end

    should("be created") do
      message = build(:ticket_message, ticket: @ticket, creator: @reporter)

      assert(message.save)
    end

    should("require a body") do
      message = build(:ticket_message, ticket: @ticket, creator: @reporter, body: "")

      assert_not(message.valid?)
      assert_includes(message.errors[:body], "can't be blank")
    end

    should("require a body of at least 2 characters") do
      message = build(:ticket_message, ticket: @ticket, creator: @reporter, body: "a")

      assert_not(message.valid?)
    end

    should("know if it came from the ticket's creator") do
      from_reporter = create(:ticket_message, ticket: @ticket, creator: @reporter)
      from_staff = create(:ticket_message, ticket: @ticket, creator: @mod)

      assert_predicate(from_reporter, :from_creator?)
      assert_not_predicate(from_staff, :from_creator?)
    end

    should("touch the ticket's updated_at") do
      @ticket.update_columns(updated_at: 1.day.ago)
      old_updated_at = @ticket.updated_at

      create(:ticket_message, ticket: @ticket, creator: @reporter)

      assert_operator(@ticket.reload.updated_at, :>, old_updated_at)
    end

    should("order messages oldest first") do
      first = create(:ticket_message, ticket: @ticket, creator: @reporter, created_at: 2.days.ago)
      second = create(:ticket_message, ticket: @ticket, creator: @mod, created_at: 1.day.ago)

      assert_equal([first, second], @ticket.ticket_messages.to_a)
    end
  end
end

# frozen_string_literal: true

require("test_helper")

# rubocop:disable YiffSpace/CurrentOutsideOfRequests -- simulating the viewer for dmail_reference_source
class DmailsHelperTest < ActionView::TestCase
  include(DmailsHelper)

  context("dmail_reference_source") do
    setup do
      @user = create(:user)
      @dmail = create(:dmail, to: @user)
    end

    should("be blank when there's no reference data") do
      CurrentUser.scoped(@user) do
        assert_nil(dmail_reference_source(@dmail))
      end
    end

    should("link to the ticket when the viewer can see it") do
      ticket = create(:ticket, creator: @user, model: create(:comment))
      @dmail.update_column(:reference_data, { "type" => "ticket", "ticket_id" => ticket.id })

      CurrentUser.scoped(@user) do
        assert_includes(dmail_reference_source(@dmail), "Ticket ##{ticket.id}")
        assert_includes(dmail_reference_source(@dmail), "href")
      end
    end

    should("fall back to plain text when the viewer can't see the ticket") do
      other_creator = create(:user)
      ticket = create(:ticket, creator: other_creator, model: create(:comment, creator: other_creator))
      @dmail.update_column(:reference_data, { "type" => "ticket", "ticket_id" => ticket.id })

      CurrentUser.scoped(@user) do
        assert_equal("Ticket ##{ticket.id}", dmail_reference_source(@dmail))
      end
    end

    should("fall back to plain text when the ticket no longer exists") do
      @dmail.update_column(:reference_data, { "type" => "ticket", "ticket_id" => 0 })

      CurrentUser.scoped(@user) do
        assert_equal("Ticket #0", dmail_reference_source(@dmail))
      end
    end

    should("titleize unknown source types") do
      @dmail.update_column(:reference_data, { "type" => "post_approval" })

      CurrentUser.scoped(@user) do
        assert_equal("Post Approval", dmail_reference_source(@dmail))
      end
    end
  end
end
# rubocop:enable YiffSpace/CurrentOutsideOfRequests

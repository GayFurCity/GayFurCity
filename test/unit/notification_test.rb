# frozen_string_literal: true

require("test_helper")

class NotificationTest < ActiveSupport::TestCase
  context("A notification") do
    setup do
      @user = create(:user)
    end

    should("increment user's unread_notification_count") do
      assert_not(@user.reload.has_unread_notifications?)
      assert_difference("@user.reload.unread_notification_count", 1) do
        create(:notification, user: @user)
      end
      assert_predicate(@user.reload, :has_unread_notifications?)
    end

    should("decrement user's unread_notification_count") do
      notification = create(:notification, user: @user)

      assert_predicate(@user.reload, :has_unread_notifications?)
      assert_difference("@user.reload.unread_notification_count", -1) do
        notification.update_with!(@user, is_read: true)
      end
      assert_not(@user.reload.has_unread_notifications?)
    end

    should("also mark the dmail as read for dmail notifications") do
      dmail = create(:dmail, owner: @user)
      notification = create(:notification, user: @user, category: "dmail", data: { dmail_id: dmail.id })

      assert_not(dmail.reload.is_read)
      notification.mark_as_read!(@user)

      assert(dmail.reload.is_read)
    end
  end
end

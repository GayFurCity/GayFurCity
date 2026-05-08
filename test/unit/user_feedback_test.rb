# frozen_string_literal: true

require("test_helper")

class UserFeedbackTest < ActiveSupport::TestCase
  context("A user's feedback") do
    setup do
      @user = create(:user)
      @mod = create(:moderator_user)
      @admin = create(:admin_user)
    end

    should("create a notification on create") do
      assert_difference("Notification.count", 1) do
        @record = create(:user_feedback, user: @user, body: "good job!", creator: @mod)
      end
      @notification = Notification.last

      assert_equal("feedback_create", @notification.category)
      assert_equal({ "user_id" => @mod.id, "record_id" => @record.id, "record_type" => @record.category }, @notification.data)
    end

    should("create a notification on update") do
      @record = create(:user_feedback, user: @user, body: "good job!")
      assert_difference("Notification.count", 1) do
        @record.update_with(@admin, body: "great job!", send_update_notification: true)
      end
      @notification = Notification.last

      assert_equal("feedback_update", @notification.category)
      assert_equal({ "user_id" => @admin.id, "record_id" => @record.id, "record_type" => @record.category }, @notification.data)
    end

    should("create a notification on destroy") do
      @record = create(:user_feedback, user: @user, body: "good job!")
      assert_difference("Notification.count", 1) do
        @record.destroy_with(@mod)
      end
      @notification = Notification.last

      assert_equal("feedback_destroy", @notification.category)
      assert_equal({ "user_id" => @mod.id, "record_id" => @record.id, "record_type" => @record.category }, @notification.data)
    end

    should("create a notification on delete") do
      @record = create(:user_feedback, user: @user, body: "good job!")
      assert_difference("Notification.count", 1) do
        @record.update_with(@mod, is_deleted: true)
      end
      @notification = Notification.last

      assert_equal("feedback_delete", @notification.category)
      assert_equal({ "user_id" => @mod.id, "record_id" => @record.id, "record_type" => @record.category }, @notification.data)
    end

    should("create a notification on undelete") do
      @record = create(:user_feedback, user: @user, body: "good job!", is_deleted: true)
      assert_difference("Notification.count", 1) do
        @record.update_with(@mod, is_deleted: false)
      end
      @notification = Notification.last

      assert_equal("feedback_undelete", @notification.category)
      assert_equal({ "user_id" => @mod.id, "record_id" => @record.id, "record_type" => @record.category }, @notification.data)
    end

    should("not validate if the creator is the user") do
      feedback = build(:user_feedback, user: @mod, creator: @mod)
      feedback.save

      assert_equal(["You cannot submit feedback for yourself"], feedback.errors.full_messages)
    end

    should("not validate if the creator has no permissions") do
      trusted = create(:trusted_user)

      feedback = build(:user_feedback, user: @user, creator: trusted)
      feedback.save

      assert_equal(["You must be moderator"], feedback.errors.full_messages)
    end
  end
end

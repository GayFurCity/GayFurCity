# frozen_string_literal: true

require("test_helper")

class NotificationsControllerTest < ActionDispatch::IntegrationTest
  context("The notifications controller") do
    setup do
      @user = create(:user)
      @notification = create(:notification, user: @user)
    end

    context("index action") do
      should("render") do
        get_auth(notifications_path, @user)
      end

      should("restrict access") do
        assert_access(User::Levels::REJECTED) { |user| get_auth(notifications_path, user) }
      end

      context("search parameters") do
        subject { notifications_path }
        setup do
          Notification.delete_all
          @user = create(:user)
          @notification = create(:notification, category: "default", user: @user)
        end

        assert_search_param(:category, "default", -> { [@notification] }, -> { @user })
        assert_shared_search_params(-> { [@notification] }, -> { @user })
      end
    end

    context("show action") do
      should("redirect") do
        get_auth(notification_path(@notification), @user)

        assert_redirected_to(@notification.view_link)
      end

      should("restrict access") do
        assert_access(User::Levels::REJECTED, success_response: :redirect) { |user| get_auth(notification_path(create(:notification, user: user)), user) }
      end
    end

    context("destroy action") do
      should("work") do
        assert_equal(1, @user.reload.unread_notification_count)
        delete_auth(notification_path(@notification), @user)

        assert_redirected_to(notifications_path)
        assert_equal(0, Notification.count)
        assert_equal(0, @user.reload.unread_notification_count)
      end

      should("restrict access") do
        assert_access(User::Levels::REJECTED, success_response: :redirect) { |user| delete_auth(notification_path(create(:notification, user: user)), user) }
      end
    end

    context("mark as read action") do
      should("work") do
        assert_equal(1, @user.reload.unread_notification_count)
        put_auth(mark_as_read_notification_path(@notification), @user)

        assert_redirected_to(notifications_path)
        assert(@notification.reload.is_read)
        assert_equal(0, @user.reload.unread_notification_count)
      end

      should("restrict access") do
        assert_access(User::Levels::REJECTED, success_response: :redirect) { |user| put_auth(mark_as_read_notification_path(create(:notification, user: user)), user) }
      end
    end

    context("mark all as read action") do
      should("work") do
        create(:notification, user: @user)

        assert_equal(2, @user.reload.unread_notification_count)
        put_auth(mark_all_as_read_notifications_path, @user)

        assert_redirected_to(notifications_path)
        assert_equal(0, Notification.unread.count)
        assert_equal(0, @user.reload.unread_notification_count)
      end

      should("restrict access") do
        assert_access(User::Levels::REJECTED, success_response: :redirect) { |user| put_auth(mark_all_as_read_notifications_path, user) }
      end
    end
  end

  context("A user with unread notifications") do
    setup do
      @user = create(:user)
      @notification = create(:notification, user: @user)
    end

    should("have an unread banner") do
      get_auth(posts_path, @user)

      assert_select("#notification-notice", count: 1)
      assert_select("#notification-notice a.unread-notification-count", { count: 1, text: "1 unread notification" })
    end
  end
end

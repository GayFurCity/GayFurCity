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
        assert_nothing_raised { get_auth(notifications_path, @user) }
      end

      context("access control") do
        asserts do
          access.gte(User::Levels::REJECTED).get(notifications_path)
          access.gte(User::Levels::REJECTED).json.get(notifications_path)
        end
      end

      context("search parameters") do
        subject { notifications_path }
        setup do
          Notification.delete_all
          @user = create(:user)
          @notification = create(:notification, category: "default", user: @user)
        end

        asserts do
          search(:category, "default").records { [@notification] }.user { @user }
          search.shared.records { [@notification] }.user { @user }
        end
      end
    end

    context("show action") do
      should("redirect") do
        get_auth(notification_path(@notification), @user)

        assert_redirected_to(@notification.view_link || notifications_path)
      end

      context("access control") do
        asserts do
          access.gte(User::Levels::REJECTED).get { |user| notification_path(create(:notification, user: user)) }.success(:redirect)
          access.gte(User::Levels::REJECTED).json.get { |user| notification_path(create(:notification, user: user)) }
        end
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

      context("access control") do
        asserts do
          access.gte(User::Levels::REJECTED).delete { |user| notification_path(create(:notification, user: user)) }.success(:redirect)
          access.gte(User::Levels::REJECTED).json.delete { |user| notification_path(create(:notification, user: user)) }
        end
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

      context("access control") do
        asserts do
          access.gte(User::Levels::REJECTED).put { |user| mark_as_read_notification_path(create(:notification, user: user)) }.success(:redirect)
          access.gte(User::Levels::REJECTED).json.put { |user| mark_as_read_notification_path(create(:notification, user: user)) }
        end
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

      context("access control") do
        asserts do
          access.gte(User::Levels::REJECTED).put(mark_all_as_read_notifications_path).success(:redirect)
          access.gte(User::Levels::REJECTED).json.put(mark_all_as_read_notifications_path)
        end
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

# frozen_string_literal: true

require("test_helper")

class MentionsTest < ActiveSupport::TestCase
  context("mentioning a user") do
    setup do
      @user = create(:user)
      @user2 = create(:user)
      @user3 = create(:user)
      @admin = create(:admin_user)
    end

    context("in a comment") do
      context("when creating") do
        should("create a notification") do
          assert_difference("Notification.count", 1) do
            @comment = create(:comment, creator: @user, body: "hello @#{@user2.name}")
          end

          @notification = Notification.last

          assert_equal("mention", @notification.category)
          assert_equal(@user2.id, @notification.user_id)
          assert_equal({ "mention_id" => @comment.id, "mention_type" => "Comment", "user_id" => @user.id, "post_id" => @comment.post_id }, @notification.data)
          assert_equal(1, @user2.reload.unread_notification_count)
          assert_same_elements([@user2.id], @comment.notified_mentions)
        end

        should("not create a notification if the recipient has blocked the user") do
          create(:user_block, user: @user2, target: @user, suppress_mentions: true)
          assert_no_difference("Notification.count") do
            @comment = create(:comment, creator: @user, body: "hello @#{@user2.name}")
          end
        end

        should("not create a notification when mentioning the creator") do
          assert_no_difference("Notification.count") do
            @comment = create(:comment, creator: @user, body: "hello @#{@user.name}")
          end
        end

        should("not create a notification when mentioning the system user") do
          assert_no_difference("Notification.count") do
            @comment = create(:comment, creator: @user, body: "hello @#{Config.instance.system_user_name}")
          end
        end

        should("not create a notification when mentioned by the system user") do
          assert_no_difference("Notification.count") do
            @comment = create(:comment, creator: User.system, body: "hello @#{@user.name}")
          end
        end
      end

      context("when editing") do
        should("create a notification") do
          @comment = create(:comment, creator: @user, body: "hello @#{@user2.name}")

          assert_equal(1, @user2.reload.unread_notification_count)
          assert_same_elements([@user2.id], @comment.notified_mentions)
          assert_difference("Notification.count", 1) do
            @comment.update!(body: "hello @#{@user3.name}")
          end
          @notification = Notification.last

          assert_equal("mention", @notification.category)
          assert_equal(@user3.id, @notification.user_id)
          assert_equal({ "mention_id" => @comment.id, "mention_type" => "Comment", "user_id" => @user.id, "post_id" => @comment.post_id }, @notification.data)
          assert_equal(1, @user2.reload.unread_notification_count)
          assert_equal(1, @user3.reload.unread_notification_count)
          assert_same_elements([@user2.id, @user3.id], @comment.notified_mentions)
        end

        should("not create a notification if the user has already been notified") do
          @comment = create(:comment, creator: @user, body: "hello @#{@user2.name}")

          assert_equal(1, @user2.reload.unread_notification_count)
          assert_same_elements([@user2.id], @comment.notified_mentions)
          assert_no_difference("Notification.count") do
            @comment.update!(body: "hello @#{@user2.name} how are you")
          end
          @notification = Notification.last

          assert_equal("mention", @notification.category)
          assert_equal(@user2.id, @notification.user_id)
          assert_equal({ "mention_id" => @comment.id, "mention_type" => "Comment", "user_id" => @user.id, "post_id" => @comment.post_id }, @notification.data)
          assert_equal(1, @user2.reload.unread_notification_count)
          assert_equal(0, @user3.reload.unread_notification_count)
          assert_same_elements([@user2.id], @comment.notified_mentions)
        end

        should("not create a notification if the recipient has blocked the user") do
          create(:user_block, user: @user2, target: @user, suppress_mentions: true)
          assert_no_difference("Notification.count") do
            @comment = create(:comment, creator: @user, body: "hello @#{@user2.name}")
            @comment.update!(body: "hello @#{@user2.name} how are you")
          end
          assert_same_elements([@user2.id], @comment.notified_mentions)
        end

        should("not create a notification if the creator is later unblocked") do
          @block = create(:user_block, user: @user2, target: @user, suppress_mentions: true)
          assert_no_difference("Notification.count") do
            @comment = create(:comment, creator: @user, body: "hello @#{@user2.name}")
          end
          assert_same_elements([@user2.id], @comment.notified_mentions)
          @block.destroy
          assert_no_difference("Notification.count") do
            @comment.update!(body: "hello @#{@user2.name} how are you")
          end
          assert_same_elements([@user2.id], @comment.notified_mentions)
        end

        should("not create a notification when mentioning the creator") do
          @comment = create(:comment, creator: @user, body: "hello @#{@user.name}")
          assert_no_difference("Notification.count") do
            @comment.update!(body: "hello @#{@user.name} how are you")
          end
        end

        should("not create a notification if edited by someone other than the creator") do
          @comment = create(:comment, creator: @user, body: "hello")

          assert_equal([], @comment.notified_mentions)
          assert_no_difference("Notification.count") do
            @comment.update!(body: "hello @#{@user2.name}", updater: @admin)
          end
          assert_equal([], @comment.notified_mentions)
        end
      end
    end

    context("in a forum post") do
      setup do
        @topic = create(:forum_topic)
      end

      context("when creating") do
        should("create a notification") do
          assert_difference("Notification.count", 1) do
            @forum_post = create(:forum_post, creator: @user, body: "hello @#{@user2.name}", topic: @topic)
          end

          @notification = Notification.last

          assert_equal("mention", @notification.category)
          assert_equal(@user2.id, @notification.user_id)
          assert_equal({ "mention_id" => @forum_post.id, "mention_type" => "ForumPost", "user_id" => @user.id, "topic_id" => @topic.id, "topic_title" => @topic.title }, @notification.data)
          assert_equal(1, @user2.reload.unread_notification_count)
          assert_same_elements([@user2.id], @forum_post.notified_mentions)
        end

        should("not create a notification if the recipient has blocked the user") do
          create(:user_block, user: @user2, target: @user, suppress_mentions: true)
          assert_no_difference("Notification.count") do
            @forum_post = create(:forum_post, creator: @user, body: "hello @#{@user2.name}", topic: @topic)
          end
        end

        should("not create a notification when mentioning the creator") do
          assert_no_difference("Notification.count") do
            @forum_post = create(:forum_post, creator: @user, body: "hello @#{@user.name}", topic: @topic)
          end
        end

        should("not create a notification when mentioning the system user") do
          assert_no_difference("Notification.count") do
            @forum_post = create(:forum_post, creator: @user, body: "hello @#{Config.instance.system_user_name}", topic: @topic)
          end
        end

        should("not create a notification when mentioned by the system user") do
          assert_no_difference("Notification.count") do
            @forum_post = create(:forum_post, creator: User.system, body: "hello @#{@user.name}", topic: @topic)
          end
        end
      end

      context("when editing") do
        should("create a notification") do
          @forum_post = create(:forum_post, creator: @user, body: "hello @#{@user2.name}", topic: @topic)

          assert_equal(1, @user2.reload.unread_notification_count)
          assert_same_elements([@user2.id], @forum_post.notified_mentions)
          assert_difference("Notification.count", 1) do
            @forum_post.update!(body: "hello @#{@user3.name}")
          end
          @notification = Notification.last

          assert_equal("mention", @notification.category)
          assert_equal(@user3.id, @notification.user_id)
          assert_equal({ "mention_id" => @forum_post.id, "mention_type" => "ForumPost", "user_id" => @user.id, "topic_id" => @topic.id, "topic_title" => @topic.title }, @notification.data)
          assert_equal(1, @user2.reload.unread_notification_count)
          assert_equal(1, @user3.reload.unread_notification_count)
          assert_same_elements([@user2.id, @user3.id], @forum_post.notified_mentions)
        end

        should("not create a notification if the user has already been notified") do
          @forum_post = create(:forum_post, creator: @user, body: "hello @#{@user2.name}", topic: @topic)

          assert_equal(1, @user2.reload.unread_notification_count)
          assert_same_elements([@user2.id], @forum_post.notified_mentions)
          assert_no_difference("Notification.count") do
            @forum_post.update!(body: "hello @#{@user2.name} how are you")
          end
          @notification = Notification.last

          assert_equal("mention", @notification.category)
          assert_equal(@user2.id, @notification.user_id)
          assert_equal({ "mention_id" => @forum_post.id, "mention_type" => "ForumPost", "user_id" => @user.id, "topic_id" => @topic.id, "topic_title" => @topic.title }, @notification.data)
          assert_equal(1, @user2.reload.unread_notification_count)
          assert_equal(0, @user3.reload.unread_notification_count)
          assert_same_elements([@user2.id], @forum_post.notified_mentions)
        end

        should("not create a notification if the recipient has blocked the user") do
          create(:user_block, user: @user2, target: @user, suppress_mentions: true)
          assert_no_difference("Notification.count") do
            @forum_post = create(:forum_post, creator: @user, body: "hello @#{@user2.name}", topic: @topic)
            @forum_post.update!(body: "hello @#{@user2.name} how are you")
          end
          assert_same_elements([@user2.id], @forum_post.notified_mentions)
        end

        should("not create a notification if the creator is later unblocked") do
          @block = create(:user_block, user: @user2, target: @user, suppress_mentions: true)
          assert_no_difference("Notification.count") do
            @forum_post = create(:forum_post, creator: @user, body: "hello @#{@user2.name}", topic: @topic)
          end
          assert_same_elements([@user2.id], @forum_post.notified_mentions)
          @block.destroy
          assert_no_difference("Notification.count") do
            @forum_post.update!(body: "hello @#{@user2.name} how are you")
          end
          assert_same_elements([@user2.id], @forum_post.notified_mentions)
        end
      end

      should("not create a notification when mentioning the creator") do
        @forum_post = create(:forum_post, creator: @user, body: "hello @#{@user.name}", topic: @topic)
        assert_no_difference("Notification.count") do
          @forum_post.update!(body: "hello @#{@user.name} how are you")
        end
      end

      should("not create a notification if edited by someone other than the creator") do
        @forum_post = create(:forum_post, creator: @user, body: "hello", topic: @topic)

        assert_equal([], @forum_post.notified_mentions)
        assert_no_difference("Notification.count") do
          @forum_post.update!(body: "hello @#{@user2.name}", updater: @admin)
        end
        assert_equal([], @forum_post.notified_mentions)
      end
    end
  end
end

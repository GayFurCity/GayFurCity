# frozen_string_literal: true

require("test_helper")

class TagFollowerTest < ActiveSupport::TestCase
  context("tag followers") do
    setup do
      @user = create(:user)
      @tag = create(:tag)
      @tag2 = create(:tag)
    end

    context("posts") do
      setup do
        IqdbProxy.stubs(:enabled?).returns(false)
      end

      should("alert followers when a new post is uploaded") do
        follower = create(:tag_follower, user: @user)
        assert_difference("Notification.count", 1) do
          with_inline_jobs { create(:post, tag_string: follower.tag_name) }
        end
      end

      should("alert followers when a post is edited") do
        follower = create(:tag_follower, user: @user)
        assert_no_difference("Notification.count") do
          @post = create(:post)
        end
        assert_difference("Notification.count", 1) do
          with_inline_jobs { @post.update!(tag_string: follower.tag_name) }
        end
      end

      should("not alert followers when a post is edited, and they already received a notification") do
        follower = create(:tag_follower, user: @user)
        assert_difference("Notification.count", 1) do
          with_inline_jobs { @post = create(:post, tag_string: follower.tag_name) }
        end
        assert_no_difference("Notification.count") do
          with_inline_jobs { @post.update!(tag_string: "abc #{follower.tag_name}") }
        end
      end

      # as much as I would like it to be possible, the only performant way to keep track of posts is to save the most recent
      # meaning older posts gaining tags will not get notifications
      should("not alert followers when a post is edited, and its id is lower than the last post id") do
        follower = create(:tag_follower, user: @user)
        @post = create(:post)
        assert_difference("Notification.count", 1) do
          with_inline_jobs { create(:post, tag_string: follower.tag_name) }
        end
        assert_no_difference("Notification.count") do
          with_inline_jobs { @post.update!(tag_string: follower.tag_name) }
        end
      end

      should("not create a notification for the uploader") do
        follower = create(:tag_follower, user: @user)
        assert_no_difference("Notification.count") do
          with_inline_jobs { create(:post, tag_string: follower.tag_name, uploader: @user) }
        end
      end
    end

    should("update the tag's follower count") do
      assert_equal(0, @tag.reload.follower_count)
      @tag.follow!(@user)

      assert_equal(1, @tag.reload.follower_count)
      @tag.unfollow!(@user)

      assert_equal(0, @tag.reload.follower_count)
    end

    should("update the user's followed tag count") do
      assert_equal(0, @user.reload.followed_tag_count)
      @tag.follow!(@user)

      assert_equal(1, @user.reload.followed_tag_count)
      @tag.unfollow!(@user)

      assert_equal(0, @user.reload.followed_tag_count)
    end

    should("have its tag changed when an alias is approved") do
      @follower = @tag.follow!(@user)

      assert_equal(@tag.id, @follower.tag_id)
      assert_equal(1, @tag.reload.follower_count)
      assert_equal(0, @tag2.reload.follower_count)
      @ta = create(:tag_alias, antecedent_name: @tag.name, consequent_name: @tag2.name)
      with_inline_jobs { @ta.approve!(@user) }
      @follower.reload

      assert_equal(@tag2.id, @follower.tag_id)
      assert_equal(0, @tag.reload.follower_count)
      assert_equal(1, @tag2.reload.follower_count)
    end

    should("prevent following aliased tags") do
      @ta = create(:tag_alias, antecedent_name: @tag.name, consequent_name: @tag2.name)
      with_inline_jobs { @ta.approve!(@user) }
      assert_raises(TagFollower::AliasedTagError) { @tag.follow!(@user) }
    end
  end
end

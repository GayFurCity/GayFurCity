# frozen_string_literal: true

require("test_helper")

class UserDeletionTest < ActiveSupport::TestCase
  setup do
    @request = mock_request
  end

  context("an invalid user deletion") do
    context("for an invalid password") do
      setup do
        @user = create(:user)
        @deletion = UserDeletion.new(@user, "wrongpassword", @request)
      end

      should("fail") do
        assert_raise(UserDeletion::ValidationError) do
          @deletion.delete!
        end
      end
    end

    context("for an admin") do
      setup do
        @user = create(:admin_user)
        @deletion = UserDeletion.new(@user, "password", @request)
      end

      should("fail") do
        assert_raise(UserDeletion::ValidationError) do
          @deletion.delete!
        end
      end
    end
  end

  context("a valid user deletion") do
    setup do
      @user = create(:trusted_user, created_at: 2.weeks.ago, mfa_secret: MFA.generate_secret)

      @post = create(:post)
      FavoriteManager.add!(user: @user, post: @post)

      @tag = @post.tags.first
      @tag.follow!(@user)

      @user.update_with(@user, email: "gay@gayfur.city")

      @deletion = UserDeletion.new(@user, "password", @request)
      with_inline_jobs { @deletion.delete! }
      @user.reload
    end

    should("create user event") do
      assert_predicate(@user.user_events.user_deletion, :exists?)
    end

    should("blank out the email") do
      assert_empty(@user.email)
    end

    should("remove the MFA secret") do
      assert_nil(@user.mfa_secret)
    end

    should("rename the user") do
      assert_equal("user_#{@user.id}", @user.name)
    end

    should("reset the password") do
      assert_raises(BCrypt::Errors::InvalidHash) do
        User.authenticate(@user.name, "password")
      end
    end

    should("reset the level") do
      assert_equal(User::Levels::MEMBER, @user.level)
    end

    should("remove any favorites") do
      @post.reload

      assert_equal(0, Favorite.count)
      assert_equal("", @post.fav_string)
      assert_equal(0, @post.fav_count)
    end

    should("remove any followed tags") do
      @tag.reload

      assert_equal(0, TagFollower.count)
      assert_equal(0, @tag.follower_count)
    end
  end
end

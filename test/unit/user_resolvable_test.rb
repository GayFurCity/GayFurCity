# frozen_string_literal: true

require("test_helper")

class UserResolvableTest < ActiveSupport::TestCase
  context("UserResolvable") do
    should("delegate missing to user") do
      @user = create(:user_resolvable)

      assert_kind_of(User, @user.user)
      assert_equal(@user.user.id, @user.id)
    end
  end

  context("user factory methods") do
    should("return UserResolvable") do
      user = create(:user)

      assert_kind_of(UserResolvable, user)
      assert_equal("127.0.0.1", user.ip_addr)
    end

    should("return UserResolvable with the provided ip_addr") do
      user = create(:user, ip_addr: "127.1.1.1")

      assert_kind_of(UserResolvable, user)
      assert_equal("127.1.1.1", user.ip_addr)
    end

    should("return User if resolvable is false") do
      assert_kind_of(User, create(:user, resolvable: false))
    end
  end
end

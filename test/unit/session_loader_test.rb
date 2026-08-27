# frozen_string_literal: true

require("test_helper")

class SessionLoaderTest < ActiveSupport::TestCase
  context("SessionLoader") do
    setup do
      @request = mock_request
    end

    context(".safe_mode?") do
      should("return true if the config has safe mode enabled") do
        AdminConfig.any_instance.stubs(:safe_mode).returns(true)
        SessionLoader.new(@request).load

        assert_predicate(CurrentUser, :safe_mode?) # rubocop:disable YiffSpace/CurrentOutsideOfRequests
      end

      should("return false if the config has safe mode disabled") do
        AdminConfig.any_instance.stubs(:safe_mode).returns(false)
        SessionLoader.new(@request).load

        assert_not(CurrentUser.safe_mode?) # rubocop:disable YiffSpace/CurrentOutsideOfRequests
      end

      should("return true if the user has enabled the safe mode account setting") do
        @user = create(:user, enable_safe_mode: true)
        @request.stubs(:session).returns(user_id: @user.id, ph: @user.password_token)
        SessionLoader.new(@request).load

        assert_predicate(CurrentUser, :safe_mode?) # rubocop:disable YiffSpace/CurrentOutsideOfRequests
      end
    end
  end
end

# frozen_string_literal: true

require("test_helper")

class EmailsControllerTest < ActionDispatch::IntegrationTest
  include(UsersHelper)

  context("The emails controller") do
    setup do
      @user = create(:user, email_verified: false)
    end

    context("activate_user action") do
      should("work") do
        assert_difference("UserEvent.count", 2) do
          get_auth(activate_user_email_url(sig: email_sig(@user, :activate, 48.hours)), @user)

          assert_redirected_to(home_users_path)
        end
        assert_predicate(@user.user_events.email_verify, :exists?)
      end
    end
  end
end

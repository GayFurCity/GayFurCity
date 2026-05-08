# frozen_string_literal: true

require("test_helper")

module Users
  class EmailChangesControllerTest < ActionDispatch::IntegrationTest
    context("in all cases") do
      setup do
        Config.any_instance.stubs(:enable_email_verification).returns(true)
        @user = create(:user, email: "bob@ogres.net")
      end

      context("new action") do
        should("render") do
          get_auth(new_users_email_change_path, @user)

          assert_response(:success)
        end
      end

      context("create action") do
        context("with the correct password") do
          should("work") do
            post_auth(users_email_change_path, @user, params: { email_change: { password: "password", email: "abc@ogres.net" } })

            assert_redirected_to(home_users_path)
            @user.reload

            assert_equal("abc@ogres.net", @user.email)
            assert_predicate(@user.user_events.email_change, :exists?)
          end
        end

        context("with the incorrect password") do
          should("not work") do
            post_auth(users_email_change_path, @user, params: { email_change: { password: "passwordx", email: "abc@ogres.net" } })
            @user.reload

            assert_equal("bob@ogres.net", @user.email)
          end
        end

        should("not work with an invalid email") do
          post_auth(users_email_change_path, @user, params: { email_change: { password: "password", email: "" } })
          @user.reload

          assert_not_equal("", @user.email)
          assert_match(/Email can't be blank/, flash[:notice])
        end

        should("work with a valid email when the users current email is invalid") do
          @user = create(:user, email: "")
          post_auth(users_email_change_path, @user, params: { email_change: { password: "password", email: "abc@ogres.net" } })
          @user.reload

          assert_equal("abc@ogres.net", @user.email)
          assert_predicate(@user.user_events.email_change, :exists?)
        end

        should("restrict access") do
          assert_access(User::Levels::REJECTED, success_response: :redirect) { |user| post_auth(users_email_change_path, user, params: { email_change: { password: "password", email: "abc@ogres.net" } }) }
        end
      end
    end
  end
end

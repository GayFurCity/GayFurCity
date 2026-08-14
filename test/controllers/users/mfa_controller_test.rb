# frozen_string_literal: true

require("test_helper")

module Users
  class MFAControllerTest < ActionDispatch::IntegrationTest
    context("The user mfa controller") do
      setup do
        @user = create(:user)
      end

      context("edit action") do
        should("render") do
          assert_nothing_raised { get_auth(edit_user_mfa_path, @user) }
        end
      end

      context("update action") do
        should("work") do
          mfa = ::MFA.new(username: @user.name)
          assert_difference("UserEvent.count", 3) do
            put_auth(user_mfa_path, @user, params: { mfa: { signed_secret: mfa.signed_secret, verification_code: mfa.code } })

            assert_redirected_to(user_mfa_backup_codes_path)
          end
          assert_equal(mfa.secret, @user.reload.mfa_secret)
          assert_equal(%w[mfa_enable backup_codes_generate], UserEvent.last(2).map(&:category))
        end
      end

      context("update action") do
        should("work") do
          mfa = ::MFA.new(username: @user.name)
          assert_difference("UserEvent.count", 3) do
            put_auth(user_mfa_path, @user, params: { mfa: { signed_secret: mfa.signed_secret, verification_code: mfa.code } })

            assert_redirected_to(user_mfa_backup_codes_path)
          end
          assert_equal(mfa.secret, @user.reload.mfa_secret)
          assert_equal(%w[mfa_enable backup_codes_generate], UserEvent.last(2).map(&:category))
        end
      end

      context("destroy action") do
        should("work") do
          mfa = ::MFA.new(username: @user.name)
          @user.update_mfa_secret!(mfa.secret, mock_request)
          assert_difference("UserEvent.count", 3) do
            delete_auth(user_mfa_path, @user)

            assert_redirected_to(edit_users_path)
          end
          assert_nil(@user.reload.mfa_secret)
          assert_predicate(@user.user_events.mfa_disable, :exists?)
        end
      end
    end
  end
end

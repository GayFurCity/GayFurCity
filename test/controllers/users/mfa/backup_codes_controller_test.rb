# frozen_string_literal: true

require("test_helper")

module Users
  module MFA
    class BackupCodesControllerTest < ActionDispatch::IntegrationTest
      context("The user mfa backup codes controller") do
        setup do
          @user = create(:user_with_mfa)
        end

        context("show action") do
          should("render") do
            get_auth(user_mfa_backup_codes_path, @user)

            assert_not(@user.user_events.backup_codes_generate.exists?)
          end

          should("fail when MFA is not enabled") do
            @user.update_mfa_secret!(nil, mock_request)
            get_auth(user_mfa_backup_codes_path, @user)

            assert_response(:unprocessable_entity)
          end

          context("for a user who hasn't authenticated recently") do
            should("redirect to the confirm password page") do
              @user = create(:user_with_mfa)

              travel_to(1.day.ago) { login_as(@user) }
              get(user_mfa_backup_codes_path)

              assert_redirected_to(confirm_password_session_path(url: user_mfa_backup_codes_path))
            end
          end
        end

        context("update action") do
          should("work") do
            codes = @user.backup_codes
            assert_difference("UserEvent.count", 3) do
              post_auth(user_mfa_backup_codes_path, @user)

              assert_redirected_to(user_mfa_backup_codes_path)
            end
            assert_not_equal(codes.join, @user.reload.backup_codes.join)
            assert_predicate(@user.user_events.backup_codes_generate, :exists?)
          end
        end
      end
    end
  end
end

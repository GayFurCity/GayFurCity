# frozen_string_literal: true

require("test_helper")

class SessionsControllerTest < ActionDispatch::IntegrationTest
  context("the sessions controller") do
    context("index action") do
      should("render") do
        get_auth(user_sessions_path, create(:admin_user))

        assert_response(:success)
      end

      should("restrict access") do
        assert_access(User::Levels::ADMIN) { |user| get_auth(user_sessions_path, user) }
      end

      # we can't test session searching due to get_auth creating a session we can't account for
    end

    context("new action") do
      should("render") do
        get(new_session_path)

        assert_response(:success)
      end
    end

    context("create action") do
      should("create a new session") do
        @user = create(:user)

        post(session_path, params: { session: { name: @user.name, password: "password" } })
        @user.reload

        assert_redirected_to(posts_path)
        assert_not_nil(@user.last_ip_addr)
        assert_equal(@user.id, session[:user_id])
        assert_predicate(@user.user_events.login, :exists?)
      end

      should("not log the user in yet if they have 2FA enabled") do
        @user = create(:user_with_mfa)

        post(session_path, params: { session: { name: @user.name, password: "password" } })

        assert_response(:success)
        assert_nil(session[:user_id])
        assert_predicate(@user.user_events.mfa_login_pending_verification, :exists?)
      end

      should("not reauthenticate the user yet if they have 2FA enabled") do
        @user = create(:user_with_mfa)

        post(session_path, params: { session: { name: @user.name, password: "password", type: "reauthenticate" } })

        assert_response(:success)
        assert_nil(session[:user_id])
        assert_predicate(@user.user_events.mfa_reauthenticate_pending_verification, :exists?)
      end

      should("not update last_ip_addr for banned accounts") do
        @user = create(:banned_user)

        get_auth(posts_path, @user, params: { format: :json })
        @user.reload

        assert_nil(@user.last_ip_addr)
        assert_predicate(@user.user_events.banned_login, :exists?)
      end

      should("fail when provided an invalid password") do
        @user = create(:user, password: "xxxxxx", password_confirmation: "xxxxxx")
        post(session_path, params: { session: { name: @user.name, password: "yyy" } })

        assert_nil(session[:user_id])
        assert_equal("Username/Password was incorrect", flash[:notice])
        assert_predicate(@user.user_events.failed_login, :exists?)
      end
    end

    context("destroy action") do
      should("clear the session") do
        @user = create(:user)

        post(session_path, params: { session: { name: @user.name, password: "password" } })

        assert_not_nil(session[:user_id])
        assert_not_nil(session[:last_authenticated_at])

        delete_auth(session_path, @user)

        assert_redirected_to(posts_path)
        assert_nil(session[:user_id])
        assert_nil(session[:last_authenticated_at])
        assert_predicate(@user.user_events.logout, :exists?)
      end
    end

    context("verify_mfa action") do
      should("log the user in if they enter the correct 2FA code") do
        @user = create(:user_with_mfa)

        post(verify_mfa_session_path, params: { mfa: { user_id: @user.signed_id(purpose: :verify_mfa), code: @user.mfa.code } })

        assert_redirected_to(posts_path)
        assert_equal(@user.id, session[:user_id])
        assert_not_nil(@user.reload.last_ip_addr)
        assert_predicate(@user.user_events.mfa_login, :exists?)
      end

      should("log the user in if they enter a 2FA code that was generated less than 30 seconds ago") do
        @user = create(:user_with_mfa)
        code = travel_to(25.seconds.ago) { @user.mfa.code }

        post(verify_mfa_session_path, params: { mfa: { user_id: @user.signed_id(purpose: :verify_mfa), code: code } })

        assert_redirected_to(posts_path)
        assert_equal(@user.id, session[:user_id])
        assert_not_nil(@user.reload.last_ip_addr)
        assert_predicate(@user.user_events.mfa_login, :exists?)
      end

      should("log the user in if they enter a 2FA code that was generated less than 30 in the future") do
        @user = create(:user_with_mfa)
        code = travel_to(25.seconds.from_now) { @user.mfa.code }

        post(verify_mfa_session_path, params: { mfa: { user_id: @user.signed_id(purpose: :verify_mfa), code: code } })

        assert_redirected_to(posts_path)
        assert_equal(@user.id, session[:user_id])
        assert_not_nil(@user.reload.last_ip_addr)
        assert_predicate(@user.user_events.mfa_login, :exists?)
      end

      should("not log the user in if they enter a 2FA code that was generated more than a minute ago") do
        @user = create(:user_with_mfa)
        code = travel_to(65.seconds.ago) { @user.mfa.code }

        post(verify_mfa_session_path, params: { mfa: { user_id: @user.signed_id(purpose: :verify_mfa), code: code } })

        assert_response(:success)
        assert_nil(session[:user_id])
        assert_predicate(@user.user_events.mfa_failed_login, :exists?)
      end

      should("not log the user in if they enter a 2FA code that was generated more than a minute in the future") do
        @user = create(:user_with_mfa)
        code = travel_to(65.seconds.from_now) { @user.mfa.code }

        post(verify_mfa_session_path, params: { mfa: { user_id: @user.signed_id(purpose: :verify_mfa), code: code } })

        assert_response(:success)
        assert_nil(session[:user_id])
        assert_predicate(@user.user_events.mfa_failed_login, :exists?)
      end

      should("not log the user in if they enter a previously used 2FA code") do
        @user = create(:user_with_mfa)
        code = @user.mfa.code
        @user.update_column(:mfa_last_used_at, Time.now)

        post(verify_mfa_session_path, params: { mfa: { user_id: @user.signed_id(purpose: :verify_mfa), code: code } })

        assert_response(:success)
        assert_nil(session[:user_id])
        assert_predicate(@user.user_events.mfa_failed_login, :exists?)
      end

      should("not log the user in if they enter an invalid 2FA code") do
        @user = create(:user_with_mfa)
        code = "123456"

        post(verify_mfa_session_path, params: { mfa: { user_id: @user.signed_id(purpose: :verify_mfa), code: code } })

        assert_response(:success)
        assert_nil(session[:user_id])
        assert_predicate(@user.user_events.mfa_failed_login, :exists?)
      end

      context("when given a backup code") do
        should("log the user in if they enter a correct backup code") do
          @user = create(:user_with_mfa)
          backup_code = @user.backup_codes.first

          post(verify_mfa_session_path, params: { mfa: { user_id: @user.signed_id(purpose: :verify_mfa), code: backup_code } })

          assert_redirected_to(posts_path)
          assert_equal(@user.id, session[:user_id])
          assert_not_nil(@user.reload.last_ip_addr)
          assert_not(@user.backup_codes.include?(backup_code))
          assert_predicate(@user.user_events.backup_code_login, :exists?)
        end

        should("not log the user in if they enter an incorrect backup code") do
          @user = create(:user_with_mfa)
          backup_code = "abcd-1234"

          post(verify_mfa_session_path, params: { mfa: { user_id: @user.signed_id(purpose: :verify_mfa), code: backup_code } })

          assert_response(:success)
          assert_nil(session[:user_id])
          assert_nil(@user.reload.last_ip_addr)
          assert_predicate(@user.user_events.mfa_failed_login, :exists?)
        end
      end

      context("reauthenticate") do
        should("reauthenticate the user if they enter the correct 2FA code") do
          @user = create(:user_with_mfa)

          post(verify_mfa_session_path, params: { mfa: { user_id: @user.signed_id(purpose: :verify_mfa), code: @user.mfa.code, type: "reauthenticate" } })

          assert_redirected_to(posts_path)
          assert_equal(@user.id, session[:user_id])
          assert_not_nil(@user.reload.last_ip_addr)
          assert_predicate(@user.user_events.mfa_reauthenticate, :exists?)
        end

        should("not reauthenticate the user if they enter an invalid 2FA code") do
          @user = create(:user_with_mfa)
          code = "123456"

          post(verify_mfa_session_path, params: { mfa: { user_id: @user.signed_id(purpose: :verify_mfa), code: code, type: "reauthenticate" } })

          assert_response(:success)
          assert_nil(session[:user_id])
          assert_predicate(@user.user_events.mfa_failed_reauthenticate, :exists?)
        end

        context("when given a backup code") do
          should("reauthenticate the user if they enter a correct backup code") do
            @user = create(:user_with_mfa)
            backup_code = @user.backup_codes.first

            post(verify_mfa_session_path, params: { mfa: { user_id: @user.signed_id(purpose: :verify_mfa), code: backup_code, type: "reauthenticate" } })

            assert_redirected_to(posts_path)
            assert_equal(@user.id, session[:user_id])
            assert_not_nil(@user.reload.last_ip_addr)
            assert_not(@user.backup_codes.include?(backup_code))
            assert_predicate(@user.user_events.backup_code_reauthenticate, :exists?)
          end

          should("not reauthenticate the user if they enter an incorrect backup code") do
            @user = create(:user_with_mfa)
            backup_code = "abcd-1234"

            post(verify_mfa_session_path, params: { mfa: { user_id: @user.signed_id(purpose: :verify_mfa), code: backup_code, type: "reauthenticate" } })

            assert_response(:success)
            assert_nil(session[:user_id])
            assert_nil(@user.reload.last_ip_addr)
            assert_predicate(@user.user_events.mfa_failed_reauthenticate, :exists?)
          end
        end
      end
    end
  end
end

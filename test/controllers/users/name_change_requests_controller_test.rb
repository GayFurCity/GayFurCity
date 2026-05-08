# frozen_string_literal: true

require("test_helper")

module Users
  class NameChangeRequestsControllerTest < ActionDispatch::IntegrationTest
    context("The user name change requests controller") do
      setup do
        @user = create(:user)
        @user2 = create(:user)
        @admin = create(:admin_user)
        @change_request = UserNameChangeRequest.create_with!(@user2,
                                                             user_id:       @user2.id,
                                                             original_name: @user2.name,
                                                             desired_name:  "abc",
                                                             change_reason: "hello")
      end

      context("new action") do
        should("render") do
          get_auth(new_user_name_change_request_path, @user)

          assert_response(:success)
        end

        should("restrict access") do
          assert_access(User::Levels::REJECTED) { |user| get_auth(new_user_name_change_request_path, user) }
        end
      end

      context("create action") do
        should("work") do
          post_auth(user_name_change_requests_path, @user, params: { user_name_change_request: { desired_name: "xaxaxa" } })

          assert_redirected_to(user_name_change_request_path(UserNameChangeRequest.last))
          @user.reload

          assert_equal("xaxaxa", @user.name)
        end

        should("reset force_name_change flag") do
          @user.update(force_name_change: true)
          post_auth(user_name_change_requests_path, @user, params: { user_name_change_request: { desired_name: "xaxaxa" } })

          assert_redirected_to(user_name_change_request_path(UserNameChangeRequest.last))
          @user.reload

          assert_equal("xaxaxa", @user.name)
          assert_not(@user.force_name_change)
        end

        should("restrict access") do
          assert_access(User::Levels::REJECTED, success_response: :redirect) { |user| post_auth(user_name_change_requests_path, user, params: { user_name_change_request: { desired_name: SecureRandom.hex(6) } }) }
        end
      end

      context("show action") do
        should("render") do
          get_auth(user_name_change_request_path(@change_request), @user2)

          assert_response(:success)
        end

        context("when the current user is not an admin and does not own the request") do
          should("fail") do
            get_auth(user_name_change_request_path(@change_request), @user)

            assert_response(:forbidden)
          end
        end

        should("restrict access") do
          assert_access(User::Levels::REJECTED) do |user|
            request = UserNameChangeRequest.create_with!(user,
                                                         user_id:       user.id,
                                                         original_name: user.name,
                                                         desired_name:  "user_#{SecureRandom.hex(6)}",
                                                         change_reason: "hello")
            get_auth(user_name_change_request_path(request), user)
          end
        end
      end

      context("for actions restricted to admins") do
        context("index action") do
          should("render") do
            get_auth(user_name_change_requests_path, @admin)

            assert_response(:success)
          end

          should("restrict access") do
            assert_access(User::Levels::MODERATOR) { |user| get_auth(user_name_change_requests_path, user) }
          end

          context("search parameters") do
            subject { user_name_change_requests_path }
            setup do
              UserNameChangeRequest.delete_all
              @user = create(:user)
              @creator = create(:user)
              @approver = create(:user)
              @mod = create(:moderator_user)
              @admin = create(:admin_user)
              @user_name_change_request = create(:user_name_change_request, user: @user, creator: @creator, creator_ip_addr: "127.0.0.2", approver: @approver, desired_name: "foo")
            end

            assert_search_param(:original_name, -> { @user.name }, -> { [@user_name_change_request] }, -> { @mod })
            assert_search_param(:desired_name, "foo", -> { [@user_name_change_request] }, -> { @mod })
            assert_search_param(:user_id, -> { @user.id }, -> { [@user_name_change_request] }, -> { @mod })
            assert_search_param(:user_name, -> { @user.name }, -> { [@user_name_change_request] }, -> { @mod })
            assert_search_param(:creator_id, -> { @creator.id }, -> { [@user_name_change_request] }, -> { @mod })
            assert_search_param(:creator_name, -> { @creator.name }, -> { [@user_name_change_request] }, -> { @mod })
            assert_search_param(:ip_addr, "127.0.0.2", -> { [@user_name_change_request] }, -> { @admin })
            assert_search_param(:approver_id, -> { @approver.id }, -> { [@user_name_change_request] }, -> { @mod })
            assert_search_param(:approver_name, -> { @approver.name }, -> { [@user_name_change_request] }, -> { @mod })
            assert_shared_search_params(-> { [@user_name_change_request] }, -> { @mod })
          end
        end
      end
    end
  end
end

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

        context("access control") do
          asserts do
            access.gte(User::Levels::REJECTED).get(new_user_name_change_request_path)
          end
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

        context("access control") do
          asserts do
            access.gte(User::Levels::REJECTED).post(user_name_change_requests_path).params { { user_name_change_request: { desired_name: SecureRandom.hex(6) } } }.success(:redirect)
            access.gte(User::Levels::REJECTED).json.post(user_name_change_requests_path).params { { user_name_change_request: { desired_name: SecureRandom.hex(6) } } }
          end
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

        context("access control") do
          asserts do
            access do |builder|
              builder.gte(User::Levels::REJECTED).get do |user|
                request = UserNameChangeRequest.create_with!(user,
                                                             user_id:       user.id,
                                                             original_name: user.name,
                                                             desired_name:  "user_#{SecureRandom.hex(6)}",
                                                             change_reason: "hello")
                user_name_change_request_path(request)
              end
            end
            access do |builder|
              builder.gte(User::Levels::REJECTED).json.get do |user|
                request = UserNameChangeRequest.create_with!(user,
                                                             user_id:       user.id,
                                                             original_name: user.name,
                                                             desired_name:  "user_#{SecureRandom.hex(6)}",
                                                             change_reason: "hello")
                user_name_change_request_path(request)
              end
            end
          end
        end
      end

      context("for actions restricted to admins") do
        context("index action") do
          should("render") do
            get_auth(user_name_change_requests_path, @admin)

            assert_response(:success)
          end

          context("access control") do
            asserts do
              access.gte(User::Levels::MODERATOR).get(user_name_change_requests_path)
            end
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

            asserts do
              search(:original_name).value { @user.name }.records { [@user_name_change_request] }.user { @mod }
              search(:desired_name, "foo").records { [@user_name_change_request] }.user { @mod }
              search(:user_id).value { @user.id }.records { [@user_name_change_request] }.user { @mod }
              search(:user_name).value { @user.name }.records { [@user_name_change_request] }.user { @mod }
              search(:creator_id).value { @creator.id }.records { [@user_name_change_request] }.user { @mod }
              search(:creator_name).value { @creator.name }.records { [@user_name_change_request] }.user { @mod }
              search(:ip_addr, "127.0.0.2").records { [@user_name_change_request] }.user { @admin }
              search(:approver_id).value { @approver.id }.records { [@user_name_change_request] }.user { @mod }
              search(:approver_name).value { @approver.name }.records { [@user_name_change_request] }.user { @mod }
              search.shared.records { [@user_name_change_request] }.user { @mod }
            end
          end
        end
      end
    end
  end
end

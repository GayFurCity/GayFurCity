# frozen_string_literal: true

require("test_helper")

module Users
  class DmailFiltersControllerTest < ActionDispatch::IntegrationTest
    context("The dmail filters controller") do
      setup do
        @user1 = create(:user)
        @user2 = create(:user)
      end

      context("update action") do
        setup do
          @dmail = create(:dmail, owner: @user1, from: @user1)
        end

        should("work") do
          put_auth(users_dmail_filter_path, @user1, params: { dmail_filter: { words: "owned" } })

          assert_equal("owned", @user1.reload.dmail_filter.try(&:words))
        end

        should("not allow a user to create a filter belonging to another user") do
          params = {
            dmail_id:     @dmail.id,
            dmail_filter: {
              words:   "owned",
              user_id: @user2.id,
            },
          }

          put_auth(users_dmail_filter_path, @user1, params: params)

          assert_not_equal("owned", @user2.reload.dmail_filter.try(&:words))
        end

        context("access control") do
          asserts do
            access.gte(User::Levels::REJECTED).put(users_dmail_filter_path).params({ dmail_filter: { words: "owned" } }).success(:redirect)
            access.gte(User::Levels::REJECTED).json.put(users_dmail_filter_path).params({ dmail_filter: { words: "owned" } })
          end
        end
      end
    end
  end
end

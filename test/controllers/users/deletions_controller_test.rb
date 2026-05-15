# frozen_string_literal: true

require("test_helper")

module Users
  class DeletionsControllerTest < ActionDispatch::IntegrationTest
    context("The user deletions controller") do
      setup do
        @user = create(:user, created_at: 2.weeks.ago)
      end

      context("show action") do
        should("render") do
          get_auth(users_deletion_path, @user)

          assert_response(:success)
        end

        context("access control") do
          asserts do
            access.gte(User::Levels::REJECTED).get(users_deletion_path)
          end
        end
      end

      context("destroy action") do
        should("work") do
          delete_auth(users_deletion_path, @user, params: { password: "password" })

          assert_redirected_to(posts_path)
          assert_predicate(@user.user_events.user_deletion, :exists?)
        end

        context("access control") do
          setup { GayFurCity.config.stubs(:disable_age_checks).returns(true) }
          asserts do
            access.between(User::Levels::REJECTED, User::Levels::SYSTEM).delete(users_deletion_path).params({ password: "password" }).success(:redirect).fail(:bad_request).anonymous(:redirect)
          end
        end
      end
    end
  end
end

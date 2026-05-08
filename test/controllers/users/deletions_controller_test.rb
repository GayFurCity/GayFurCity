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

        should("restrict access") do
          assert_access(User::Levels::REJECTED) { |user| get_auth(users_deletion_path, user) }
        end
      end

      context("destroy action") do
        should("work") do
          delete_auth(users_deletion_path, @user, params: { password: "password" })

          assert_redirected_to(posts_path)
          assert_predicate(@user.user_events.user_deletion, :exists?)
        end

        should("restrict access") do
          GayFurCity.config.stubs(:disable_age_checks).returns(true)
          assert_access([User::Levels::REJECTED, User::Levels::RESTRICTED, User::Levels::MEMBER, User::Levels::TRUSTED, User::Levels::FORMER_STAFF, User::Levels::JANITOR, User::Levels::MODERATOR, User::Levels::SYSTEM], success_response: :redirect, fail_response: :bad_request, anonymous_response: :redirect) { |user| delete_auth(users_deletion_path, user, params: { password: "password" }) }
        end
      end
    end
  end
end

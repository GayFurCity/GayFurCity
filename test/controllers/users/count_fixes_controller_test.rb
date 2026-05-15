# frozen_string_literal: true

require("test_helper")

module Users
  class CountFixesControllerTest < ActionDispatch::IntegrationTest
    context("The user count fixes controller") do
      setup do
        @user = create(:user)
      end

      context("new action") do
        should("render") do
          get_auth(new_users_count_fixes_path, @user)

          assert_response(:success)
        end

        context("access control") do
          asserts do
            access.gte(User::Levels::MEMBER).get(new_users_count_fixes_path)
          end
        end
      end

      context("create action") do
        setup do
          @columns = %i[post_count post_deleted_count post_update_count post_flag_count favorite_count wiki_update_count note_update_count forum_post_count comment_count pool_update_count set_count artist_update_count own_post_replaced_count own_post_replaced_penalize_count post_replacement_rejected_count ticket_count]
          @user.update_columns(@columns.index_with { rand(5..500) })
        end

        should("work") do
          post_auth(users_count_fixes_path, @user)

          assert_redirected_to(user_path(@user))
          perform_enqueued_jobs(only: RefreshUserCountsJob)

          @columns.each do |column|
            assert_equal(0, @user.reload.send(column), "Column #{column} was not reset")
          end
        end

        context("access control") do
          asserts do
            access.gte(User::Levels::MEMBER).post(users_count_fixes_path).success(:redirect)
            access.gte(User::Levels::MEMBER).json.post(users_count_fixes_path)
          end
        end
      end
    end
  end
end

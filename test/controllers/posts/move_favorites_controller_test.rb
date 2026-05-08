# frozen_string_literal: true

require("test_helper")

module Posts
  class MoveFavoritesControllerTest < ActionDispatch::IntegrationTest
    context("The post move favorites controller") do
      setup do
        @admin = create(:admin_user)
        @user = create(:user, created_at: 1.month.ago)
        @parent = create(:post, uploader: @user)
        @child = create(:post, parent: @parent, uploader: @user)
        @users = create_list(:user, 2)
        @users.each do |u|
          FavoriteManager.add!(user: u, post: @child)
          VoteManager::Posts.vote!(user: u, ip_addr: "127.0.0.1", post: @child, score: 1)
          @child.reload
        end
      end

      context("show action") do
        should("render") do
          get_auth(move_favorites_post_path(@child), @admin)

          assert_response(:success)
        end

        should("restrict access") do
          assert_access([User::Levels::JANITOR, User::Levels::ADMIN, User::Levels::OWNER]) { |user| get_auth(move_favorites_post_path(@child), user) }
        end
      end

      context("create action") do
        should("work") do
          post_auth(move_favorites_post_path(@child), @admin)

          assert_redirected_to(@child)
          perform_enqueued_jobs(only: [TransferFavoritesJob, TransferVotesJob])
          @parent.reload
          @child.reload

          assert_equal(@users.map(&:id).sort, @parent.favorited_users(@user).map(&:id).sort)
          assert_equal(@users.map(&:id).sort, @parent.voted_users(@admin).map(&:id).sort)
          assert_equal([], @child.favorited_users(@admin).map(&:id))
          assert_equal([], @child.voted_users(@user).map(&:id))
        end

        should("restrict access") do
          assert_access([User::Levels::JANITOR, User::Levels::ADMIN, User::Levels::OWNER], success_response: :redirect) { |user| post_auth(move_favorites_post_path(@child), user) }
        end
      end
    end
  end
end

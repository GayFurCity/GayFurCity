# frozen_string_literal: true

require("test_helper")

module Moderator
  class DashboardsControllerTest < ActionDispatch::IntegrationTest
    context("The moderator dashboards controller") do
      setup do
        @user = create(:trusted_user, created_at: 1.month.ago)
        @admin = create(:admin_user)
      end

      context("show action") do
        context("for mod actions") do
          setup do
            @mod_action = create(:mod_action, creator: @user)
          end

          should("render") do
            get_auth(moderator_dashboard_path, @admin)

            assert_response(:success)
          end
        end

        context("for user feedbacks") do
          setup do
            @feedback = create(:user_feedback, creator: @admin)
          end

          should("render") do
            get_auth(moderator_dashboard_path, @admin)

            assert_response(:success)
          end
        end

        context("for wiki pages") do
          setup do
            @wiki_page = create(:wiki_page, creator: @user)
          end

          should("render") do
            get_auth(moderator_dashboard_path, @admin)

            assert_response(:success)
          end
        end

        context("for tags and uploads") do
          setup do
            @post = create(:post, uploader: @user)
          end

          should("render") do
            get_auth(moderator_dashboard_path, @admin)

            assert_response(:success)
          end
        end

        context("for notes") do
          setup do
            @post = create(:post, uploader: @user)
            @note = create(:note, post: @post, creator: @user)
          end

          should("render") do
            get_auth(moderator_dashboard_path, @admin)

            assert_response(:success)
          end
        end

        context("for comments") do
          setup do
            @users = create_list(:user, 6)

            @comment = create(:comment)

            @users.each do |user|
              VoteManager::Comments.vote!(user: user, ip_addr: "127.0.0.1", comment: @comment, score: -1)
            end
          end

          should("render") do
            get_auth(moderator_dashboard_path, @admin)

            assert_response(:success)
          end
        end

        context("for artists") do
          setup do
            @artist = create(:artist, creator: @user)
          end

          should("render") do
            get_auth(moderator_dashboard_path, @admin)

            assert_response(:success)
          end
        end

        context("for flags") do
          setup do
            @post = create(:post, uploader: @user)
            create(:post_flag, post: @post, creator: @user)
          end

          should("render") do
            get_auth(moderator_dashboard_path, @admin)

            assert_response(:success)
          end
        end

        context("access control") do
          asserts do
            access.gte(User::Levels::MODERATOR).get(moderator_dashboard_path)
          end
        end
      end
    end
  end
end

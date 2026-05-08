# frozen_string_literal: true

require("test_helper")

module Users
  class FeedbacksControllerTest < ActionDispatch::IntegrationTest
    context("The user feedbacks controller") do
      setup do
        @user = create(:user)
        @critic = create(:moderator_user)
        @mod = create(:moderator_user)
        @admin = create(:admin_user)
      end

      context("new action") do
        should("render") do
          get_auth(new_user_feedback_path, @critic, params: { user_feedback: { user_id: @user.id } })

          assert_response(:success)
        end

        should("restrict access") do
          assert_access(User::Levels::MODERATOR) { |user| get_auth(new_user_feedback_path, user) }
        end
      end

      context("edit action") do
        setup do
          @user_feedback = create(:user_feedback, user: @user, creator: @critic)
        end

        should("render") do
          get_auth(edit_user_feedback_path(@user_feedback), @critic)

          assert_response(:success)
        end

        should("restrict access") do
          assert_access(User::Levels::MODERATOR) { |user| get_auth(edit_user_feedback_path(@user_feedback), user) }
        end
      end

      context("index action") do
        setup do
          @user_feedback = create(:user_feedback, user: @user, creator: @critic)
        end

        should("render") do
          get_auth(user_feedbacks_path, @user)

          assert_response(:success)
        end

        context("with search parameters") do
          should("render") do
            get_auth(user_feedbacks_path, @critic, params: { search: { user_id: @user.id } })

            assert_response(:success)
          end
        end

        should("restrict access") do
          assert_access(User::Levels::ANONYMOUS) { |user| get_auth(user_feedbacks_path, user) }
        end

        context("search parameters") do
          subject { user_feedbacks_path }
          setup do
            UserFeedback.delete_all
            @user = create(:user)
            @creator = create(:moderator_user)
            @updater = create(:moderator_user)
            @mod = create(:moderator_user)
            @admin = create(:admin_user)
            @user_feedback = create(:user_feedback, user: @user, creator: @creator, creator_ip_addr: "127.0.0.2", updater: @updater, updater_ip_addr: "127.0.0.3", body: "foo", category: "neutral")
          end

          assert_search_param(:body_matches, "foo", -> { [@user_feedback] })
          assert_search_param(:category, "neutral", -> { [@user_feedback] })
          assert_search_param(:deleted, "excluded", -> { [@user_feedback] }, -> { @mod })
          assert_search_param(:deleted, "only", -> { [] }, -> { @mod })
          assert_search_param(:user_id, -> { @user.id }, -> { [@user_feedback] })
          assert_search_param(:user_name, -> { @user.name }, -> { [@user_feedback] })
          assert_search_param(:creator_id, -> { @creator.id }, -> { [@user_feedback] })
          assert_search_param(:creator_name, -> { @creator.name }, -> { [@user_feedback] })
          assert_search_param(:ip_addr, "127.0.0.2", -> { [@user_feedback] }, -> { @admin })
          assert_search_param(:updater_id, -> { @updater.id }, -> { [@user_feedback] })
          assert_search_param(:updater_name, -> { @updater.name }, -> { [@user_feedback] })
          assert_search_param(:updater_ip_addr, "127.0.0.3", -> { [@user_feedback] }, -> { @admin })
          assert_shared_search_params(-> { [@user_feedback] })
        end
      end

      context("create action") do
        should("create a new feedback") do
          assert_difference(%w[UserFeedback.count Notification.count], 1) do
            post_auth(user_feedbacks_path, @critic, params: { user_feedback: { category: "positive", user_name: @user.name, body: "xxx" } })
          end
        end

        should("restrict access") do
          assert_access(User::Levels::MODERATOR, success_response: :redirect) { |user| post_auth(user_feedbacks_path, user, params: { user_feedback: { category: "positive", user_name: @user.name, body: "xxx" } }) }
        end
      end

      context("update action") do
        should("update the feedback") do
          @feedback = create(:user_feedback, user: @user, category: "negative", creator: @critic)

          assert_no_difference("Notification.count") do
            put_auth(user_feedback_path(@feedback), @critic, params: { id: @feedback.id, user_feedback: { category: "positive" } })
          end

          assert_redirected_to(@feedback)
          assert_equal("positive", @feedback.reload.category)
          assert_equal("feedback_create", Notification.last.category)
        end

        should("send a new dmail") do
          @feedback = create(:user_feedback, user: @user, category: "negative", creator: @critic)
          assert_difference("Notification.count", 1) do
            put_auth(user_feedback_path(@feedback), @critic, params: { id: @feedback.id, user_feedback: { body: "changed", send_update_notification: true } })
          end
          assert_equal("feedback_update", Notification.last.category)
        end

        should("restrict access") do
          assert_access(User::Levels::MODERATOR, success_response: :redirect) { |user| put_auth(user_feedback_path(create(:user_feedback, creator: @mod)), user, params: { user_feedback: { category: "positive" } }) }
        end
      end

      context("destroy action") do
        setup do
          @user_feedback = create(:user_feedback, user: @user, creator: @critic)
        end

        should("destroy a feedback") do
          assert_difference({ "UserFeedback.count" => -1, "Notification.count" => 1, "ModAction.count" => 1 }) do
            delete_auth(user_feedback_path(@user_feedback), @critic)
          end
          assert_equal("feedback_destroy", Notification.last.category)
        end

        context("by a moderator") do
          should("allow destroying feedbacks they created") do
            @user_feedback = create(:user_feedback, user: @user, creator: @mod)
            assert_difference({ "UserFeedback.count" => -1, "Notification.count" => 1, "ModAction.count" => 1 }) do
              delete_auth(user_feedback_path(@user_feedback), @mod)
            end
            assert_equal("feedback_destroy", Notification.last.category)
          end

          should("now allow destroying feedbacks they did not create") do
            assert_difference(%w[UserFeedback.count Notification.count ModAction.count], 0) do
              delete_auth(user_feedback_path(@user_feedback), @mod)
            end
          end

          should("not allow deleting feedbacks given to themselves") do
            @user_feedback = create(:user_feedback, user: @mod, creator: @critic)

            assert_no_difference(%w[UserFeedback.count Notification.count ModAction.count]) do
              delete_auth(user_feedback_path(@user_feedback), @mod)
            end
          end
        end

        context("by an admin") do
          should("allow destroying feedbacks they created") do
            @user_feedback = create(:user_feedback, user: @user, creator: @admin)
            assert_difference({ "UserFeedback.count" => -1, "Notification.count" => 1, "ModAction.count" => 1 }) do
              delete_auth(user_feedback_path(@user_feedback), @admin)
            end
          end

          should("allow destroying feedbacks they did not create") do
            assert_difference({ "UserFeedback.count" => -1, "Notification.count" => 1, "ModAction.count" => 1 }) do
              delete_auth(user_feedback_path(@user_feedback, format: :json), @admin)
            end
          end

          should("not allow destroying feedbacks given to themselves") do
            @user_feedback = create(:user_feedback, user: @admin, creator: @critic)

            assert_no_difference(%w[UserFeedback.count Notification.count ModAction.count]) do
              delete_auth(user_feedback_path(@user_feedback), @admin)
            end
          end
        end

        should("restrict access") do
          assert_access(User::Levels::ADMIN, success_response: :redirect) { |user| delete_auth(user_feedback_path(create(:user_feedback, creator: @mod)), user) }
        end
      end

      context("delete action") do
        setup do
          @user_feedback = create(:user_feedback, user: @user, creator: @critic)
        end

        should("delete a feedback") do
          assert_difference("ModAction.count", 1) do
            put_auth(delete_user_feedback_path(@user_feedback), @critic)
          end
        end

        context("by a moderator") do
          should("allow deleting feedbacks given to other users") do
            assert_difference({ "UserFeedback.count" => 0, "ModAction.count" => 1, "@user.feedback.active.count" => -1 }) do
              put_auth(delete_user_feedback_path(@user_feedback), @mod)
            end
          end

          should("not allow deleting feedbacks given to themselves") do
            @user_feedback = create(:user_feedback, user: @mod, creator: @critic)

            assert_no_difference(%w[UserFeedback.count ModAction.count @mod.feedback.active.count]) do
              put_auth(delete_user_feedback_path(@user_feedback), @mod)
            end
          end
        end

        should("restrict access") do
          assert_access(User::Levels::MODERATOR, success_response: :redirect) { |user| put_auth(delete_user_feedback_path(create(:user_feedback, creator: @mod)), user) }
        end
      end

      context("undelete action") do
        setup do
          @user_feedback = create(:user_feedback, user: @user, is_deleted: true, creator: @critic)
        end

        should("delete a feedback") do
          assert_difference("ModAction.count", 1) do
            put_auth(undelete_user_feedback_path(@user_feedback), @critic)
          end
        end

        context("by a moderator") do
          should("allow undeleting feedbacks given to other users") do
            assert_difference({ "UserFeedback.count" => 0, "ModAction.count" => 1, "@user.feedback.active.count" => 1 }) do
              put_auth(undelete_user_feedback_path(@user_feedback), @mod)
            end
          end

          should("not allow undeleting feedbacks given to themselves") do
            @user_feedback = create(:user_feedback, user: @mod, creator: @critic)

            assert_no_difference(%w[UserFeedback.count ModAction.count @mod.feedback.active.count]) do
              put_auth(undelete_user_feedback_path(@user_feedback), @mod)
            end
          end
        end

        should("restrict access") do
          assert_access(User::Levels::MODERATOR, success_response: :redirect) { |user| put_auth(undelete_user_feedback_path(create(:user_feedback, is_deleted: true, creator: @mod)), user) }
        end
      end
    end
  end
end

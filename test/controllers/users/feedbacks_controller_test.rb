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

        context("access control") do
          asserts do
            access.gte(User::Levels::MODERATOR).get(new_user_feedback_path)
          end
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

        context("access control") do
          asserts do
            access.gte(User::Levels::MODERATOR).get { edit_user_feedback_path(@user_feedback) }
          end
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

        context("access control") do
          asserts do
            access.gte(User::Levels::ANONYMOUS).get(user_feedbacks_path)
            access.gte(User::Levels::ANONYMOUS).json.get(user_feedbacks_path)
          end
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

          asserts do
            search(:body_matches, "foo").records { [@user_feedback] }
            search(:category, "neutral").records { [@user_feedback] }
            search(:deleted, "excluded").records { [@user_feedback] }.user { @mod }
            search(:deleted, "only").records { [] }.user { @mod }
            search(:user_id).value { @user.id }.records { [@user_feedback] }
            search(:user_name).value { @user.name }.records { [@user_feedback] }
            search(:creator_id).value { @creator.id }.records { [@user_feedback] }
            search(:creator_name).value { @creator.name }.records { [@user_feedback] }
            search(:ip_addr, "127.0.0.2").records { [@user_feedback] }.user { @admin }
            search(:updater_id).value { @updater.id }.records { [@user_feedback] }
            search(:updater_name).value { @updater.name }.records { [@user_feedback] }
            search(:updater_ip_addr, "127.0.0.3").records { [@user_feedback] }.user { @admin }
            search.shared.records { [@user_feedback] }
          end
        end
      end

      context("create action") do
        should("create a new feedback") do
          assert_difference(%w[UserFeedback.count Notification.count], 1) do
            post_auth(user_feedbacks_path, @critic, params: { user_feedback: { category: "positive", user_name: @user.name, body: "xxx" } })
          end
        end

        context("access control") do
          asserts do
            access.gte(User::Levels::MODERATOR).post(user_feedbacks_path).params { { user_feedback: { category: "positive", user_name: @user.name, body: "xxx" } } }.success(:redirect)
            access.gte(User::Levels::MODERATOR).json.post(user_feedbacks_path).params { { user_feedback: { category: "positive", user_name: @user.name, body: "xxx" } } }
          end
        end
      end

      context("update action") do
        setup do
          @user_feedback = create(:user_feedback, user: @user, category: "negative", creator: @critic)
        end

        should("update the feedback") do
          assert_no_difference("Notification.count") do
            put_auth(user_feedback_path(@user_feedback), @critic, params: { id: @user_feedback.id, user_feedback: { category: "positive" } })
          end

          assert_redirected_to(@user_feedback)
          assert_equal("positive", @user_feedback.reload.category)
          assert_equal("feedback_create", Notification.last.category)
        end

        should("send a new dmail") do
          assert_difference("Notification.count", 1) do
            put_auth(user_feedback_path(@user_feedback), @critic, params: { id: @user_feedback.id, user_feedback: { body: "changed", send_update_notification: true } })
          end
          assert_equal("feedback_update", Notification.last.category)
        end

        context("access control") do
          asserts do
            access.gte(User::Levels::MODERATOR).put { user_feedback_path(@user_feedback) }.params({ user_feedback: { category: "positive" } }).success(:redirect)
            access.gte(User::Levels::MODERATOR).json.put { user_feedback_path(@user_feedback) }.params({ user_feedback: { category: "positive" } })
          end
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

        context("access control") do
          asserts do
            access.gte(User::Levels::ADMIN).delete { user_feedback_path(@user_feedback) }.success(:redirect)
            access.gte(User::Levels::ADMIN).json.delete { user_feedback_path(@user_feedback) }.success(:no_content)
          end
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

        context("access control") do
          asserts do
            access.gte(User::Levels::MODERATOR).put { delete_user_feedback_path(@user_feedback) }.success(:redirect)
            access.gte(User::Levels::MODERATOR).json.put { delete_user_feedback_path(@user_feedback) }
          end
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

        context("access control") do
          asserts do
            access.gte(User::Levels::MODERATOR).put { delete_user_feedback_path(@user_feedback) }.success(:redirect)
            access.gte(User::Levels::MODERATOR).json.put { delete_user_feedback_path(@user_feedback) }
          end
        end
      end
    end
  end
end

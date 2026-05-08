# frozen_string_literal: true

require("test_helper")

class BansControllerTest < ActionDispatch::IntegrationTest
  context("The bans controller") do
    setup do
      @mod = create(:moderator_user)
      @user = create(:user)
      @ban = create(:ban, user: @user, banner: @mod)
    end

    context("new action") do
      should("render") do
        get_auth(new_ban_path, @mod)

        assert_response(:success)
      end

      should("restrict access") do
        assert_access(User::Levels::MODERATOR) { |user| get_auth(new_ban_path, user) }
      end
    end

    context("edit action") do
      should("render") do
        get_auth(edit_ban_path(@ban), @mod)

        assert_response(:success)
      end

      should("restrict access") do
        assert_access(User::Levels::MODERATOR) { |user| get_auth(edit_ban_path(@ban), user) }
      end
    end

    context("show action") do
      should("render") do
        get_auth(ban_path(@ban), @mod)

        assert_response(:success)
      end

      should("restrict access") do
        assert_access(User::Levels::ANONYMOUS) { |user| get_auth(ban_path(@ban), user) }
      end
    end

    context("index action") do
      should("render") do
        get_auth(bans_path, @mod)

        assert_response(:success)
      end

      should("search") do
        get_auth(bans_path(search: { user_name: @user.name }), @mod)

        assert_response(:success)
      end

      should("restrict access") do
        assert_access(User::Levels::ANONYMOUS) { |user| get_auth(bans_path, user) }
      end

      context("search parameters") do
        subject { bans_path }
        setup do
          Ban.delete_all
          @user = create(:user)
          @creator = create(:moderator_user)
          @banner = create(:user)
          @admin = create(:admin_user)
          @ban = create(:ban, user: @user, banner: @creator, banner_ip_addr: "127.0.0.2", reason: "foo", is_permaban: true)
        end

        assert_search_param(:expired, "false", -> { [@ban] })
        assert_search_param(:reason_matches, "foo", -> { [@ban] })
        assert_search_param(:ip_addr, "127.0.0.2", -> { [@ban] }, -> { @admin })
        assert_search_param(:banner_id, -> { @creator.id }, -> { [@ban] })
        assert_search_param(:banner_name, -> { @creator.name }, -> { [@ban] })
        assert_search_param(:user_id, -> { @user.id }, -> { [@ban] })
        assert_search_param(:user_name, -> { @user.name }, -> { [@ban] })
        assert_shared_search_params(-> { [@ban] })
      end
    end

    context("create action") do
      should("work") do
        user = create(:user)
        assert_difference({ "Ban.count" => 1, "ModAction.count" => 3 }) do
          post_auth(bans_path, @mod, params: { ban: { duration: 60, reason: "xxx", user_id: user.id } })

          assert_redirected_to(ban_path(Ban.last))
        end
        assert_predicate(user.reload, :is_banned?)
        assert_equal(%w[user_feedback_create user_ban ban_create], ModAction.last(3).pluck(:action))
      end

      should("restrict access") do
        assert_access(User::Levels::MODERATOR, success_response: :redirect) { |user| post_auth(bans_path, user, params: { ban: { duration: 60, reason: "xxx", user_id: create(:user).id } }) }
      end
    end

    context("update action") do
      should("work") do
        assert_difference("ModAction.count", 1) do
          put_auth(ban_path(@ban), @mod, params: { ban: { reason: "xxx", duration: 60 } })
        end
        @ban.reload

        assert_equal("xxx", @ban.reason)
        assert_redirected_to(ban_path(@ban))
      end

      should("restrict access") do
        assert_access(User::Levels::MODERATOR, success_response: :redirect) { |user| put_auth(ban_path(@ban), user, params: { ban: { reason: "xxx", duration: 60 } }) }
      end
    end

    context("destroy action") do
      should("work") do
        assert_difference({ "Ban.count" => -1, "ModAction.count" => 1 }) do
          delete_auth(ban_path(@ban), @mod)
        end
        assert_redirected_to(bans_path)
      end

      should("restrict access") do
        assert_access(User::Levels::MODERATOR, success_response: :redirect) { |user| delete_auth(ban_path(create(:ban, user: @user, banner: @mod)), user) }
      end
    end
  end
end

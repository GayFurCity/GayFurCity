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

      context("access control") do
        asserts do
          access.gte(User::Levels::MODERATOR).get(new_ban_path)
        end
      end
    end

    context("edit action") do
      should("render") do
        get_auth(edit_ban_path(@ban), @mod)

        assert_response(:success)
      end

      context("access control") do
        asserts do
          access.gte(User::Levels::MODERATOR).get { edit_ban_path(@ban) }
        end
      end
    end

    context("show action") do
      should("render") do
        get_auth(ban_path(@ban), @mod)

        assert_response(:success)
      end

      context("access control") do
        asserts do
          access.gte(User::Levels::ANONYMOUS).get { ban_path(@ban) }
        end
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

      context("access control") do
        asserts do
          access.gte(User::Levels::ANONYMOUS).get(bans_path)
        end
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

        asserts do
          search(:expired, "false").records { [@ban] }
          search(:reason_matches, "foo").records { [@ban] }
          search(:ip_addr, "127.0.0.2").records { [@ban] }.user{ @admin }
          search(:banner_id).value { @creator.id }.records { [@ban] }
          search(:banner_name).value { @creator.name }.records { [@ban] }
          search(:user_id).value { @user.id }.records { [@ban] }
          search(:user_name).value { @user.name }.records { [@ban] }
          search.shared.records { [@ban] }
        end
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

      context("access control") do
        asserts do
          access.gte(User::Levels::MODERATOR).post(bans_path).params { { ban: { duration: 60, reason: "xxx", user_id: create(:user).id } } }.success(:redirect)
          #access.levels([]).post(bans_path).params { { ban: { duration: 60, reason: "xxx", user_id: create(:user).id } } }
        end
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

      context("access control") do
        asserts do
          access.gte(User::Levels::MODERATOR).put { ban_path(@ban) }.params { { ban: { reason: "xxx", duration: 60 } } }.success(:redirect)
          # access.levels([]).json.put { ban_path(@ban) }.params { { ban: { reason: "xxx", duration: 60 } } }
        end
      end
    end

    context("destroy action") do
      should("work") do
        assert_difference({ "Ban.count" => -1, "ModAction.count" => 1 }) do
          delete_auth(ban_path(@ban), @mod)
        end
        assert_redirected_to(bans_path)
      end

      context("access control") do
        asserts do
          access.gte(User::Levels::MODERATOR).delete { ban_path(create(:ban, user: @user, banner: @mod)) }.success(:redirect)
          # access.gte([]).json.delete { ban_path(create(:ban, user: @user, banner: @mod)) }.success(:no_content)
        end
      end
    end
  end
end

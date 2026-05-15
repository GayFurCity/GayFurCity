# frozen_string_literal: true

require("test_helper")

class ModActionsControllerTest < ActionDispatch::IntegrationTest
  context("The mod actions controller") do
    setup do
      @mod_action = create(:mod_action)
    end

    context("index action") do
      should("render") do
        get(mod_actions_path)

        assert_response(:success)
      end

      context("access control") do
        asserts do
          access.gte(User::Levels::ANONYMOUS).get(mod_actions_path)
          access.gte(User::Levels::ANONYMOUS).json.get(mod_actions_path)
        end
      end
      context("search parameters") do
        subject { mod_actions_path }
        setup do
          ModAction.delete_all
          @creator = create(:user)
          @user = create(:user)
          @admin = create(:admin_user)
          @mod_action1 = create(:mod_action, action: "foo", creator: @creator, creator_ip_addr: "127.0.0.2", subject: @user)
          @mod_action2 = create(:mod_action, action: "bar", creator: @creator, creator_ip_addr: "127.0.0.2", subject: @user)
        end

        asserts do
          search(:action, "foo").records { [@mod_action1] }
          search(:action, "foo,bar").records { [@mod_action2, @mod_action1] }
          search(:subject_id).value { @user.id }.records { [@mod_action2, @mod_action1] }
          search(:subject_type, "User").records { [@mod_action2, @mod_action1] }
          search(:creator_id).value { @creator.id }.records { [@mod_action2, @mod_action1] }
          search(:creator_name).value { @creator.name }.records { [@mod_action2, @mod_action1] }
          search(:ip_addr, "127.0.0.2").records { [@mod_action2, @mod_action1] }.user { @admin }
          search.shared.records { [@mod_action2, @mod_action1] }
        end
      end
    end

    context("show action") do
      should("redirect") do
        get(mod_action_path(@mod_action))

        assert_redirected_to(mod_actions_path(search: { id: @mod_action.id }))
      end

      context("access control") do
        asserts do
          access.gte(User::Levels::ANONYMOUS).get { mod_action_path(@mod_action) }.success(:redirect).anonymous(:redirect)
          access.gte(User::Levels::ANONYMOUS).json.get { mod_action_path(@mod_action) }
        end
      end
    end
  end
end

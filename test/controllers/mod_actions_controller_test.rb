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

      should("restrict access") do
        assert_access(User::Levels::ANONYMOUS) { |user| get_auth(mod_actions_path, user) }
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

        assert_search_param(:action, "foo", -> { [@mod_action1] })
        assert_search_param(:action, "foo,bar", -> { [@mod_action2, @mod_action1] })
        assert_search_param(:subject_id, -> { @user.id }, -> { [@mod_action2, @mod_action1] })
        assert_search_param(:subject_type, "User", -> { [@mod_action2, @mod_action1] })
        assert_search_param(:creator_id, -> { @creator.id }, -> { [@mod_action2, @mod_action1] })
        assert_search_param(:creator_name, -> { @creator.name }, -> { [@mod_action2, @mod_action1] })
        assert_search_param(:ip_addr, "127.0.0.2", -> { [@mod_action2, @mod_action1] }, -> { @admin })
        assert_shared_search_params(-> { [@mod_action2, @mod_action1] })
      end
    end

    context("show action") do
      should("redirect") do
        get(mod_action_path(@mod_action))

        assert_redirected_to(mod_actions_path(search: { id: @mod_action.id }))
      end

      should("restrict access") do
        assert_access(User::Levels::ANONYMOUS, success_response: :redirect, anonymous_response: :redirect) { |user| get_auth(mod_action_path(@mod_action), user) }
      end
    end
  end
end

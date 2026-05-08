# frozen_string_literal: true

require("test_helper")

class RulesControllerTest < ActionDispatch::IntegrationTest
  context("The rules controller") do
    setup do
      @admin = create(:admin_user)
      @user = create(:user)
      @category = create(:rule_category)
      @rule = create(:rule, category: @category)
    end

    context("index action") do
      should("render") do
        get(rules_path)

        assert_response(:success)
      end

      should("restrict access") do
        assert_access(User::Levels::ANONYMOUS) { |user| get_auth(rules_path, user) }
      end
    end

    context("new action") do
      should("render") do
        get_auth(new_rule_path, @admin)

        assert_response(:success)
      end

      should("restrict access") do
        assert_access(User::Levels::ADMIN) { |user| get_auth(new_rule_path, user) }
      end
    end

    context("create action") do
      should("create a new rule") do
        assert_difference("Rule.count", 1) do
          post_auth(rules_path, @admin, params: { rule: { name: "xxx", description: "yyy", category_id: @category.id } })
        end
      end

      should("create a modaction") do
        assert_difference("ModAction.count", 1) do
          post_auth(rules_path, @admin, params: { rule: { name: "xxx", description: "yyy", category_id: @category.id } })
        end

        mod_action = ModAction.last

        assert_equal("rule_create", mod_action.action)
        assert_equal(Rule.last, mod_action.subject)
        assert_equal("xxx", mod_action.name)
        assert_equal("yyy", mod_action.description)
        assert_equal(@category.name, mod_action.category_name)
      end

      should("restrict access") do
        assert_access(User::Levels::ADMIN, success_response: :redirect) { |user| post_auth(rules_path, user, params: { rule: { name: SecureRandom.hex(6), description: SecureRandom.hex(6), category_id: @category.id } }) }
      end
    end

    context("edit action") do
      should("render") do
        get_auth(edit_rule_path(@rule), @admin)

        assert_response(:success)
      end

      should("restrict access") do
        assert_access(User::Levels::ADMIN) { |user| get_auth(edit_rule_path(@rule), user) }
      end
    end

    context("update action") do
      should("update the rule") do
        put_auth(rule_path(@rule), @admin, params: { rule: { name: "xxx" } })

        assert_redirected_to(rules_path)
        assert_equal("xxx", @rule.reload.name)
      end

      should("create modaction") do
        old = @rule.name
        assert_difference("ModAction.count", 1) do
          put_auth(rule_path(@rule), @admin, params: { rule: { name: "xxx" } })
        end

        mod_action = ModAction.last

        assert_equal("rule_update", mod_action.action)
        assert_equal(@rule, mod_action.subject)
        assert_equal("xxx", mod_action.name)
        assert_equal(old, mod_action.old_name)
      end

      should("restrict access") do
        assert_access(User::Levels::ADMIN, success_response: :redirect) { |user| put_auth(rule_path(@rule), user, params: { rule: { name: SecureRandom.hex(6), description: SecureRandom.hex(6) } }) }
      end
    end

    context("destroy action") do
      should("destroy the rule") do
        delete_auth(rule_path(@rule), @admin)

        assert_redirected_to(rules_path)
        assert_raise(ActiveRecord::RecordNotFound) { @rule.reload }
      end

      should("create modaction") do
        assert_difference("ModAction.count", 1) do
          delete_auth(rule_path(@rule), @admin)
        end

        mod_action = ModAction.last

        assert_equal("rule_delete", mod_action.action)
        assert_equal(@rule.name, mod_action.name)
        assert_equal(@rule.category.name, mod_action.category_name)
        assert_equal(@rule.description, mod_action.description)
      end

      should("restrict access") do
        assert_access(User::Levels::ADMIN, success_response: :redirect) { |user| delete_auth(rule_path(create(:rule)), user) }
      end
    end
  end
end

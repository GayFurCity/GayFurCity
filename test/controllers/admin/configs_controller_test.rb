# frozen_string_literal: true

require("test_helper")

module Admin
  class ConfigsControllerTest < ActionDispatch::IntegrationTest
    context("The admin configs controller") do
      setup do
        @owner = create(:owner_user)
      end

      context("show action") do
        should("render") do
          get_auth(admin_config_path, @owner)

          assert_response(:success)
        end

        should("restrict access") do
          assert_access(User::Levels::MODERATOR) { |user| get_auth(admin_config_path, user) }
        end
      end

      context("update action") do
        should("render") do
          put_auth(admin_config_path, @owner, params: { config: { comment_limit: 1 }, format: :json })

          assert_response(:success)
        end

        should("restrict access") do
          assert_access(User::Levels::OWNER, anonymous_response: :forbidden) { |user| put_auth(admin_config_path, user, params: { config: { comment_limit: 1 }, format: :json }) }
        end
      end
    end
  end
end

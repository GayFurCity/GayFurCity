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

        context("access control") do
          asserts do
            access.gte(User::Levels::MODERATOR).get(admin_config_path)
            access.gte(User::Levels::MODERATOR).json.get(admin_config_path)
          end
        end
      end

      context("update action") do
        should("render") do
          put_auth(admin_config_path, @owner, params: { config: { comment_limit: 1 }, format: :json })

          assert_response(:success)
        end

        should("save a boolean field flipped from false to true") do
          Config.instance.update_column(:db_exports_enabled, false)

          put_auth(admin_config_path, @owner, params: { config: { db_exports_enabled: "true" } })

          assert_response(:redirect)
          assert(Config.uncached.db_exports_enabled)
        end

        context("access control") do
          asserts do
            access.gte(User::Levels::OWNER).json.put(admin_config_path).params({ config: { comment_limit: 1 } })
          end
        end
      end
    end
  end
end

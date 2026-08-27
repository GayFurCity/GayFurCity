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
          AdminConfig.instance.update_column(:db_exports_enabled, false)

          put_auth(admin_config_path, @owner, params: { config: { db_exports_enabled: "true" } })

          assert_response(:redirect)
          assert(AdminConfig.uncached.db_exports_enabled)
        end

        should("not allow saving a value pinned via an env variable") do
          AdminConfig.instance.update_column(:records_per_page, 100)
          ENV["GAYFURCITY_ADMIN_CONFIG_RECORDS_PER_PAGE"] = "42"

          begin
            put_auth(admin_config_path, @owner, params: { config: { records_per_page: 5 } })

            assert_response(:redirect)
            assert_equal(42, AdminConfig.get(:records_per_page))
            assert_equal(100, AdminConfig.uncached.attributes["records_per_page"])
          ensure
            ENV.delete("GAYFURCITY_ADMIN_CONFIG_RECORDS_PER_PAGE")
          end
        end

        context("access control") do
          asserts do
            access.gte(User::Levels::OWNER).json.put(admin_config_path).params({ config: { comment_limit: 1 } })
          end
        end
      end

      context("clear_cache action") do
        should("work") do
          AdminConfig.expects(:delete_cache)
          put_auth(clear_cache_admin_config_path, @owner)

          assert_redirected_to(admin_config_path)
        end

        context("access control") do
          asserts do
            access.gte(User::Levels::OWNER).put(clear_cache_admin_config_path).success(:redirect)
            access.gte(User::Levels::OWNER).json.put(clear_cache_admin_config_path).success(:no_content)
          end
        end
      end
    end
  end
end

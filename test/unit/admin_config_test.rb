# frozen_string_literal: true

require("test_helper")

class AdminConfigTest < ActiveSupport::TestCase
  context("AdminConfig env overrides") do
    teardown do
      ENV.delete("GAYFURCITY_ADMIN_CONFIG_RECORDS_PER_PAGE")
      ENV.delete("GAYFURCITY_ADMIN_CONFIG_ENABLE_SIGNUPS")
      ENV.delete("GAYFURCITY_ADMIN_CONFIG_IMAGE_WIDTH")
      ENV.delete("GAYFURCITY_ADMIN_CONFIG_COMMENT_LIMIT_BYPASS")
    end

    should("pin an integer column to the env value") do
      ENV["GAYFURCITY_ADMIN_CONFIG_RECORDS_PER_PAGE"] = "42"

      assert_equal(42, AdminConfig.uncached.records_per_page)
      assert_equal(42, AdminConfig.get(:records_per_page))
    end

    should("pin a boolean column to the env value") do
      ENV["GAYFURCITY_ADMIN_CONFIG_ENABLE_SIGNUPS"] = "false"

      assert_not(AdminConfig.uncached.enable_signups)
      assert_not(AdminConfig.uncached.enable_signups?)
    end

    should("pin a jsonb column to the parsed env value") do
      ENV["GAYFURCITY_ADMIN_CONFIG_IMAGE_WIDTH"] = '{"min":10,"max":20}'

      assert_equal({ "min" => 10, "max" => 20 }, AdminConfig.uncached.image_width)
    end

    should("apply the override to bypass columns too") do
      ENV["GAYFURCITY_ADMIN_CONFIG_COMMENT_LIMIT_BYPASS"] = "0"
      user = create(:anonymous_user)

      assert(AdminConfig.bypass?(:comment_limit, user))
    end

    should("exclude overridden columns from settable_columns") do
      ENV["GAYFURCITY_ADMIN_CONFIG_RECORDS_PER_PAGE"] = "42"
      user = create(:owner_user)

      assert_not_includes(AdminConfig.settable_columns(user).map(&:name), "records_per_page")
      assert_not(AdminConfig.usable?(user, :records_per_page))
    end
  end
end

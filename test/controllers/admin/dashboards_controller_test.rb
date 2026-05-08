# frozen_string_literal: true

require("test_helper")

module Admin
  class DashboardsControllerTest < ActionDispatch::IntegrationTest
    context("The admin dashboard controller") do
      setup do
        @admin = create(:admin_user)
      end

      context("show action") do
        should("render") do
          get_auth(admin_dashboard_path, @admin)

          assert_response(:success)
        end

        should("restrict access") do
          assert_access(User::Levels::ADMIN) { |user| get_auth(admin_dashboard_path, user) }
        end
      end
    end
  end
end

# frozen_string_literal: true

require("test_helper")

class SystemsControllerTest < ActionDispatch::IntegrationTest
  context("The systems controller") do
    setup do
      @user = create(:owner_user)
    end

    context("show action") do
      should("render") do
        get_auth(system_path, @user)

        assert_response(:success)
      end

      context("access control") do
        asserts do
          access.gte(User::Levels::OWNER).get { system_path }
        end
      end
    end

    context("dbsize action") do
      should("render") do
        get_auth(dbsize_system_path, @user)

        assert_response(:success)
      end

      context("access control") do
        asserts do
          access.gte(User::Levels::OWNER).get { dbsize_system_path }
        end
      end
    end
  end
end

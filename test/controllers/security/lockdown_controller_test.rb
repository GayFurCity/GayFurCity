# frozen_string_literal: true

require("test_helper")

module Security
  class LockdownControllerTest < ActionDispatch::IntegrationTest
    context("The lockdown controller") do
      setup do
        @admin = create(:admin_user)
      end

      teardown do
        Security::Lockdown::BOOLEAN_TYPES.each do |type|
          Security::Lockdown.public_send("#{type}_disabled=", false)
        end
        Security::Lockdown.uploads_min_level = User::Levels::MEMBER
        Security::Lockdown.hide_pending_posts_for = 0
      end

      context("index action") do
        should("render") do
          get_auth(security_root_path, @admin)

          assert_response(:success)
        end

        context("access control") do
          asserts do
            access.gte(User::Levels::ADMIN).get(security_root_path)
          end
        end
      end

      context("panic action") do
        should("work") do
          put_auth(panic_security_lockdown_index_path, @admin)

          Security::Lockdown::BOOLEAN_TYPES.each do |type|
            assert(Security::Lockdown.public_send("#{type}_disabled?"), type) # rubocop:disable Minitest/AssertWithExpectedArgument -- type is being used as the message
          end
        end

        context("access control") do
          asserts do
            access.gte(User::Levels::ADMIN).put(panic_security_lockdown_index_path).success(:redirect)
          end
        end
      end

      context("enact action") do
        should("work") do
          put_auth(enact_security_lockdown_index_path, @admin, params: { lockdown: Security::Lockdown::BOOLEAN_TYPES.index_with { |_type| true } })

          Security::Lockdown::BOOLEAN_TYPES.each do |type|
            assert(Security::Lockdown.public_send("#{type}_disabled?"), type) # rubocop:disable Minitest/AssertWithExpectedArgument -- type is being used as the message
          end
        end

        context("access control") do
          asserts do
            access.gte(User::Levels::ADMIN).put(enact_security_lockdown_index_path).params { { lockdown: Security::Lockdown::BOOLEAN_TYPES.index_with { |_type| true } } }.success(:redirect)
          end
        end
      end

      context("uploading limits action") do
        should("work") do
          put_auth(uploads_min_level_security_lockdown_index_path, @admin, params: { uploads_min_level: { min_level: User::Levels::TRUSTED } })

          assert_equal(Security::Lockdown.uploads_min_level, User::Levels::TRUSTED)
        end

        context("access control") do
          asserts do
            access.gte(User::Levels::ADMIN).put(enact_security_lockdown_index_path).params { { uploads_min_level: { min_level: User::Levels::TRUSTED } } }.success(:redirect)
          end
        end
      end

      context("hide pending posts action") do
        should("work") do
          put_auth(uploads_hide_pending_security_lockdown_index_path, @admin, params: { uploads_hide_pending: { duration: 24 } })

          assert_equal(24, Security::Lockdown.hide_pending_posts_for)
        end

        context("access control") do
          asserts do
            access.gte(User::Levels::ADMIN).put(uploads_hide_pending_security_lockdown_index_path).params { { uploads_hide_pending: { duration: 24 } } }.success(:redirect)
          end
        end
      end
    end
  end
end

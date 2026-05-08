# frozen_string_literal: true

require("test_helper")

module Moderator
  class IpAddrsControllerTest < ActionDispatch::IntegrationTest
    context("The ip addrs controller") do
      setup do
        @user = create(:admin_user, created_at: 1.month.ago)

        create(:comment, creator: @user)
      end

      context("index action") do
        should("fail for moderators") do
          get_auth(moderator_ip_addrs_path, create(:moderator_user), params: { search: { ip_addr: "127.0.0.1" } })

          assert_response(:forbidden)
        end

        should("find by ip addr") do
          get_auth(moderator_ip_addrs_path, @user, params: { search: { ip_addr: "127.0.0.1" } })

          assert_response(:success)
        end

        should("find by user id") do
          get_auth(moderator_ip_addrs_path, @user, params: { search: { user_id: @user.id } })

          assert_response(:success)
        end

        should("find by user name") do
          get_auth(moderator_ip_addrs_path, @user, params: { search: { user_name: @user.name } })

          assert_response(:success)
        end

        should("restrict access") do
          assert_access(User::Levels::ADMIN) { |user| get_auth(moderator_ip_addrs_path, user) }
        end
      end

      context("export action") do
        should("restrict access") do
          assert_access(User::Levels::ADMIN, anonymous_response: :forbidden) { |user| get_auth(export_moderator_ip_addrs_path, user, params: { format: :json }) }
        end
      end
    end
  end
end

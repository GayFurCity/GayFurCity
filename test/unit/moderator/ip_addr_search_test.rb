# frozen_string_literal: true

require("test_helper")

module Moderator
  class IpAddrSearchTest < ActiveSupport::TestCase
    context("an ip addr search") do
      setup do
        @user = create(:user)
        create(:comment, creator: @user, creator_ip_addr: "170.1.2.3")
      end

      should("find by ip addr") do
        @result = IpAddrSearch.new(ip_addr: "170.1.2.3").execute

        assert_equal(@result[:users][@user.id].id, @user.id)
        assert_equal(1, @result[:sums][:comment][@user.id])
      end

      should("find by user id") do
        @result = IpAddrSearch.new(user_id: @user.id.to_s).execute

        assert_equal(1, @result[:sums][:comment][IPAddr.new("170.1.2.3")])
      end

      should("find by user name") do
        @result = IpAddrSearch.new(user_name: @user.name).execute

        assert_equal(1, @result[:sums][:comment][IPAddr.new("170.1.2.3")])
      end
    end
  end
end

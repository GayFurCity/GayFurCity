# frozen_string_literal: true

require("test_helper")
require_relative("helper")

module ModActions
  class PostSetsest < ActiveSupport::TestCase
    include(Helper)
    include(Rails.application.routes.url_helpers)

    context("mod actions for post sets") do
      setup do
        @set = create(:post_set, creator: @user)
        set_count!
      end

      should("format set_change_visibility correctly") do
        GayFurCity.config.stubs(:disable_age_checks).returns(true)
        @set.update_with!(@admin, is_public: true)

        assert_matches(
          actions:   %w[set_change_visibility],
          text:      "Made set ##{@set.id} by #{user(@user)} public",
          subject:   @set,
          is_public: true,
          user_id:   @user.id,
        )
      end

      should("format set_delete correctly") do
        @set.destroy_with(@admin)

        assert_matches(
          actions: %w[set_delete],
          text:    "Deleted set ##{@set.id} by #{user(@user)}",
          subject: @set,
          user_id: @user.id,
        )
      end

      should("format set_update correctly") do
        @set.update_with!(@admin, name: "xxx")

        assert_matches(
          actions: %w[set_update],
          text:    "Updated set ##{@set.id} by #{user(@user)}",
          subject: @set,
          user_id: @user.id,
        )
      end
    end
  end
end

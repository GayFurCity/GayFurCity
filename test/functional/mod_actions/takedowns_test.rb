# frozen_string_literal: true

require("test_helper")
require_relative("helper")

module ModActions
  class TakedownsTest < ActiveSupport::TestCase
    include(Helper)
    include(Rails.application.routes.url_helpers)

    context("mod actions for takedowns") do
      setup do
        @takedown = create(:takedown)
        set_count!
      end

      should("format takedown_process correctly") do
        with_inline_jobs { @takedown.process!(@admin, "Artist requested removal") }

        assert_matches(
          actions: %w[takedown_process],
          text:    "Completed takedown ##{@takedown.id}",
          subject: @takedown,
        )
      end

      should("format takedown_delete") do
        @takedown.destroy_with(@admin)

        assert_matches(
          actions: %w[takedown_delete],
          text:    "Deleted takedown ##{@takedown.id}",
          subject: @takedown,
        )
      end
    end
  end
end

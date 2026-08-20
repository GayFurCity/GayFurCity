# frozen_string_literal: true

require("test_helper")
require_relative("helper")

module ModActions
  class AvoidPostingsTest < ActiveSupport::TestCase
    include(Helper)
    include(Rails.application.routes.url_helpers)

    context("mod actions for avoid posting entries") do
      setup do
        @avoid_posting = create(:avoid_posting, creator: @admin)
        set_count!
      end

      should("parse avoid_posting_create correctly") do
        @avoid_posting = create(:avoid_posting, creator: @admin)

        assert_matches(
          actions:     %w[avoid_posting_create],
          text:        "Created avoid posting ##{@avoid_posting.id} for [[#{@avoid_posting.artist_name}]]",
          subject:     @avoid_posting,
          artist_name: @avoid_posting.artist_name,
        )
      end

      should("parse avoid_posting_delete correctly") do
        @avoid_posting.update_with!(@admin, is_active: false)

        assert_matches(
          actions:     %w[avoid_posting_delete],
          text:        "Deleted avoid posting ##{@avoid_posting.id} for [[#{@avoid_posting.artist_name}]]",
          subject:     @avoid_posting,
          artist_name: @avoid_posting.artist_name,
        )
      end

      should("parse avoid_posting_destroy correctly") do
        @avoid_posting.destroy_with(@admin)

        assert_matches(
          actions:     %w[avoid_posting_destroy],
          text:        "Destroyed avoid posting ##{@avoid_posting.id} for [[#{@avoid_posting.artist_name}]]",
          subject:     @avoid_posting,
          artist_name: @avoid_posting.artist_name,
        )
      end

      should("parse avoid_posting_undelete correctly") do
        @avoid_posting.update_columns(is_active: false)
        @avoid_posting.update_with!(@admin, is_active: true)

        assert_matches(
          actions:     %w[avoid_posting_undelete],
          text:        "Undeleted avoid posting ##{@avoid_posting.id} for [[#{@avoid_posting.artist_name}]]",
          subject:     @avoid_posting,
          artist_name: @avoid_posting.artist_name,
        )
      end

      should("parse avoid_posting_update correctly") do
        @avoid_posting.update_with!(@admin, details: "foo")

        assert_matches(
          actions:     %w[avoid_posting_update],
          text:        "Updated avoid posting ##{@avoid_posting.id} for [[#{@avoid_posting.artist_name}]]",
          subject:     @avoid_posting,
          artist_name: @avoid_posting.artist_name,
        )
      end
    end
  end
end

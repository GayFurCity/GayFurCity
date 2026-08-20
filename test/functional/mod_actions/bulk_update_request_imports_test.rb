# frozen_string_literal: true

require("test_helper")
require_relative("helper")

module ModActions
  class BulkUpdateRequestImportsTest < ActiveSupport::TestCase
    include(Helper)

    context("mod actions for bulk update request imports") do
      should("format bulk_update_request_import_create correctly") do
        @import = create(:bulk_update_request_import, creator: @admin)

        assert_matches(
          actions: %w[bulk_update_request_import_create],
          text:    "Created bulk update request import ##{@import.id}",
          subject: @import,
        )
      end

      should("format bulk_update_request_import_update correctly") do
        @import = create(:bulk_update_request_import, creator: @admin)
        set_count!
        @import.update_with(@user, script: "alias foo -> bar")

        assert_matches(
          actions: %w[bulk_update_request_import_update],
          text:    "Updated bulk update request import ##{@import.id}",
          subject: @import,
          creator: @user,
        )
      end

      should("format bulk_update_request_import_retry correctly") do
        @import = create(:bulk_update_request_import, creator: @user)
        @import.update_columns(status: "failed", status_message: "boom")
        set_count!

        @import.retry!(@admin)

        assert_matches(
          actions: %w[bulk_update_request_import_retry],
          text:    "Retried bulk update request import ##{@import.id}",
          subject: @import,
          creator: @admin,
        )
      end
    end
  end
end

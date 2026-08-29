# frozen_string_literal: true

require("test_helper")
require_relative("helper")

module ModActions
  class NewsTest < ActiveSupport::TestCase
    include(Helper)
    include(Rails.application.routes.url_helpers)

    context("mod actions for news") do
      setup do
        @news_update = create(:news_update)
        set_count!
      end

      should("parse news_create correctly") do
        @news_update = create(:news_update, creator: @admin)

        assert_matches(
          actions: %w[news_create],
          text:    %(Created "news update ##{@news_update.id}":[#{news_updates_path(search: { id: @news_update.id })}]\n[section=Message]#{@news_update.message}[/section]),
          subject: @news_update,
          message: @news_update.message,
        )
      end

      should("parse news_delete correctly") do
        @news_update.destroy_with(@admin)

        assert_matches(
          actions: %w[news_delete],
          text:    %(Deleted "news update ##{@news_update.id}":[#{news_updates_path(search: { id: @news_update.id })}]\n[section=Message]#{@news_update.message}[/section]),
          subject: @news_update,
          message: @news_update.message,
        )
      end

      should("parse news_update correctly") do
        @original = @news_update.dup
        @news_update.update_with!(@admin, message: "xxx")

        assert_matches(
          actions:     %w[news_update],
          text:        %(Updated "news update ##{@news_update.id}":[#{news_updates_path(search: { id: @news_update.id })}]\n[section=Old Message]#{@original.message}[/section]\n[section=New Message]#{@news_update.message}[/section]),
          subject:     @news_update,
          message:     @news_update.message,
          old_message: @original.message,
        )
      end
    end
  end
end

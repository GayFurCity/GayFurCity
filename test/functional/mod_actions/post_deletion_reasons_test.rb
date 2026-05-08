# frozen_string_literal: true

require("test_helper")
require_relative("helper")

module ModActions
  class PostDeletionReasonsTest < ActiveSupport::TestCase
    include(Helper)
    include(Rails.application.routes.url_helpers)

    context("mod actions for post deletion reasons") do
      setup do
        @reason = create(:post_deletion_reason, creator: @admin)
        set_count!
      end

      should("format post_deletion_reason_create correctly") do
        @reason = create(:post_deletion_reason, creator: @admin)

        assert_matches(
          actions: %w[post_deletion_reason_create],
          text:    "Created post deletion reason \"#{@reason.reason}\"",
          subject: @reason,
          reason:  @reason.reason,
        )
      end

      should("format post_deletion_reason_delete correctly") do
        @reason.destroy_with(@admin)

        assert_matches(
          actions: %w[post_deletion_reason_delete],
          text:    "Deleted post deletion reason \"#{@reason.reason}\" by #{user(@admin)}",
          subject: @reason,
          reason:  @reason.reason,
          user_id: @admin.id,
        )
      end

      should("format post_deletion_reasons_reorder correctly") do
        PostDeletionReason.log_reorder(2, @admin)

        assert_matches(
          actions: %w[post_deletion_reasons_reorder],
          text:    "Changed the order of 2 post deletion reasons.",
          subject: nil,
          total:   2,
        )
      end

      context("post_deletion_reason_update") do
        setup do
          @original = @reason.dup
        end

        should("format no changes correctly") do
          @reason.save

          assert_matches(
            actions:    %w[post_deletion_reason_update],
            text:       "Updated post deletion reason \"#{@reason.reason}\"",
            subject:    @reason,
            reason:     @reason.reason,
            old_reason: @original.reason,
            prompt:     @reason.prompt,
            old_prompt: @original.prompt,
            title:      @reason.title,
            old_title:  @original.title,
          )
        end

        should("format reason changes correctly") do
          @reason.update_with!(@admin, reason: "xxx")

          assert_matches(
            actions:    %w[post_deletion_reason_update],
            text:       <<~TEXT.strip,
              Updated post deletion reason "#{@reason.reason}"
              Changed reason from "#{@original.reason}" to "#{@reason.reason}"
            TEXT
            subject:    @reason,
            reason:     @reason.reason,
            old_reason: @original.reason,
            prompt:     @reason.prompt,
            old_prompt: @original.prompt,
            title:      @reason.title,
            old_title:  @original.title,
          )
        end

        should("format prompt changes correctly") do
          @reason.update_with!(@admin, prompt: "xxx")

          assert_matches(
            actions:    %w[post_deletion_reason_update],
            text:       <<~TEXT.strip,
              Updated post deletion reason "#{@reason.reason}"
              Changed prompt from "#{@original.prompt}" to "#{@reason.prompt}"
            TEXT
            subject:    @reason,
            reason:     @reason.reason,
            old_reason: @original.reason,
            prompt:     @reason.prompt,
            old_prompt: @original.prompt,
            title:      @reason.title,
            old_title:  @original.title,
          )
        end

        should("format title changes correctly") do
          @reason.update_with!(@admin, title: "xxx")

          assert_matches(
            actions:    %w[post_deletion_reason_update],
            text:       <<~TEXT.strip,
              Updated post deletion reason "#{@original.reason}"
              Changed title from "#{@original.title}" to "#{@reason.title}"
            TEXT
            subject:    @reason,
            reason:     @reason.reason,
            old_reason: @original.reason,
            prompt:     @reason.prompt,
            old_prompt: @original.prompt,
            title:      @reason.title,
            old_title:  @original.title,
          )
        end

        should("format all changes correctly") do
          @reason.update_with!(@admin, reason: "xxx", prompt: "yyy", title: "zzz")

          assert_matches(
            actions:    %w[post_deletion_reason_update],
            text:       <<~TEXT.strip,
              Updated post deletion reason "#{@reason.reason}"
              Changed reason from "#{@original.reason}" to "#{@reason.reason}"
              Changed prompt from "#{@original.prompt}" to "#{@reason.prompt}"
              Changed title from "#{@original.title}" to "#{@reason.title}"
            TEXT
            subject:    @reason,
            reason:     @reason.reason,
            old_reason: @original.reason,
            prompt:     @reason.prompt,
            old_prompt: @original.prompt,
            title:      @reason.title,
            old_title:  @original.title,
          )
        end
      end
    end
  end
end

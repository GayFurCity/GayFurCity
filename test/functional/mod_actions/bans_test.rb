# frozen_string_literal: true

require("test_helper")
require_relative("helper")

module ModActions
  class BansTest < ActiveSupport::TestCase
    include(Helper)
    include(Rails.application.routes.url_helpers)

    def format_expires_at(timestamp)
      timestamp.nil? ? "never" : DateTime.parse(timestamp).strftime("%Y-%m-%d %H:%M")
    end

    context("mod actions for bans") do
      setup do
        @ban = create(:ban, user: @user, creator: @admin)
        set_count!
      end

      context("ban_create") do
        should("format permanent bans correctly") do
          @ban = create(:ban, duration: -1, user: @user, creator: @admin)

          assert_matches(
            actions:  %w[ban_create user_feedback_create],
            subject:  @ban,
            text:     "Created ban for #{user(@user)} lasting forever with reason:\n[section=Reason]#{@ban.reason}[/section]",
            duration: -1,
            user_id:  @user.id,
            reason:   @ban.reason,
          )
        end

        should("format temporary bans correctly") do
          @ban = create(:ban, duration: 1, user: @user, creator: @admin)

          assert_matches(
            actions:  %w[ban_create user_feedback_create],
            subject:  @ban,
            text:     "Created ban for #{user(@user)} lasting 1 day with reason:\n[section=Reason]#{@ban.reason}[/section]",
            duration: 1,
            user_id:  @user.id,
            reason:   @ban.reason,
          )
        end

        # should be impossible in normal usage
        should("format invalid durations correctly") do
          @ban = build(:ban, duration: nil, user: @user, creator: @admin)
          @ban.save(validate: false)

          assert_matches(
            actions:  %w[ban_create user_feedback_create],
            subject:  @ban,
            text:     "Created ban for #{user(@user)} with reason:\n[section=Reason]#{@ban.reason}[/section]",
            duration: nil,
            user_id:  @user.id,
            reason:   @ban.reason,
          )
        end
      end

      should("format ban_delete correctly") do
        @ban.destroy_with(@admin)

        assert_matches(
          actions: %w[ban_delete],
          subject: @ban,
          text:    "Deleted ban for #{user(@user)}",
          user_id: @user.id,
        )
      end

      context("ban_update") do
        setup do
          @original = @ban.dup
        end

        should("format no changes correctly") do
          @ban.updater = @admin
          @ban.save

          assert_matches(
            actions:        %w[ban_update],
            subject:        @ban,
            text:           "Updated ban for #{user(@user)}",
            expires_at:     nil,
            old_expires_at: nil,
            reason:         nil,
            old_reason:     nil,
            user_id:        @user.id,
          )
        end

        should("format duration changes correctly") do
          @ban.update_with!(@admin, duration: -1)

          assert_matches(
            actions:        %w[ban_update],
            subject:        @ban,
            text:           <<~TEXT.strip,
              Updated ban for #{user(@user)}
              Changed expiration from #{format_expires_at(@original.expires_at.iso8601)} to #{format_expires_at(@ban.expires_at&.iso8601)}
            TEXT
            expires_at:     nil,
            old_expires_at: @original.expires_at&.iso8601,
            reason:         nil,
            old_reason:     nil,
            user_id:        @user.id,
          )
        end

        should("format reason changes correctly") do
          @ban.update_with!(@admin, reason: "xxx")

          assert_matches(
            actions:        %w[ban_update],
            subject:        @ban,
            text:           <<~TEXT.strip,
              Updated ban for #{user(@user)}
              Changed reason: [section=Old]#{@original.reason}[/section] [section=New]#{@ban.reason}[/section]
            TEXT
            expires_at:     nil,
            old_expires_at: nil,
            reason:         @ban.reason,
            old_reason:     @original.reason,
            user_id:        @user.id,
          )
        end

        should("format both duration and reason changes correctly") do
          @ban.update_with!(@admin, duration: -1, reason: "xxx")

          assert_matches(
            actions:        %w[ban_update],
            subject:        @ban,
            text:           <<~TEXT.strip,
              Updated ban for #{user(@user)}
              Changed expiration from #{format_expires_at(@original.expires_at.iso8601)} to #{format_expires_at(@ban.expires_at&.iso8601)}
              Changed reason: [section=Old]#{@original.reason}[/section] [section=New]xxx[/section]
            TEXT
            expires_at:     nil,
            old_expires_at: @original.expires_at.iso8601,
            reason:         "xxx",
            old_reason:     @original.reason,
            user_id:        @user.id,
          )
        end
      end
    end
  end
end

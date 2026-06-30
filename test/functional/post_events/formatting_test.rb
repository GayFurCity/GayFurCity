# frozen_string_literal: true

require("test_helper")
require_relative("helper")

module PostEvents
  class FormattingTest < ActiveSupport::TestCase
    include(Helper)
    include(Rails.application.routes.url_helpers)

    context("post events for") do
      setup do
        @post = create(:post)
      end

      context("deletions") do
        should("format deleted correctly") do
          @post.delete!(@admin, "Test")

          assert_matches(
            post_id: @post.id,
            actions: %w[deleted],
            text:    "Test",
            reason:  "Test",
          )
        end

        should("format undeleted correctly") do
          @post.update_column(:is_deleted, true)
          @post.undelete!(@admin)

          assert_matches(
            post_id: @post.id,
            actions: %w[undeleted],
            text:    "",
          )
        end
      end

      context("approvals") do
        should("format approved correctly") do
          @post.approve!(@admin)

          assert_matches(
            post_id: @post.id,
            actions: %w[approved],
            text:    "",
          )
        end

        should("format unapproved correctly") do
          @post.update_column(:is_pending, false)
          @post.unapprove!(@admin)

          assert_matches(
            post_id: @post.id,
            actions: %w[unapproved],
            text:    "",
          )
        end
      end

      context("flags") do
        should("format flag_created correctly") do
          @flag = @post.flags.create!(reason_name: "uploading_guidelines", creator: @admin, note: "abc")

          reason = GayFurCity.config.flag_reasons.find { |r| r[:name] == "uploading_guidelines" }[:reason]

          assert_matches(
            post_id:      @post.id,
            actions:      %w[flag_created],
            text:         reason,
            post_flag_id: @flag.id,
            reason:       reason,
          )
        end

        should("format flag_removed correctly") do
          @post2 = create(:post, parent_id: @post.id)
          @post2.give_favorites_to_parent!(@admin)

          # FIXME: make a way to test two actions at once, as these are both only ever created at the same time in a determined order
          assert_matches(
            post_id:   @post2.id,
            actions:   %w[favorites_moved favorites_received],
            text:      "Target: post ##{@post.id}",
            parent_id: @post.id,
          )
        end
      end

      context("locks") do
        should("format rating_locked correctly") do
          @post.update_with!(@admin, is_rating_locked: true)

          assert_matches(
            post_id: @post.id,
            actions: %w[rating_locked],
            text:    "",
          )
        end

        should("format rating_unlocked correctly") do
          @post.update_column(:is_rating_locked, true)
          @post.update_with!(@admin, is_rating_locked: false)

          assert_matches(
            post_id: @post.id,
            actions: %w[rating_unlocked],
            text:    "",
          )
        end

        should("format status_locked correctly") do
          @post.update_with!(@admin, is_status_locked: true)

          assert_matches(
            post_id: @post.id,
            actions: %w[status_locked],
            text:    "",
          )
        end

        should("format status_unlocked correctly") do
          @post.update_column(:is_status_locked, true)
          @post.update_with!(@admin, is_status_locked: false)

          assert_matches(
            post_id: @post.id,
            actions: %w[status_unlocked],
            text:    "",
          )
        end

        should("format note_locked correctly") do
          @post.update_with!(@admin, is_note_locked: true)

          assert_matches(
            post_id: @post.id,
            actions: %w[note_locked],
            text:    "",
          )
        end

        should("format note_unlocked correctly") do
          @post.update_column(:is_note_locked, true)
          @post.update_with!(@admin, is_note_locked: false)

          assert_matches(
            post_id: @post.id,
            actions: %w[note_unlocked],
            text:    "",
          )
        end
      end

      context("replacements") do
        setup do
          @upload = create(:png_upload, uploader: @admin)
          @post = @upload.post
          @replacement = create(:jpg_replacement, post: @post)
          set_count!
        end

        should("format replacement_accepted correctly") do
          previous_md5 = @post.md5
          @replacement.approve!(@admin, penalize_current_uploader: true)

          assert_matches(
            post_id:             @post.id,
            actions:             %w[replacement_accepted],
            text:                "\"replacement ##{@replacement.id}\":#{post_replacements_path(search: { id: @replacement.id })}",
            post_replacement_id: @replacement.id,
            old_md5:             previous_md5,
            new_md5:             @replacement.md5,
          )
        end

        should("format replacement_rejected correctly") do
          @replacement.reject!(@admin)

          assert_matches(
            post_id:             @post.id,
            actions:             %w[replacement_rejected],
            text:                "\"replacement ##{@replacement.id}\":#{post_replacements_path(search: { id: @replacement.id })}",
            post_replacement_id: @replacement.id,
          )
        end

        should("format replacement_promoted correctly") do
          @post2 = @replacement.promote!(@admin).post

          assert_matches(
            post_id:             @post2.id,
            actions:             %w[replacement_promoted],
            text:                "Source: post ##{@post.id}",
            post_replacement_id: @replacement.id,
            source_post_id:      @post.id,
          )
        end

        context("replacement_deleted") do
          should("format correctly for admins") do
            @replacement.destroy_with(@admin)

            CurrentUser.scoped(@admin) do # rubocop:disable YiffSpace/CurrentOutsideOfRequests
              assert_matches(
                post_id:             @post.id,
                actions:             %w[replacement_deleted],
                text:                "",
                post_replacement_id: @replacement.id,
                md5:                 @replacement.md5,
                storage_id:          @replacement.storage_id,
              )
            end
          end

          should("format correctly for users") do
            @replacement.destroy_with(@admin)

            CurrentUser.scoped(@user) do # rubocop:disable YiffSpace/CurrentOutsideOfRequests
              assert_matches(
                post_id:             @post.id,
                actions:             %w[replacement_deleted],
                text:                "",
                post_replacement_id: @replacement.id,
              )
            end
          end
        end
      end

      context("misc") do
        should("format expunged correctly") do
          @post.expunge!(@admin)

          assert_matches(
            post_id: @post.id,
            actions: %w[expunged],
            text:    "",
          )
        end

        should("format changed_bg_color correctly") do
          @post.update_with!(@admin, bg_color: "000000")

          assert_matches(
            post_id:  @post.id,
            actions:  %w[changed_bg_color],
            text:     "To: #000000",
            bg_color: "000000",
          )
        end

        should("format changed_thumbnail_frame correctly") do
          @upload = create(:webm_upload, uploader: @admin)
          @post = @upload.post
          set_count!
          @post.update_with!(@admin, thumbnail_frame: 1)

          assert_matches(
            post_id:             @post.id,
            actions:             %w[changed_thumbnail_frame],
            text:                "Default -> 1",
            old_thumbnail_frame: nil,
            new_thumbnail_frame: 1,
          )
        end

        should("format copied_notes correctly") do
          @post2 = create(:post)
          @note = create(:note, post: @post)
          @post.copy_notes_to(@post2, @admin)

          assert_matches(
            post_id:        @post2.id,
            actions:        %w[copied_notes],
            text:           "Copied 1 note from post ##{@post.id}",
            source_post_id: @post.id,
            note_count:     1,
          )
        end

        should("format set_min_edit_level correctly") do
          @post.update_with!(@admin, min_edit_level: User::Levels::TRUSTED)

          assert_matches(
            post_id:        @post.id,
            actions:        %w[set_min_edit_level],
            text:           "To: [b]#{User::Levels.id_to_name(User::Levels::TRUSTED)}[/b]",
            min_edit_level: User::Levels::TRUSTED,
          )
        end
      end

      context("appeals") do
        setup do
          @post.update_column(:is_deleted, true)
          @appeal = @post.appeals.create!(reason: "Test", creator: @admin)
          set_count!
        end

        should("format appeal_created correctly") do
          @appeal.destroy
          @appeal = @post.appeals.create!(reason: "Test", creator: @admin)

          assert_matches(
            post_id:        @post.id,
            actions:        %w[appeal_created],
            text:           "\"appeal ##{@appeal.id}\":#{post_appeals_path(search: { id: @appeal.id })}",
            post_appeal_id: @appeal.id,
          )
        end

        should("format appeal_accepted correctly") do
          @appeal.accept!(@admin)

          assert_matches(
            post_id:        @post.id,
            actions:        %w[appeal_accepted],
            text:           "\"appeal ##{@appeal.id}\":#{post_appeals_path(search: { id: @appeal.id })}",
            post_appeal_id: @appeal.id,
          )
        end

        should("format appeal_rejected correctly") do
          @appeal.reject!(@admin)

          assert_matches(
            post_id:        @post.id,
            actions:        %w[appeal_rejected],
            text:           "\"appeal ##{@appeal.id}\":#{post_appeals_path(search: { id: @appeal.id })}",
            post_appeal_id: @appeal.id,
          )
        end
      end
    end
  end
end

# frozen_string_literal: true

require("test_helper")

class PostEventTest < ActiveSupport::TestCase
  setup do
    travel_to(1.month.ago) do
      @user = create(:user)
      @janitor = create(:janitor_user)
      @admin = create(:admin_user)
    end

    @post2 = create(:post, uploader: @user)
    @post = create(:post, uploader: @user, parent: @post2)
  end

  def assert_post_events_created(user, events, &)
    count = Array.wrap(events).count

    assert_difference("PostEvent.count", count, &)
    list = PostEvent.last(count)

    assert_equal(Array.wrap(events).map(&:to_s), list.map(&:action))
    assert_equal([user] * count, list.map(&:creator))
  end

  context("certain actions") do
    should("create a post event") do
      assert_post_events_created(@janitor, :approved) do
        @post.approve!(@janitor)
      end

      assert_post_events_created(@janitor, :unapproved) do
        @post.unapprove!(@janitor)
      end

      assert_post_events_created(@user, :flag_created) do
        create(:post_flag, post: @post, creator: @user)
      end

      assert_post_events_created(@janitor, :flag_removed) do
        @post.unflag!(@janitor)
      end

      assert_post_events_created(@janitor, :deleted) do
        @post.delete!(@janitor, "reason")
      end

      assert_post_events_created(@janitor, :undeleted) do
        @post.undelete!(@janitor)
      end

      assert_post_events_created(@janitor, %i[favorites_moved favorites_received]) do
        TransferFavoritesJob.new.perform(@post, @janitor)
      end

      assert_post_events_created(@admin, :rating_locked) do
        @post.is_rating_locked = true
        @post.updater = @admin
        @post.save
      end

      assert_post_events_created(@admin, :rating_unlocked) do
        @post.is_rating_locked = false
        @post.updater = @admin
        @post.save
      end

      assert_post_events_created(@admin, :status_locked) do
        @post.is_status_locked = true
        @post.updater = @admin
        @post.save
      end

      assert_post_events_created(@admin, :status_unlocked) do
        @post.is_status_locked = false
        @post.updater = @admin
        @post.save
      end

      assert_post_events_created(@admin, :comment_disabled) do
        @post.is_comment_disabled = true
        @post.updater = @admin
        @post.save
      end

      assert_post_events_created(@admin, :comment_enabled) do
        @post.is_comment_disabled = false
        @post.updater = @admin
        @post.save
      end

      assert_post_events_created(@admin, :comment_locked) do
        @post.is_comment_locked = true
        @post.updater = @admin
        @post.save
      end

      assert_post_events_created(@admin, :comment_unlocked) do
        @post.is_comment_locked = false
        @post.updater = @admin
        @post.save
      end

      assert_post_events_created(@admin, :note_locked) do
        @post.is_note_locked = true
        @post.updater = @admin
        @post.save
      end

      assert_post_events_created(@admin, :note_unlocked) do
        @post.is_note_locked = false
        @post.updater = @admin
        @post.save
      end

      assert_post_events_created(@janitor, :changed_bg_color) do
        @post.bg_color = "FFFFFF"
        @post.updater = @janitor
        @post.save
      end

      assert_post_events_created(@janitor, :copied_notes) do
        create(:note, post: @post, creator: @janitor)
        @post.copy_notes_to(@post2, @janitor)
      end

      assert_post_events_created(@admin, :set_min_edit_level) do
        @post.update_with(@admin, min_edit_level: User::Levels::TRUSTED)
      end

      assert_post_events_created(@admin, :expunged) do
        @post.expunge!(@admin)
      end
    end

    context("replacements") do
      setup do
        upload = create(:gif_upload, uploader: @user, tag_string: "tst")
        @post = upload.post
        @replacement = create(:png_replacement, creator: @user, post: @post)
      end

      should("reject") do
        assert_post_events_created(@admin, :replacement_rejected) do
          @replacement.reject!(@admin)
        end
      end

      should("approve") do
        assert_post_events_created(@admin, :replacement_accepted) do
          @replacement.approve!(@admin, penalize_current_uploader: true)
        end
      end

      should("destroy") do
        assert_post_events_created(@admin, :replacement_deleted) do
          @replacement.destroy_with!(@admin)
        end
      end
    end
  end
end

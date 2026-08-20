# frozen_string_literal: true

require("test_helper")

class PostReplacementHelperTest < ActionView::TestCase
  context("The post replacement helper") do
    context("replacement_thumbnail method") do
      setup do
        @admin = create(:admin_user, created_at: 2.weeks.ago)
        @upload = create(:jpg_upload, uploader: @admin)
        @post = @upload.post
        @post.update_columns(is_pending: false, approver_id: @admin.id)
      end

      should("show the missing preview for a metadata-only backup") do
        replacement = create(:png_replacement, creator: @admin, post: @post)
        File.delete(@post.media_asset.file_path)
        replacement.approve!(@admin, penalize_current_uploader: false, force_missing_backup: true)
        backup = @post.replacements.original.sole

        assert_predicate(backup, :metadata_only?)

        html = CurrentUser.scoped(@admin) { replacement_thumbnail(backup) } # rubocop:disable YiffSpace/CurrentOutsideOfRequests

        assert_includes(html, Config.instance.missing_preview_url)
      end

      should("show the normal thumbnail for a real backup") do
        replacement = create(:png_replacement, creator: @admin, post: @post)
        replacement.approve!(@admin, penalize_current_uploader: false)
        backup = @post.replacements.original.sole

        assert_not(backup.metadata_only?)

        html = CurrentUser.scoped(@admin) { replacement_thumbnail(backup) } # rubocop:disable YiffSpace/CurrentOutsideOfRequests

        assert_not_includes(html, Config.instance.missing_preview_url)
      end
    end
  end
end

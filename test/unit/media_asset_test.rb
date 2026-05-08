# frozen_string_literal: true

require("test_helper")

class MediaAssetTest < ActiveSupport::TestCase
  include(ActiveJob::TestHelper)

  setup do
    @user = create(:user)
  end

  context("A media asset") do
    should("delete files after 24 hours") do
      assert_enqueued_jobs(1, only: MediaAssetDeleteTempfileJob) do
        @upload = create(:jpg_upload)
      end

      assert_path_exists(@upload.media_asset.tempfile_path)
      perform_enqueued_jobs(only: MediaAssetDeleteTempfileJob)

      assert_not(File.exist?(@upload.media_asset.tempfile_path))
    end

    should("expire after 4 hours") do
      @asset = create(:upload_media_asset)
      travel_to(5.hours.from_now) do
        MediaAsset.prune_expired!
        @asset.reload

        assert_equal("failed", @asset.status)
        assert_equal("expired after 4 hours", @asset.status_message)
      end
    end
  end
end

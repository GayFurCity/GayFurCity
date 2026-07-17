# frozen_string_literal: true

class UploadMediaAssetVideoVariantsJob < ApplicationJob
  queue_as(:variants)
  good_job_control_concurrency_with(total_limit: 1, key: -> { "UploadMediaAssetVideoVariantsJob-#{arguments[0]}" })
  retry_on(StandardError, attempts: 3)

  def perform(id)
    asset = UploadMediaAsset.find(id)
    raise(StandardError, "upload is still in progress") if asset.in_progress?
    asset.open_file do |file|
      UploadMediaAssetVariantsJob.generate_videos(file, asset)
    end
  end
end

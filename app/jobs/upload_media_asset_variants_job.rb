# frozen_string_literal: true

class UploadMediaAssetVariantsJob < ApplicationJob
  queue_as(:variants)
  sidekiq_options(lock: :until_executed, lock_args_method: :lock_args, retry: 3)

  def self.lock_args(args)
    [args[0]]
  end

  def perform(id)
    asset = UploadMediaAsset.find(id)
    raise(StandardError, "upload is still in progress") if asset.in_progress?
    asset.open_file do |file|
      # image samples are more important, since otherwise posts would not have thumbnails,
      # thus they are done first and added to the asset before proceeding
      UploadMediaAssetVariantsJob.generate_images(file, asset)
      UploadMediaAssetVariantsJob.generate_videos(file, asset)
    end
  end

  def self.generate_images(file, asset)
    asset.regenerate_image_variants!(file)
    data = asset.variants_data.select { |v| v["video"] } + asset.image_variants.without(asset.original).map(&:serializable_hash)
    names = data.pluck("type")
    asset.update!(variants_data: data.uniq { |d| [d["type"], d["ext"]] }, generated_variants: names.uniq)
  end

  def self.generate_videos(file, asset)
    asset.regenerate_video_variants!(file)
    data = asset.variants_data.reject { |v| v["video"] } + asset.video_variants.without(asset.original).map(&:serializable_hash)
    names = data.pluck("type")
    asset.update!(variants_data: data.uniq { |d| [d["type"], d["ext"]] }, generated_variants: names.uniq)
  end
end

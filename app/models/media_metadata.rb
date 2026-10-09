# frozen_string_literal: true

class MediaMetadata < ApplicationRecord
  has_one(:upload_media_asset)
  has_one(:post_replacement_media_asset)
  has_one(:mascot_media_asset)
  has_one(:site_media_asset)
  has_one(:domain_icon_media_asset)

  %w[width height sar bitrate duration container colorspace frame_rate video_codec].each do |field|
    define_method(field) do
      metadata.try(:[], field)
    end
  end

  def audio_codec
    metadata.try(:[], "audio_streams").try(:first).try(:[], "codec_name")
  end
end

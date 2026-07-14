# frozen_string_literal: true

require("test_helper")

class MediaMetadataTest < ActiveSupport::TestCase
  context("audio_codec") do
    should("return the first audio stream's codec when present") do
      metadata = MediaMetadata.new(metadata: { "audio_streams" => [{ "codec_name" => "aac" }] })

      assert_equal("aac", metadata.audio_codec)
    end

    should("be nil when there are no audio streams") do
      metadata = MediaMetadata.new(metadata: { "audio_streams" => [] })

      assert_nil(metadata.audio_codec)
    end

    should("be nil when the metadata has no audio_streams key at all") do
      metadata = MediaMetadata.new(metadata: {})

      assert_nil(metadata.audio_codec)
    end
  end
end

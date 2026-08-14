# frozen_string_literal: true

require("test_helper")

class FileMethodsTest < ActiveSupport::TestCase
  setup do
    @jpg = file_fixture("test.jpg").to_s
    @png = file_fixture("test.png").to_s
    @apng = file_fixture("apng/normal_apng.png").to_s
    @webp = file_fixture("test.webp").to_s
    @gif = file_fixture("test.gif").to_s
    @tiff = file_fixture("test.tiff").to_s # used for invalid inputs
    @empty = Tempfile.new.path # used for empty inputs
    @mp4 = file_fixture("test-300x300.mp4").to_s
    @mp4_with_audio = file_fixture("test-300x300-with-audio.mp4").to_s
    @webm = file_fixture("test-512x512.webm").to_s
    @webm_with_audio = file_fixture("test-512x512-with-audio.webm").to_s
    @anamorphic = file_fixture("test-anamorphic.webm").to_s
    @ai_generator = file_fixture("ai/generator.png").to_s
    @ai_tokens = file_fixture("ai/tokens.png").to_s
    @obj = BasicObject.include(FileMethods)
  end

  def assert_metadata(type, file, field, expected)
    data = @obj.public_send("#{type}_metadata", file)

    assert(data.key?(field.to_sym))
    if expected.nil?
      assert_nil(data[field.to_sym])
    else
      assert_equal(expected, data[field.to_sym])
    end
  end

  def assert_not_metadata(type, file, field, allow_nil: false, allow_none: true)
    data = @obj.public_send("#{type}_metadata", file)
    if data.blank?
      assert(allow_none, "expected #{type}_metadata to return data, but got none")
      return
    end
    assert_not(data.key?(field.to_sym)) unless allow_nil

    assert_nil(data[field.to_sym])
  end

  context("file_header_to_file_ext") do
    should("work") do
      assert_equal("jpg", @obj.file_header_to_file_ext(@jpg))
      assert_equal("png", @obj.file_header_to_file_ext(@png))
      assert_equal("png", @obj.file_header_to_file_ext(@apng))
      assert_equal("webp", @obj.file_header_to_file_ext(@webp))
      assert_equal("gif", @obj.file_header_to_file_ext(@gif))
      assert_equal("mp4", @obj.file_header_to_file_ext(@mp4))
      assert_equal("webm", @obj.file_header_to_file_ext(@webm))
    end

    should("return the mime type if the file extension is not specified") do
      assert_equal("image/tiff", @obj.file_header_to_file_ext(@tiff))
      assert_equal("application/octet-stream", @obj.file_header_to_file_ext(@empty))
    end
  end

  context("video") do
    should("work for videos") do
      assert_instance_of(FFMPEG::Movie, @obj.video(@mp4))
      assert_instance_of(FFMPEG::Movie, @obj.video(@webm))
    end

    should("not work for images") do
      assert_nil(@obj.video(@jpg))
      assert_nil(@obj.video(@png))
      assert_nil(@obj.video(@apng))
      assert_nil(@obj.video(@webp))
      assert_nil(@obj.video(@gif))
    end

    should("not work for invalid files") do
      assert_nil(@obj.video(@tiff))
      assert_nil(@obj.video(@empty))
    end
  end

  context("image") do
    should("work for images") do
      assert_instance_of(Vips::Image, @obj.image(@jpg))
      assert_instance_of(Vips::Image, @obj.image(@png))
      assert_instance_of(Vips::Image, @obj.image(@apng))
      assert_instance_of(Vips::Image, @obj.image(@webp))
      assert_instance_of(Vips::Image, @obj.image(@gif))
    end

    should("not work for videos") do
      assert_nil(@obj.image(@mp4))
      assert_nil(@obj.image(@webm))
    end

    should("not work for invalid files") do
      assert_nil(@obj.image(@tiff))
      assert_nil(@obj.image(@empty))
    end
  end

  context("calculate_dimensions") do
    should("work") do
      assert_equal([500, 335], @obj.calculate_dimensions(@jpg))
      assert_equal([768, 1024], @obj.calculate_dimensions(@png))
      assert_equal([150, 150], @obj.calculate_dimensions(@apng))
      assert_equal([386, 395], @obj.calculate_dimensions(@webp))
      assert_equal([1000, 685], @obj.calculate_dimensions(@gif))
      assert_equal([300, 300], @obj.calculate_dimensions(@mp4))
      assert_equal([512, 512], @obj.calculate_dimensions(@webm))
    end

    should("not work for invalid files") do
      assert_equal([0, 0], @obj.calculate_dimensions(@tiff))
      assert_equal([0, 0], @obj.calculate_dimensions(@empty))
    end
  end

  context("image_metadata") do
    context("width") do
      should("work for images") do
        assert_metadata(:image, @jpg, :width, 500)
        assert_metadata(:image, @png, :width, 768)
        assert_metadata(:image, @apng, :width, 150)
        assert_metadata(:image, @webp, :width, 386)
        assert_metadata(:image, @gif, :width, 1000)
      end

      should("not work for videos") do
        assert_not_metadata(:image, @mp4, :width)
        assert_not_metadata(:image, @webm, :width)
      end

      should("not work for invalid files") do
        assert_not_metadata(:image, @tiff, :width)
        assert_not_metadata(:image, @empty, :width)
      end
    end

    context("height") do
      should("work for images") do
        assert_metadata(:image, @jpg, :height, 335)
        assert_metadata(:image, @png, :height, 1024)
        assert_metadata(:image, @apng, :height, 150)
        assert_metadata(:image, @webp, :height, 395)
        assert_metadata(:image, @gif, :height, 685)
      end

      should("not work for videos") do
        assert_not_metadata(:image, @mp4, :height)
        assert_not_metadata(:image, @webm, :height)
      end

      should("not work for invalid files") do
        assert_not_metadata(:image, @tiff, :height)
        assert_not_metadata(:image, @empty, :height)
      end
    end
  end

  context("video_metadata") do
    context("width") do
      should("work for videos") do
        assert_metadata(:video, @mp4, :width, 300)
        assert_metadata(:video, @webm, :width, 512)
      end

      should("not work for images") do
        assert_not_metadata(:video, @jpg, :width)
        assert_not_metadata(:video, @png, :width)
        assert_not_metadata(:video, @apng, :width)
        assert_not_metadata(:video, @webp, :width)
        assert_not_metadata(:video, @gif, :width)
      end

      should("not work for invalid files") do
        assert_not_metadata(:video, @tiff, :width)
        assert_not_metadata(:video, @empty, :width)
      end
    end

    context("height") do
      should("work for videos") do
        assert_metadata(:video, @mp4, :height, 300)
        assert_metadata(:video, @webm, :height, 512)
      end

      should("not work for images") do
        assert_not_metadata(:video, @jpg, :height)
        assert_not_metadata(:video, @png, :height)
        assert_not_metadata(:video, @apng, :height)
        assert_not_metadata(:video, @webp, :height)
        assert_not_metadata(:video, @gif, :height)
      end

      should("not work for invalid files") do
        assert_not_metadata(:video, @tiff, :height)
        assert_not_metadata(:video, @empty, :height)
      end
    end

    context("container") do
      should("work for videos") do
        assert_metadata(:video, @mp4, :container, "mov,mp4,m4a,3gp,3g2,mj2")
        assert_metadata(:video, @webm, :container, "matroska,webm")
      end

      should("not work for images") do
        assert_not_metadata(:video, @jpg, :container)
        assert_not_metadata(:video, @png, :container)
        assert_not_metadata(:video, @apng, :container)
        assert_not_metadata(:video, @webp, :container)
        assert_not_metadata(:video, @gif, :container)
      end

      should("not work for invalid files") do
        assert_not_metadata(:video, @tiff, :container)
        assert_not_metadata(:video, @empty, :container)
      end
    end

    context("duration") do
      should("work for videos") do
        assert_metadata(:video, @mp4, :duration, 5.7)
        assert_metadata(:video, @webm, :duration, 0.48)
      end

      should("not work for images") do
        assert_not_metadata(:video, @jpg, :duration)
        assert_not_metadata(:video, @png, :duration)
        assert_not_metadata(:video, @apng, :duration)
        assert_not_metadata(:video, @webp, :duration)
        assert_not_metadata(:video, @gif, :duration)
      end

      should("not work for invalid files") do
        assert_not_metadata(:video, @tiff, :duration)
        assert_not_metadata(:video, @empty, :duration)
      end
    end

    context("frame_rate") do
      should("work for videos") do
        assert_metadata(:video, @mp4, :frame_rate, 1.7543859649122806)
        assert_metadata(:video, @webm, :frame_rate, 50.0)
      end

      should("not work for images") do
        assert_not_metadata(:video, @jpg, :frame_rate)
        assert_not_metadata(:video, @png, :frame_rate)
        assert_not_metadata(:video, @apng, :frame_rate)
        assert_not_metadata(:video, @webp, :frame_rate)
        assert_not_metadata(:video, @gif, :frame_rate)
      end

      should("not work for invalid files") do
        assert_not_metadata(:video, @tiff, :frame_rate)
        assert_not_metadata(:video, @empty, :frame_rate)
      end
    end

    context("video_codec") do
      should("work for videos") do
        assert_metadata(:video, @mp4, :video_codec, "h264")
        assert_metadata(:video, @webm, :video_codec, "vp8")
      end

      should("not work for images") do
        assert_not_metadata(:video, @jpg, :video_codec)
        assert_not_metadata(:video, @png, :video_codec)
        assert_not_metadata(:video, @apng, :video_codec)
        assert_not_metadata(:video, @webp, :video_codec)
        assert_not_metadata(:video, @gif, :video_codec)
      end

      should("not work for invalid files") do
        assert_not_metadata(:video, @tiff, :video_codec)
        assert_not_metadata(:video, @empty, :video_codec)
      end
    end

    context("colorspace") do
      should("work for videos") do
        assert_metadata(:video, @mp4, :colorspace, "yuv420p")
        assert_metadata(:video, @webm, :colorspace, "yuv420p")
      end

      should("not work for images") do
        assert_not_metadata(:video, @jpg, :colorspace)
        assert_not_metadata(:video, @png, :colorspace)
        assert_not_metadata(:video, @apng, :colorspace)
        assert_not_metadata(:video, @webp, :colorspace)
        assert_not_metadata(:video, @gif, :colorspace)
      end

      should("not work for invalid files") do
        assert_not_metadata(:video, @tiff, :colorspace)
        assert_not_metadata(:video, @empty, :colorspace)
      end
    end

    context("bitrate") do
      should("work for videos") do
        assert_metadata(:video, @mp4, :bitrate, 26_213)
        assert_metadata(:video, @webm, :bitrate, 205_750)
      end

      should("not work for images") do
        assert_not_metadata(:video, @jpg, :bitrate)
        assert_not_metadata(:video, @png, :bitrate)
        assert_not_metadata(:video, @apng, :bitrate)
        assert_not_metadata(:video, @webp, :bitrate)
        assert_not_metadata(:video, @gif, :bitrate)
      end

      should("not work for invalid files") do
        assert_not_metadata(:video, @tiff, :bitrate)
        assert_not_metadata(:video, @empty, :bitrate)
      end
    end

    context("sar") do
      should("work for videos") do
        assert_metadata(:video, @mp4, :sar, nil)
        assert_metadata(:video, @webm, :sar, "1:1")
        assert_metadata(:video, @anamorphic, :sar, "2:1")
      end

      should("not work for images") do
        assert_not_metadata(:video, @jpg, :sar)
        assert_not_metadata(:video, @png, :sar)
        assert_not_metadata(:video, @apng, :sar)
        assert_not_metadata(:video, @webp, :sar)
        assert_not_metadata(:video, @gif, :sar)
      end

      should("not work for invalid files") do
        assert_not_metadata(:video, @tiff, :sar)
        assert_not_metadata(:video, @empty, :sar)
      end
    end

    context("dar") do
      should("work for videos") do
        assert_metadata(:video, @mp4, :dar, nil)
        assert_metadata(:video, @webm, :dar, "1:1")
        assert_metadata(:video, @anamorphic, :dar, "8:3")
      end

      should("not work for images") do
        assert_not_metadata(:video, @jpg, :dar)
        assert_not_metadata(:video, @png, :dar)
        assert_not_metadata(:video, @apng, :dar)
        assert_not_metadata(:video, @webp, :dar)
        assert_not_metadata(:video, @gif, :dar)
      end

      should("not work for invalid files") do
        assert_not_metadata(:video, @tiff, :dar)
        assert_not_metadata(:video, @empty, :dar)
      end
    end

    context("audio_streams") do
      should("be empty for videos without an audio track") do
        assert_metadata(:video, @mp4, :audio_streams, [])
        assert_metadata(:video, @webm, :audio_streams, [])
      end

      should("work for videos with an audio track") do
        streams = @obj.video_metadata(@mp4_with_audio)[:audio_streams]

        assert_equal(1, streams.length)
        assert_equal("aac", streams[0][:codec_name])
        assert_equal(1, streams[0][:channels])
        assert_equal("mono", streams[0][:channel_layout])
        assert_equal(44_100, streams[0][:sample_rate])
      end

      should("work for webms with an audio track") do
        streams = @obj.video_metadata(@webm_with_audio)[:audio_streams]

        assert_equal(1, streams.length)
        assert_equal("opus", streams[0][:codec_name])
        assert_equal(1, streams[0][:channels])
        assert_equal("mono", streams[0][:channel_layout])
        assert_equal(48_000, streams[0][:sample_rate])
      end

      should("not work for images") do
        assert_not_metadata(:video, @jpg, :audio_streams)
        assert_not_metadata(:video, @png, :audio_streams)
        assert_not_metadata(:video, @apng, :audio_streams)
        assert_not_metadata(:video, @webp, :audio_streams)
        assert_not_metadata(:video, @gif, :audio_streams)
      end

      should("not work for invalid files") do
        assert_not_metadata(:video, @tiff, :audio_streams)
        assert_not_metadata(:video, @empty, :audio_streams)
      end
    end
  end

  context("gif_metadata") do
    context("width") do
      should("work for gifs") do
        assert_metadata(:gif, @gif, :width, 1000)
      end

      should("not work for videos") do
        assert_not_metadata(:gif, @mp4, :width)
        assert_not_metadata(:gif, @webm, :width)
      end

      should("not work for images") do
        assert_not_metadata(:gif, @jpg, :width)
        assert_not_metadata(:gif, @png, :width)
        assert_not_metadata(:gif, @apng, :width)
        assert_not_metadata(:gif, @webp, :width)
      end

      should("not work for invalid files") do
        assert_not_metadata(:gif, @tiff, :width)
        assert_not_metadata(:gif, @empty, :width)
      end
    end

    context("height") do
      should("work for gifs") do
        assert_metadata(:gif, @gif, :height, 685)
      end

      should("not work for videos") do
        assert_not_metadata(:gif, @mp4, :height)
        assert_not_metadata(:gif, @webm, :height)
      end

      should("not work for images") do
        assert_not_metadata(:gif, @jpg, :height)
        assert_not_metadata(:gif, @png, :height)
        assert_not_metadata(:gif, @apng, :height)
        assert_not_metadata(:gif, @webp, :height)
      end

      should("not work for invalid files") do
        assert_not_metadata(:gif, @tiff, :height)
        assert_not_metadata(:gif, @empty, :height)
      end
    end

    context("container") do
      should("work for gifs") do
        assert_metadata(:gif, @gif, :container, "gif")
      end

      should("not work for videos") do
        assert_not_metadata(:gif, @mp4, :container)
        assert_not_metadata(:gif, @webm, :container)
      end

      should("not work for images") do
        assert_not_metadata(:gif, @jpg, :container)
        assert_not_metadata(:gif, @png, :container)
        assert_not_metadata(:gif, @apng, :container)
        assert_not_metadata(:gif, @webp, :container)
      end

      should("not work for invalid files") do
        assert_not_metadata(:gif, @tiff, :container)
        assert_not_metadata(:gif, @empty, :container)
      end
    end

    context("duration") do
      should("work for gifs") do
        assert_metadata(:gif, @gif, :duration, 0.42)
      end

      should("not work for videos") do
        assert_not_metadata(:gif, @mp4, :duration)
        assert_not_metadata(:gif, @webm, :duration)
      end

      should("not work for images") do
        assert_not_metadata(:gif, @jpg, :duration)
        assert_not_metadata(:gif, @png, :duration)
        assert_not_metadata(:gif, @apng, :duration)
        assert_not_metadata(:gif, @webp, :duration)
      end

      should("not work for invalid files") do
        assert_not_metadata(:gif, @tiff, :duration)
        assert_not_metadata(:gif, @empty, :duration)
      end
    end

    context("frame_rate") do
      should("work for gifs") do
        assert_metadata(:gif, @gif, :frame_rate, 7.142857142857143)
      end

      should("not work for videos") do
        assert_not_metadata(:gif, @mp4, :frame_rate)
        assert_not_metadata(:gif, @webm, :frame_rate)
      end

      should("not work for images") do
        assert_not_metadata(:gif, @jpg, :frame_rate)
        assert_not_metadata(:gif, @png, :frame_rate)
        assert_not_metadata(:gif, @apng, :frame_rate)
        assert_not_metadata(:gif, @webp, :frame_rate)
      end

      should("not work for invalid files") do
        assert_not_metadata(:gif, @tiff, :frame_rate)
        assert_not_metadata(:gif, @empty, :frame_rate)
      end
    end

    context("video_codec") do
      should("work for gifs") do
        assert_metadata(:gif, @gif, :video_codec, "gif")
      end

      should("not work for videos") do
        assert_not_metadata(:gif, @mp4, :video_codec)
        assert_not_metadata(:gif, @webm, :video_codec)
      end

      should("not work for images") do
        assert_not_metadata(:gif, @jpg, :video_codec)
        assert_not_metadata(:gif, @png, :video_codec)
        assert_not_metadata(:gif, @apng, :video_codec)
        assert_not_metadata(:gif, @webp, :video_codec)
      end

      should("not work for invalid files") do
        assert_not_metadata(:gif, @tiff, :video_codec)
        assert_not_metadata(:gif, @empty, :video_codec)
      end
    end

    context("colorspace") do
      should("work for gifs") do
        assert_metadata(:gif, @gif, :colorspace, "bgra")
      end

      should("not work for videos") do
        assert_not_metadata(:gif, @mp4, :colorspace)
        assert_not_metadata(:gif, @webm, :colorspace)
      end

      should("not work for images") do
        assert_not_metadata(:gif, @jpg, :colorspace)
        assert_not_metadata(:gif, @png, :colorspace)
        assert_not_metadata(:gif, @apng, :colorspace)
        assert_not_metadata(:gif, @webp, :colorspace)
      end

      should("not work for invalid files") do
        assert_not_metadata(:gif, @tiff, :colorspace)
        assert_not_metadata(:gif, @empty, :colorspace)
      end
    end

    context("bitrate") do
      should("work for gifs") do
        assert_metadata(:gif, @gif, :bitrate, 3_878_400)
      end

      should("not work for videos") do
        assert_not_metadata(:gif, @mp4, :bitrate)
        assert_not_metadata(:gif, @webm, :bitrate)
      end

      should("not work for images") do
        assert_not_metadata(:gif, @jpg, :bitrate)
        assert_not_metadata(:gif, @png, :bitrate)
        assert_not_metadata(:gif, @apng, :bitrate)
        assert_not_metadata(:gif, @webp, :bitrate)
      end

      should("not work for invalid files") do
        assert_not_metadata(:gif, @tiff, :bitrate)
        assert_not_metadata(:gif, @empty, :bitrate)
      end
    end
  end

  context("is_image?") do
    should("return true for images") do
      assert(@obj.is_image?("jpg"))
      assert(@obj.is_image?("png"))
      assert(@obj.is_image?("png")) # apng has the same extension
      assert(@obj.is_image?("webp"))
      assert(@obj.is_image?("gif"))
    end

    should("return false for videos") do
      assert_not(@obj.is_image?("mp4"))
      assert_not(@obj.is_image?("webm"))
    end

    should("return false for invalid files") do
      assert_not(@obj.is_image?("image/tiff"))
      assert_not(@obj.is_image?("application/octet-stream"))
    end
  end

  context("is_file_image?") do
    should("return true for images") do
      assert(@obj.is_file_image?(@jpg))
      assert(@obj.is_file_image?(@png))
      assert(@obj.is_file_image?(@apng))
      assert(@obj.is_file_image?(@webp))
      assert(@obj.is_file_image?(@gif))
    end

    should("return false for videos") do
      assert_not(@obj.is_file_image?(@mp4))
      assert_not(@obj.is_file_image?(@webm))
    end

    should("return false for invalid files") do
      assert_not(@obj.is_file_image?(@tiff))
      assert_not(@obj.is_file_image?(@empty))
    end
  end

  context("is_gif?") do
    should("return true for gifs") do
      assert(@obj.is_gif?("gif"))
    end

    should("return false for images") do
      assert_not(@obj.is_gif?("jpg"))
      assert_not(@obj.is_gif?("png"))
      assert_not(@obj.is_gif?("png")) # apng has the same extension
      assert_not(@obj.is_gif?("webp"))
    end

    should("return false for videos") do
      assert_not(@obj.is_gif?("mp4"))
      assert_not(@obj.is_gif?("webm"))
    end

    should("return false for invalid files") do
      assert_not(@obj.is_gif?("image/tiff"))
      assert_not(@obj.is_gif?("application/octet-stream"))
    end
  end

  context("is_file_gif?") do
    should("return true for gifs") do
      assert(@obj.is_file_gif?(@gif))
    end

    should("return false for images") do
      assert_not(@obj.is_file_gif?(@jpg))
      assert_not(@obj.is_file_gif?(@png))
      assert_not(@obj.is_file_gif?(@apng))
      assert_not(@obj.is_file_gif?(@webp))
    end

    should("return false for videos") do
      assert_not(@obj.is_file_gif?(@mp4))
      assert_not(@obj.is_file_gif?(@webm))
    end

    should("return false for invalid files") do
      assert_not(@obj.is_file_gif?(@tiff))
      assert_not(@obj.is_file_gif?(@empty))
    end
  end

  context("is_video?") do
    should("return true for videos") do
      assert(@obj.is_video?("mp4"))
      assert(@obj.is_video?("webm"))
    end

    should("return false for images") do
      assert_not(@obj.is_video?("jpg"))
      assert_not(@obj.is_video?("png"))
      assert_not(@obj.is_video?("png")) # apng has the same extension
      assert_not(@obj.is_video?("webp"))
      assert_not(@obj.is_video?("gif"))
    end

    should("return false for invalid files") do
      assert_not(@obj.is_video?("image/tiff"))
      assert_not(@obj.is_video?("application/octet-stream"))
    end
  end

  context("is_file_video?") do
    should("return true for videos") do
      assert(@obj.is_file_video?(@mp4))
      assert(@obj.is_file_video?(@webm))
    end

    should("return false for images") do
      assert_not(@obj.is_file_video?(@jpg))
      assert_not(@obj.is_file_video?(@png))
      assert_not(@obj.is_file_video?(@apng))
      assert_not(@obj.is_file_video?(@webp))
      assert_not(@obj.is_file_video?(@gif))
    end

    should("return false for invalid files") do
      assert_not(@obj.is_file_video?(@tiff))
      assert_not(@obj.is_file_video?(@empty))
    end
  end

  context("is_valid_extension?") do
    should("work") do
      assert(@obj.is_valid_extension?("jpg"))
      assert(@obj.is_valid_extension?("png"))
      assert_not(@obj.is_valid_extension?("apng")) # apng should be png
      assert(@obj.is_valid_extension?("webp"))
      assert(@obj.is_valid_extension?("gif"))
      assert(@obj.is_valid_extension?("mp4"))
      assert(@obj.is_valid_extension?("webm"))
    end

    should("not work for invalid files") do
      assert_not(@obj.is_valid_extension?("image/tiff"))
      assert_not(@obj.is_valid_extension?("application/octet-stream"))
    end
  end

  context("is_file_valid_extension?") do
    should("work") do
      assert(@obj.is_file_valid_extension?(@jpg))
      assert(@obj.is_file_valid_extension?(@png))
      assert(@obj.is_file_valid_extension?(@apng))
      assert(@obj.is_file_valid_extension?(@webp))
      assert(@obj.is_file_valid_extension?(@gif))
      assert(@obj.is_file_valid_extension?(@mp4))
      assert(@obj.is_file_valid_extension?(@webm))
    end

    should("not work for invalid files") do
      assert_not(@obj.is_file_valid_extension?(@tiff))
      assert_not(@obj.is_file_valid_extension?(@empty))
    end
  end

  context("is_animated_png?") do
    should("work") do
      assert(@obj.is_animated_png?(@apng))
    end

    should("not work for other files") do
      assert_not(@obj.is_animated_png?(@jpg))
      assert_not(@obj.is_animated_png?(@png))
      assert_not(@obj.is_animated_png?(@webp))
      assert_not(@obj.is_animated_png?(@gif))
      assert_not(@obj.is_animated_png?(@mp4))
      assert_not(@obj.is_animated_png?(@webm))
    end

    should("not work for invalid files") do
      assert_not(@obj.is_animated_png?(@tiff))
      assert_not(@obj.is_animated_png?(@empty))
    end
  end

  context("is_animated_gif?") do
    should("work") do
      assert(@obj.is_animated_gif?(@gif))
    end

    should("not work for other files") do
      assert_not(@obj.is_animated_gif?(@jpg))
      assert_not(@obj.is_animated_gif?(@png))
      assert_not(@obj.is_animated_gif?(@webp))
      assert_not(@obj.is_animated_gif?(@apng))
      assert_not(@obj.is_animated_gif?(@mp4))
      assert_not(@obj.is_animated_gif?(@webm))
    end

    should("not work for invalid files") do
      assert_not(@obj.is_animated_gif?(@tiff))
      assert_not(@obj.is_animated_gif?(@empty))
    end
  end

  context("is_corrupt?") do
    setup do
      @corrupted = file_fixture("test-corrupt.jpg")
    end

    should("work") do
      assert_not(@obj.is_corrupt?(@jpg))
      assert_not(@obj.is_corrupt?(@png))
      assert_not(@obj.is_corrupt?(@webp))
      assert_not(@obj.is_corrupt?(@gif))
      assert_not(@obj.is_corrupt?(@mp4))
      assert_not(@obj.is_corrupt?(@webm))
      assert(@obj.is_corrupt?(@tiff))
      assert(@obj.is_corrupt?(@empty))
      assert(@obj.is_corrupt?(@corrupted))
    end
  end

  context("is_ai_generated?") do
    should("work") do
      assert_equal(0, @obj.is_ai_generated?(@jpg)[:score])
      assert_equal(0, @obj.is_ai_generated?(@png)[:score])
      assert_equal(0, @obj.is_ai_generated?(@webp)[:score])
      assert_equal(0, @obj.is_ai_generated?(@gif)[:score])
      assert_equal(0, @obj.is_ai_generated?(@mp4)[:score])
      assert_equal(0, @obj.is_ai_generated?(@webm)[:score])
      assert_equal(0, @obj.is_ai_generated?(@tiff)[:score])
      assert_equal(0, @obj.is_ai_generated?(@empty)[:score])
      assert_operator(@obj.is_ai_generated?(@ai_generator)[:score], :>=, 70)
      assert_operator(@obj.is_ai_generated?(@ai_tokens)[:score], :>=, 60)
    end
  end

  context("pixel_hash") do
    should("work for images") do
      assert_equal("01cb481ec7730b7cfced57ffa5abd196", @obj.pixel_hash(@jpg))
      assert_equal("d351db38efb2697d355cf89853099539", @obj.pixel_hash(@png))
      assert_equal("39225408c7673a19a5c69f596c0d1032", @obj.pixel_hash(@webp))
      assert_equal("516e3ef761c48e70036fb7cba973bb99", @obj.pixel_hash(@gif))
    end

    should("not work for videos") do
      assert_nil(@obj.pixel_hash(@apng))
      assert_nil(@obj.pixel_hash(@mp4))
      assert_nil(@obj.pixel_hash(@webm))
    end

    should("not work for invalid files") do
      assert_nil(@obj.pixel_hash(@tiff))
      assert_nil(@obj.pixel_hash(@empty))
    end
  end

  context("md5") do
    should("work") do
      assert_equal("ecef68c44edb8a0d6a3070b5f8e8ee76", @obj.md5(@jpg))
      assert_equal("081a5c3b92d8980d1aadbd215bfac5b9", @obj.md5(@png))
      assert_equal("291654feb88606970e927f32b08e2621", @obj.md5(@webp))
      assert_equal("05f1c7a0466a4e6a2af1eef3387f4dbe", @obj.md5(@gif))
      assert_equal("df87217e2c181ae6674898dff27e5a56", @obj.md5(@tiff))
      assert_equal("d41d8cd98f00b204e9800998ecf8427e", @obj.md5(@empty))
      assert_equal("865c93102cad3e8a893d6aac6b51b0d2", @obj.md5(@mp4))
      assert_equal("34dd2489f7aaa9e57eda1b996ff26ff7", @obj.md5(@webm))
    end
  end
end

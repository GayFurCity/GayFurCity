# frozen_string_literal: true

module VideoResizer
  module_function

  def crop(file_path, width, height, frame: nil)
    video = FFMPEG::Movie.new(file_path)
    vp = Tempfile.new(%w[video-preview .webp], binmode: true)
    video.screenshot(vp.path, { resolution: "#{video.width}x#{video.height}", custom: (%W[-vf select=eq(n\\,#{frame - 1})] if frame.present? && frame != 0) })
    crop = ImageResizer.crop(vp, width, height, 87)
    vp.close(unlink: true)
    crop
  end

  def extract_frame(file_path, frame)
    output_file = Tempfile.new(%w[video-preview .webp], binmode: true)
    stdout, stderr, status = Open3.capture3(GayFurCity.config.ffmpeg_path, "-y", "-i", file_path, "-vf", "select=eq(n\\,#{frame - 1})", "-frames:v", "1", output_file.path)

    unless status == 0
      Rails.logger.warn("[FFMPEG FRAME STDOUT] #{stdout.chomp!}")
      Rails.logger.warn("[FFMPEG FRAME STDERR] #{stderr.chomp!}")
      raise(StandardError, "could not extract frame")
    end
    output_file
  end

  def sample(file_path, width: nil, height: nil, frame: nil)
    output_file = Tempfile.new(%w[video-preview .webp], binmode: true)
    if frame.blank? || frame == 0
      opt = %w[-vf thumbnail]
    else
      opt = %W[-vf select=eq(n\\,#{frame - 1})]
    end
    if width
      o = opt.pop
      if height
        opt.push("#{o},scale=w=#{width}:h=#{height}")
      else
        opt.push("#{o},scale=#{width}:-1")
      end
    elsif height
      o = opt.pop
      opt.push("#{o},scale=-1:#{height}")
    end
    stdout, stderr, status = Open3.capture3(GayFurCity.config.ffmpeg_path, "-y", "-i", file_path, *opt, "-frames:v", "1", output_file.path)

    unless status == 0
      Rails.logger.warn("[FFMPEG SAMPLE STDOUT] #{stdout.chomp!}")
      Rails.logger.warn("[FFMPEG SAMPLE STDERR] #{stderr.chomp!}")
      raise(StandardError, "could not generate sample")
    end
    output_file
  end
end

# frozen_string_literal: true

module FileMethods
  extend(ActiveSupport::Concern)

  VIDEO_EXTENSIONS = %w[webm mp4].freeze
  IMAGE_EXTENSIONS = %w[png jpg gif webp].freeze
  GIF_EXTENSIONS = %w[gif].freeze
  EXTENSIONS = (IMAGE_EXTENSIONS + VIDEO_EXTENSIONS + GIF_EXTENSIONS).uniq.freeze

  module ClassMethods
    include(AiMethods)

    def file_header_to_file_ext(file_path)
      File.open(file_path) do |bin|
        mime_type = Marcel::MimeType.for(bin)
        case mime_type
        when "image/jpeg"
          "jpg"
        when "image/gif"
          "gif"
        when "image/png"
          "png"
        when "image/webp"
          "webp"
        when "video/webm"
          "webm"
        when "video/mp4"
          "mp4"
        else
          mime_type
        end
      end
    end

    EXTENSIONS.each do |ext|
      define_method("is_#{ext}?") { |file_ext| file_ext == ext }
      define_method("is_file_#{ext}?") { |file_path| send("is_#{ext}?", file_header_to_file_ext(file_path)) }
    end

    def video(file_path, ...)
      return unless is_file_video?(file_path)
      FFMPEG::Movie.new(file_path, ...)
    end

    def video_metadata(file_path)
      video = self.video(file_path)
      hash = {}
      return hash if video.nil?
      %i[container duration time format_tags creation_time bitrate video_codec colorspace width height video_bitrate sar dar rotation].each do |p|
        hash[p] = video.public_send(p)
      end
      hash[:frame_rate] = video.frame_rate.to_f # because it's a Rational for some reason
      hash[:overview] = video.video_stream
      hash[:raw] = video.metadata
      hash[:exif] = exif(file_path)

      hash[:audio_streams] = []
      video.audio_streams.each do |audio|
        audhash = {}
        %i[index channels codec_name sample_rate bitrate channel_layout tags overview].each do |p|
          audhash[p] = audio.public_send(:[], p)
        end
        hash[:audio_streams].push(audhash)
      end

      hash
    end

    def gif(file_path, ...)
      return unless is_file_gif?(file_path)
      FFMPEG::Movie.new(file_path, ...)
    end

    def gif_metadata(file_path)
      gif = self.gif(file_path)
      hash = {}
      return hash if gif.nil?
      %i[container duration time format_tags creation_time bitrate video_codec colorspace width height video_bitrate sar dar rotation].each do |p|
        hash[p] = gif.public_send(p)
      end
      hash[:frame_rate] = gif.frame_rate.to_f # because it's a Rational for some reason
      hash[:overview] = gif.video_stream
      hash[:raw] = gif.metadata
      hash[:exif] = exif(file_path)
      hash
    end

    def webp_metadata(file_path)
      stdout, stderr, status = Open3.capture3("webpmux", "-info", file_path.to_s)
      hash = {
        width:      0,
        height:     0,
        features:   [],
        bgcolor:    "00000000",
        framecount: 0,
        loopcount:  nil,
        frames:     [],
        exif_size:  0,
        duration:   0.0,
        frame_rate: 0.0,
      }
      unless status.success?
        ExceptionLog.add!(StandardError.new("webp metadata failed: #{file_path}"), source: "FileMethods#webp_metadata", stdout: stdout, stderr: stderr)
        return hash
      end

      lines = stdout.lines.map(&:strip)
      headers = []
      lines.each do |line|
        case line
        when /\ACanvas size:\s*(\d+)\s*x\s*(\d+)\s*\z/i
          hash[:width] = $1.to_i
          hash[:height] = $2.to_i
        when /\AFeatures present:\s*(.*)\s*\z/i
          hash[:features] = $1.split
        when /\ABackground color\s*:\s*0x([\dA-F]+)\s*Loop Count\s*:\s*(\d+)\s*/i
          hash[:bgcolor] = $1.rjust(8, "0").upcase
          hash[:loopcount] = $1.to_i
        when /\ANumber of frames\s*:\s*(\d+)\s*\z/i
          hash[:framecount] = $1.to_i
        when /^No\.\s*:\s*(.+)$/i
          headers = $1.split(/\s+/).map { |h| h.downcase.to_sym }
        when /\A\s*(\d+):\s*(.*)\z/
          next if headers.empty?
          h = { index: $1.to_i }
          parts = $2.split(/\s+/)
          parts.each_with_index do |part, idx|
            name = headers[idx]
            next if name.nil?
            value = case part
                    when "yes" then true
                    when "no"  then false
                    when /\A\d+\z/ then part.to_i
                    else part
                    end
            h[name] = value
          end
          hash[:frames] << h
        when /\ASize of the EXIF metadata\s*:\s*(\d+)\s*\z/
          hash[:exif_size] = $1.to_i
        end
      end

      hash[:frames].compact!
      unless hash[:frames].empty?
        hash[:duration] = hash[:frames].sum { |f| f[:duration].to_i } / 1000.0
        hash[:frame_rate] = hash[:framecount] / hash[:duration]
      end

      hash[:exif] = exif(file_path)

      hash
    end

    def image(file_path, ...)
      return unless is_file_image?(file_path)
      Vips::Image.new_from_file(file_path, ...)
    end

    def image_metadata(file_path, ...)
      image = self.image(file_path, ...)
      hash = {}
      return hash if image.nil?
      %w[width height bands format coding interpretation xoffset yoffset xres yres resolution-unit bits-per-sample].each do |field|
        hash[field.to_sym] = image.get(field)
      rescue Vips::Error
        # Ignored
      end
      hash[:exif] = exif(file_path)
      hash
    end

    def calculate_dimensions(file_path)
      if (is_file_gif?(file_path) && (data = gif_metadata(file_path))) ||
         (is_file_webp?(file_path) && (data = webp_metadata(file_path))) ||
         (is_file_image?(file_path) && (data = image_metadata(file_path))) ||
         (is_file_video?(file_path) && (data = video_metadata(file_path)))
        [data[:width], data[:height]]
      else
        [0, 0]
      end
    end

    def is_image?(file_ext)
      IMAGE_EXTENSIONS.include?(file_ext)
    end

    def is_file_image?(file_path)
      is_image?(file_header_to_file_ext(file_path))
    end

    def is_gif?(file_ext)
      GIF_EXTENSIONS.include?(file_ext)
    end

    def is_file_gif?(file_path)
      is_gif?(file_header_to_file_ext(file_path))
    end

    def is_video?(file_ext)
      VIDEO_EXTENSIONS.include?(file_ext)
    end

    def is_file_video?(file_path)
      is_video?(file_header_to_file_ext(file_path))
    end

    def is_valid_extension?(file_ext)
      EXTENSIONS.include?(file_ext)
    end

    def is_file_valid_extension?(file_path)
      is_valid_extension?(file_header_to_file_ext(file_path))
    end

    def is_animated_png?(file_path)
      return false unless is_file_png?(file_path)
      ApngInspector.new(file_path).inspect!.animated?
    end

    def is_animated_gif?(file_path)
      return false unless is_file_gif?(file_path)

      # Check whether the gif has multiple frames by trying to load the second frame.
      result = begin
        Vips::Image.gifload(file_path, page: 1)
      rescue StandardError
        $ERROR_INFO
      end
      if result.is_a?(Vips::Image)
        true
      elsif result.is_a?(Vips::Error) && result.message =~ /bad page number/
        false
      else
        raise(result)
      end
    end

    # Fast-ish approach: scans the file header for animation markers (ANIM/ANMF).
    # See: https://developers.google.com/speed/webp/docs/riff_container#extended
    def is_animated_webp?(file_path)
      return false unless is_file_webp?(file_path)

      File.open(file_path, "rb") do |f|
        header = f.read(12)
        # Expect: 'RIFF' <size:LE32> 'WEBP'
        return false unless header && header.bytesize == 12
        return false unless header[0, 4] == "RIFF" && header[8, 4] == "WEBP"

        # Iterate over chunks: <FourCC:4><Size:LE32><Payload...> (padded to even length)
        loop do
          chunk_header = f.read(8)
          break false unless chunk_header && chunk_header.bytesize == 8

          # ANIM = animation header, ANMF = animation frame
          return true if %w[ANIM ANMF].include?(chunk_header[0, 4])

          # Skip payload (+ padding byte if size is odd)
          chunk_size = chunk_header[4, 4].unpack1("V") # Little-endian uint32
          skip = chunk_size + (chunk_size.odd? ? 1 : 0)
          f.seek(skip, IO::SEEK_CUR)
        end
      end
    rescue StandardError
      false
    end

    def is_corrupt?(file_path)
      return false if is_file_video?(file_path)
      image = self.image(file_path, fail: true)
      image.stats
      false
    rescue StandardError
      true
    end

    def pixel_hash(file_path)
      return unless is_file_image?(file_path) && !is_animated_png?(file_path)
      image = self.image(file_path)
      image = image.icc_transform("srgb") if image.get_typeof("icc-profile-data") != 0
      image = image.colourspace("srgb") if image.interpretation != :srgb
      image = image.add_alpha unless image.has_alpha?

      # PAM file format: https://netpbm.sourceforge.net/doc/pam.html
      output = Tempfile.new(%W[pixel-hash-#{SecureRandom.hex(4)}- .pam], binmode: true)
      output.puts("P7")
      output.puts("WIDTH #{image.width}")
      output.puts("HEIGHT #{image.height}")
      output.puts("DEPTH #{image.bands}")
      output.puts("MAXVAL 255")
      output.puts("TUPLTYPE RGB_ALPHA")
      output.puts("ENDHDR")
      output.flush
      output.write(image.rawsave_buffer)
      output.flush
      hash = md5(output.path)
      output.close!
      hash
    end

    def md5(file_path)
      Digest::MD5.file(file_path).hexdigest
    end

    def exif(file_path)
      stdout, stderr, status = Open3.capture3("exiftool", "-json", "--File:all", "--ExifTool:all", file_path)
      unless status.success?
        ExceptionLog.add!(StandardError.new("exif failed: #{file_path}"), source: "FileMethods#exif", stdout: stdout, stderr: stderr)
        return {}
      end
      result = JSON.parse(stdout).first
      result.delete("SourceFile")
      result
    end
  end

  included do
    def get_file(&)
      if block_given?
        return yield(Tempfile.new(binmode: true)) if respond_to?(:skip_files) && skip_files # used in tests
        return yield(file) if file
        open_file(&)
      else
        return Tempfile.new(binmode: true) if respond_to?(:skip_files) && skip_files # used in tests
        return file if file
        open_file
      end
    end

    EXTENSIONS.each do |ext|
      define_method("is_#{ext}?") { file_ext == ext }
      define_method("is_file_#{ext}?") { get_file { |file| self.class.send("is_file_#{ext}?", file.path) } }
    end

    def video(&)
      if block_given?
        get_file { |file| yield(self.class.video(file.path)) }
        return
      end
      self.class.video(get_file.path)
    end

    def video_metadata(&)
      if block_given?
        get_file { |file| yield(self.class.video_metadata(file.path)) }
      end
      self.class.video_metadata(get_file.path)
    end

    def gif(&)
      if block_given?
        get_file { |file| yield(self.class.gif(file.path)) }
        return
      end
      self.class.gif(get_file.path)
    end

    def gif_metadata(&)
      if block_given?
        get_file { |file| yield(self.class.gif_metadata(file.path)) }
      end
      self.class.gif_metadata(get_file.path)
    end

    def webp_metadata(&)
      if block_given?
        get_file { |file| yield(self.class.webp_metadata(file.path)) }
      end
      self.class.webp_metadata(get_file.path)
    end

    def image(&)
      if block_given?
        get_file { |file| yield(self.class.image(file.path)) }
        return
      end
      self.class.image(get_file.path)
    end

    def image_metadata(&)
      if block_given?
        get_file { |file| yield(self.class.image_metadata(file.path)) }
      end
      self.class.image_metadata(get_file.path)
    end

    def calculate_dimensions
      get_file { |file| self.class.calculate_dimensions(file.path) }
    end

    def is_image?
      self.class.is_image?(file_ext)
    end

    def is_file_image?
      get_file { |file| self.class.is_file_image?(file.path) }
    end

    def is_video?
      self.class.is_video?(file_ext)
    end

    def is_file_video?
      get_file { |file| self.class.is_file_video?(file.path) }
    end

    # def is_animated_png?
    #   is_png? && get_file { |file| self.class.is_animated_png?(file.path) }
    # rescue Errno::ENOENT
    #   false
    # end

    # def is_animated_gif?
    #   is_gif? && get_file { |file| self.class.is_animated_gif?(file.path) }
    # rescue Errno::ENOENT
    #   false
    # end

    def is_corrupt?
      get_file { |file| self.class.is_corrupt?(file.path) }
    end

    def is_ai_generated?
      get_file { |file| self.class.is_ai_generated?(file.path) }
    end

    def file_pixel_hash
      return unless is_image? && !is_animated_png?
      get_file { |file| self.class.pixel_hash(file.path) }
    end

    def file_md5
      get_file { |file| self.class.md5(file.path) }
    end
  end
end

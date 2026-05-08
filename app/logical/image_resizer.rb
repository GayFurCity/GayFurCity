# frozen_string_literal: true

module ImageResizer
  module_function

  # https://www.libvips.org/API/current/libvips-resample.html#vips-thumbnail
  THUMBNAIL_OPTIONS = { size: :down, linear: false, no_rotate: true, export_profile: "srgb", import_profile: "srgb" }.freeze
  # https://www.libvips.org/API/current/VipsForeignSave.html#vips-webpsave
  WEBP_OPTIONS = { strip: true }.freeze
  CROP_OPTIONS = { linear: false, no_rotate: true, export_profile: "srgb", import_profile: "srgb", crop: :attention }.freeze

  def resize(file, width, height, resize_quality = 90)
    options = WEBP_OPTIONS.merge(Q: resize_quality)
    output_file = Tempfile.new(%w[image-sample .webp], binmode: true)
    resized_image = thumbnail(file, width, height, THUMBNAIL_OPTIONS)
    resized_image.webpsave(output_file.path, **options)

    output_file
  end

  def crop(file, width, height, resize_quality = 90)
    return nil unless Config.instance.enable_image_cropping?
    options = WEBP_OPTIONS.merge(Q: resize_quality)
    output_file = Tempfile.new(%w[image-crop .webp], binmode: true)
    resized_image = thumbnail(file, width, height, CROP_OPTIONS)
    resized_image.webpsave(output_file.path, **options)

    output_file
  end

  # https://github.com/libvips/libvips/wiki/HOWTO----Image-shrinking
  # https://www.libvips.org/API/current/Using-vipsthumbnail.md.html
  def thumbnail(file, width, height, options)
    Vips::Image.thumbnail(file.path, width, height: height, **options)
  rescue Vips::Error => e
    raise(e) unless e.message =~ /icc_transform/i
    Vips::Image.thumbnail(file.path, width, height: height, **options.except(:import_profile))
  end

  def replacement_thumbnail(file, type, frame: nil)
    if type == :video
      preview_file = VideoResizer.sample(file.path, width: GayFurCity.config.replacement_thumbnail_width, frame: frame)
    elsif type == :image
      preview_file = resize(file, GayFurCity.config.replacement_thumbnail_width, GayFurCity.config.replacement_thumbnail_width, 87)
    end

    preview_file
  end
end

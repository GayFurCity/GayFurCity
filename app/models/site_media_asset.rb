# frozen_string_literal: true

class SiteMediaAsset < MediaAssetWithVariants
  has_one(:site_asset)

  # the same image can be used by more than one site asset
  scope(:duplicate_relevant, -> { none })

  def self.model
    SiteAsset
  end

  module StorageMethods
    def path_prefix
      GayFurCity.config.site_asset_path_prefix
    end

    def is_protected?
      false
    end
  end

  module FileMethods
    def validate_file
      slot = SiteAsset::SLOTS[name]
      return errors.add(:name, "is invalid") if slot.nil?
      size = slot.size
      FileValidator.new(self, file.path).validate(max_file_sizes: AdminConfig.max_site_asset_file_sizes.transform_values { |v| v * 1.kilobyte }, min_width: size[:min], max_width: size[:max], min_height: size[:min], max_height: size[:max])
      errors.add(:file, "must be square") if image_width != image_height
      errors.add(:file, "can't be animated") if is_animated_png? || is_animated_webp?
    end
  end

  module VariantMethods
    def variants(variant_class = Variant)
      slot = SiteAsset.slot(name)
      pngs = slot.png_sizes.map { |size| variant_class.new(self, :"png_#{size}", :image, "png", MediaAsset::Rescale.new(width: size, height: size, method: :exact)) }
      ico = variant_class.new(self, :ico, :image, "ico", MediaAsset::Rescale.new(width: slot.ico_sizes.max, height: slot.ico_sizes.max, method: :exact))
      super + pngs + [ico]
    end

    # variants are small, so they're made right away
    def generate_variants_after_finalize
      regenerate_variants!
      save!
    end

    # variants.without(original) doesn't work since variants are rebuilt on every call
    def generated_variant_list
      variants.reject { |variant| variant.type == :original }
    end

    def regenerate_variants!(_file = nil)
      list = generated_variant_list
      open_file do |file|
        list.each { |variant| variant.store!(file) }
      end
      self.variants_data = list.map(&:serializable_hash)
      self.generated_variants = list.map(&:type).uniq
      true
    end
  end

  include(StorageMethods)
  include(FileMethods)
  include(VariantMethods)

  def self.available_includes
    %i[creator site_asset]
  end

  class Variant < Variant
    def convert_file(original_file, &block)
      raise(ArgumentError, "block is required") if block.nil?
      if type == :original
        set_data(original_file)
        return block.call(original_file)
      end

      file = ext == "ico" ? SiteMediaAsset.ico(original_file, SiteAsset.slot(name).ico_sizes) : SiteMediaAsset.png(original_file, width)
      set_data(file)
      block.call(file)
    ensure
      file&.close!
    end

    def set_data(file)
      return super unless ext == "ico"
      @data = { type: type, width: width, height: height, size: file.size, md5: MediaAsset.md5(file.path), ext: ext, video: false }
    end
  end

  def self.png_data(file, size)
    ImageResizer.thumbnail(file, size, size, ImageResizer::THUMBNAIL_OPTIONS).pngsave_buffer(strip: true)
  end

  def self.png(file, size)
    Tempfile.new(%w[site-asset .png], binmode: true).tap do |output|
      output.write(png_data(file, size))
      output.rewind
    end
  end

  # An ico file holding a png for each size, see https://en.wikipedia.org/wiki/ICO_(file_format)
  def self.ico(file, sizes)
    images = sizes.map { |size| [size, png_data(file, size)] }
    offset = 6 + (16 * images.size)
    entries = images.map do |size, data|
      # a size of 0 means 256
      entry = [size % 256, size % 256, 0, 0, 1, 32, data.bytesize, offset].pack("C4v2V2")
      offset += data.bytesize
      entry
    end

    Tempfile.new(%w[site-asset .ico], binmode: true).tap do |output|
      output.write([0, 1, images.size].pack("v3"), *entries, *images.map(&:last))
      output.rewind
    end
  end
end

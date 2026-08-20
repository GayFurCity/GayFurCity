# frozen_string_literal: true

class MediaAssetWithVariants < MediaAsset
  class VariantNotFoundError < StandardError; end
  self.abstract_class = true

  after_create(:generate_variants_after_finalize, if: :file_now?)
  after_finalize(:generate_variants_after_finalize, if: :file_later?)

  module VariantMethods
    extend(ActiveSupport::Concern)

    module ClassMethods
      def variant_valid?(options, width, height)
        return true if options.method == :none
        return true if options.method == :exact && width > options.width && height >= options.height
        return true if options.method == :scaled && (options.width.nil? || width >= options.width) && (options.height.nil? || height >= options.height)
        false
      end

      def scaled_variant_dimensions(options, width, height)
        return [width, height] if options.method == :none
        return [options.width, options.height] if options.method == :exact
        box = [options.width, options.height].compact_blank.presence || [width]
        if box.size == 1
          ratio = box[0] / width.to_f
          width = [[width * ratio, 2].max.ceil, box[0]].min & ~1
          height = [[height * ratio, 2].max.ceil, Float::INFINITY].min & ~1
        else
          ratio = [box[0] / width.to_f, box[1] / height.to_f].min
          width = [[width * ratio, 2].max.ceil, box[0]].min & ~1
          height = [[height * ratio, 2].max.ceil, box[1]].min & ~1
        end
        [width, height]
      end
    end

    def variant_valid?(options)
      return false if image_width.nil? || image_height.nil?
      MediaAssetWithVariants.variant_valid?(options, image_width, image_height)
    end

    def scaled_variant_dimensions(options)
      self.class.scaled_variant_dimensions(options, image_width, image_height)
    end

    def variants(variant_class = Variant)
      [variant_class.new(self, :original, is_video? ? :video : :image, file_ext, MediaAsset::Rescale.new(width: image_width, height: image_height, method: :none))]
    end

    def variants_images_first
      variants.sort_by { |v| v.image? ? 0 : 1 }
    end

    def variants_videos_first
      variants.sort_by { |v| v.video? ? 0 : 1 }
    end

    def original
      find_variant!(:original, file_ext)
    end

    def image_variants
      variants.select(&:image?)
    end

    def video_variants
      variants.select(&:video?)
    end

    def regenerate_variants
      regenerate_variants!
    end

    def regenerate_variants!(_file = file)
      raise(NotImplementedError, "#{self.class.name}#regenerate_variants!")
    end

    def generate_variants_after_finalize
      regenerate_variants
    end

    def update_variants_data
      variants = self.variants.without(original)
      data = variants.map(&:cached_hash)
      names = variants.map(&:type).uniq
      self.variants_data = data
      self.generated_variants = names
    end

    def update_variants_partial_data(variants)
      data = (variants.map(&:cached_hash).map { |v| v.transform_keys(&:to_s) } + variants_data).compact_blank
      names = variants.map(&:type).uniq
      self.variants_data = data
      self.generated_variants = names
    end

    def find_variant(type, ext = nil)
      variants.find { |v| v.type == type.to_sym && (ext.nil? || v.ext == ext) }
    end

    def find_variant!(type, ext = nil)
      variant = find_variant(type, ext)
      raise(VariantNotFoundError, "variant \"#{type}\" not found (#{id})") if variant.nil?
      variant
    end
  end

  module StorageMethods
    delegate(:file_path, :backup_file_path, :file_url, to: :original)

    def store_file_finalize
      raise(StandardError, "file not present") if file.nil?
      check_duplicates
      return if duplicate?
      store(file, variants: false)
    end

    def store(user, file = self.file, variants: true)
      super(user, file)
      regenerate_variants! if variants
    end

    def delete(user)
      super
      variants.each(&:delete!)
    end

    def undelete(user)
      super
      variants.each(&:undelete!)
    end

    def expunge(user, status: true)
      super
      variants.each(&:expunge!)
    end
  end

  include(VariantMethods)
  include(StorageMethods)

  class Variant
    include(ActiveModel::Serializers::JSON)

    attr_reader(:media_asset, :type, :format, :ext, :options)

    delegate_missing_to(:media_asset)

    def initialize(media_asset, type, format, ext, options)
      @media_asset = media_asset
      @type = type.to_sym
      @format = format.to_sym
      @ext = ext
      @options = options
    end

    def video?
      MediaAsset.is_video?(ext)
    end

    def image?
      MediaAsset.is_image?(ext)
    end

    def scaled_dimensions
      scaled_variant_dimensions(options)
    end

    def width
      scaled_dimensions.first
    end

    def height
      scaled_dimensions.last
    end

    def set_data(file)
      width, height = MediaAsset.calculate_dimensions(file.path)
      md5 = MediaAsset.md5(file.path)
      @data = { type: type, width: width, height: height, size: file.size, md5: md5, ext: ext, video: video? }
    end

    def data
      return @data if instance_variable_defined?(:@data)
      open_file { |file| set_data(file) }
    end

    def convert_file(original_file, &)
      raise(NotImplementedError, "#{self.class.name}#convert_file not implemented")
    end

    def file_path(protected: is_protected?)
      storage_manager.file_path(md5, ext, type, protected: protected, prefix: path_prefix, protected_prefix: protected_path_prefix, hierarchical: hierarchical?)
    end

    def file_exists?(protected: is_protected?)
      storage_manager.exists?(file_path(protected: protected))
    end

    def backup_file_path(protected: is_protected?)
      backup_storage_manager.file_path(md5, ext, type, protected: protected, prefix: path_prefix, protected_prefix: protected_path_prefix, hierarchical: hierarchical?)
    end

    def backup_file_exists?(protected: is_protected?)
      backup_storage_manager.exists?(backup_file_path(protected: protected))
    end

    def file_url(user:, protected: is_protected?)
      storage_manager.url(md5, ext, type, protected: protected, prefix: path_prefix, protected_prefix: protected_path_prefix, hierarchical: hierarchical?, secret: protected_secret, user: user)
    end

    def store!(original_file)
      convert_file(original_file) do |file|
        storage_manager.store(file, file_path)
        backup_storage_manager.store(file, backup_file_path)
      end
    end

    def delete!
      raise(MediaAsset::DeletionNotSupportedError, "deletion of #{parent_class.name} is not supported") unless parent_class.deletion_supported
      storage_manager.move_file_delete(md5, ext, type, prefix: path_prefix, protected_prefix: protected_path_prefix, hierarchical: hierarchical?)
      backup_storage_manager.move_file_delete(md5, ext, type, prefix: path_prefix, protected_prefix: protected_path_prefix, hierarchical: hierarchical?)
    end

    def undelete!
      raise(MediaAsset::DeletionNotSupportedError, "deletion of #{parent_class.name} is not supported") unless parent_class.deletion_supported
      storage_manager.move_file_undelete(md5, ext, type, prefix: path_prefix, protected_prefix: protected_path_prefix, hierarchical: hierarchical?)
      backup_storage_manager.move_file_undelete(md5, ext, type, prefix: path_prefix, protected_prefix: protected_path_prefix, hierarchical: hierarchical?)
    end

    def expunge!
      storage_manager.delete(file_path(protected: false))
      storage_manager.delete(file_path(protected: true))
      backup_storage_manager.delete(backup_file_path(protected: false))
      backup_storage_manager.delete(backup_file_path(protected: true))
    end

    def serializable_hash(*)
      data.transform_keys(&:to_s)
    end

    def cached_hash
      variants_data.find { |v| v["type"] == type.to_s && v["ext"] == ext } || serializable_hash
    end

    private

    def parent_class
      self.class.name.delete_suffix("::Variant").constantize
    end
  end
end

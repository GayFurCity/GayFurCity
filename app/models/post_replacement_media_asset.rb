# frozen_string_literal: true

class PostReplacementMediaAsset < MediaAssetWithVariants
  STORAGE_ID_SIZE = 16

  has_one(:post_replacement)
  validates(:storage_id, length: { is: STORAGE_ID_SIZE * 2 }, uniqueness: true, if: :storage_id_changed?)
  after_initialize(:initialize_storage_id)
  after_finalize(:update_post_replacement)

  attr_accessor(:backup_post_id)

  scope(:duplicate_relevant, -> { active.joins(:post_replacement).where.not("post_replacements.id": nil).where("post_replacements.status": %w[pending uploading]) })

  def update_post_replacement
    return unless post_replacement&.valid?
    post_replacement.pending! if post_replacement.uploading?
  end

  def initialize_storage_id
    self.storage_id ||= SecureRandom.hex(STORAGE_ID_SIZE)
  end

  def link_to_duplicate
    return unless duplicate?
    return Routes.post_replacements_path(id: duplicate_post_replacement_id) if duplicate_post_replacement_id.present?
    return Routes.posts_path(id: duplicate_post_id) if duplicate_post_id.present?
    return Routes.post_replacement_media_assets_path(search: { id: duplicate_media_asset_id }) if duplicate_media_asset_id.present?
    nil
  end

  def duplicate_post_id
    return unless duplicate? && status_message.present?
    @duplicate_post_id ||= status_message[/post #(\d+)/, 1]&.to_i
  end

  def duplicate_post_replacement_id
    return unless duplicate? && status_message.present?
    @duplicate_post_replacement_id ||= status_message[/post replacement #(\d+)/, 1]&.to_i
  end

  def duplicate_media_asset_id
    return unless duplicate? && status_message.present?
    @duplicate_media_asset_id ||= status_message[/media asset #(\d+)/, 1]&.to_i
  end

  module StorageMethods
    def path_prefix
      GayFurCity.config.replacement_path_prefix
    end

    def protected_secret
      GayFurCity.config.replacement_file_secret
    end

    def is_protected?
      true
    end
  end

  module VariantMethods
    def variants
      super(Variant) + [Variant.new(self, :thumb, :image, "webp", MediaAsset::Rescale.new(width: GayFurCity.config.replacement_thumbnail_width, height: nil, method: :scaled))]
    end

    def regenerate_variants!(file = self.file)
      variants = self.variants.without(original)
      if file
        variants.each { |variant| variant.store!(file) }
      else
        open_file do |rfile|
          variants.each { |variant| variant.store!(rfile) }
        end
      end
      update_variants_data
      true
    end
  end

  class Variant < Variant
    def file_path(protected: is_protected?)
      storage_manager.file_path(storage_id, ext, type, protected: protected, prefix: path_prefix, protected_prefix: protected_path_prefix, hierarchical: hierarchical?)
    end

    def file_url(user:, protected: is_protected?)
      storage_manager.url(storage_id, ext, type, protected: protected, prefix: path_prefix, protected_prefix: protected_path_prefix, hierarchical: hierarchical?, secret: protected_secret, user: user)
    end

    def convert_file(original_file, &block)
      raise(ArgumentError, "block is required") if block.nil?
      handle = ->(file) {
        set_data(file)
        block.call(file)
      }
      return handle.call(original_file) if type == :original
      if is_video? # original
        convert_video(original_file, &handle)
      else
        convert_image(original_file, &handle)
      end
    end

    def convert_video(original_file, &)
      VideoResizer.sample(original_file.path, width: width, height: height).tap(&).close!
    end

    def convert_image(original_file, &)
      ImageResizer.resize(original_file, width, height, 90).tap(&).close!
    end
  end

  include(StorageMethods)
  include(VariantMethods)

  def self.available_includes
    %i[creator post_replacement]
  end
end

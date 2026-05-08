# frozen_string_literal: true

module HasMediaAsset
  extend(ActiveSupport::Concern)

  class_methods do
    def has_media_asset(attribute, nullable: false)
      attribute = attribute.to_sym
      mod = nullable ? MediaAsset::DelegateProperties::Nullable : MediaAsset::DelegateProperties
      class_eval do
        include(mod)

        scope(:with_assets, -> { includes(attribute) })
        scope(:with_assets_and_metadata, -> { with_assets.includes(attribute => :media_metadata) })
        attr_accessor(:file, :propagated)
        alias_method(:propagated?, :propagated)
        after_initialize { @propagated = false }
        belongs_to(attribute, autosave: true)
        accepts_nested_attributes_for(attribute)
        validates_associated(attribute)
        # prevent making duplicate entries when direct uploading
        # validate(:validate_not_duplicate, if: :validate_media_asset_direct?)
        validate(:validate_status, on: :status)
        validate(:validate_checksum_present, if: :validate_media_asset_not_direct?)
        after_initialize(:"build_#{attribute}", unless: -> { (association(attribute).loaded? && send(attribute).present?) || send("#{attribute}_id").present? })
        after_initialize(:set_media_asset_creator, if: -> { creator.present? && (send("#{attribute}_id").blank? || send(attribute).blank? || send(attribute).creator.blank?) })
        before_validation(:propagate_file, if: -> { validate_media_asset? && is_direct? && !propagated? })
        define_method(:media_asset_id) { send("#{attribute}_id") }
        define_method(:media_asset) { send(attribute) }
        define_method(:checksum=) { |value| (send(attribute) || send("build_#{attribute}")).checksum = value }
        define_method(:validate_media_asset?) { send(attribute)&.new_record? }
        define_method(:validate_media_asset_direct?) { validate_media_asset? && send(attribute)&.is_direct? }
        define_method(:validate_media_asset_not_direct?) { validate_media_asset? && !send(attribute)&.is_direct? }
        define_method(:is_direct?) { !file.nil? || direct_url.present? }
        define_method(:set_media_asset_creator) { (send(attribute) || send("build_#{attribute}")).creator = creator }
        define_method(:validate_status) do
          status = send(attribute)&.status
          status_message = send(attribute)&.status_message.presence || status
          return unless %w[duplicate failed expunged].include?(status)
          errors.add(:"#{attribute}.base", status_message)
        end
        define_method(:validate_checksum_present) do
          return if send(attribute)&.checksum.present?
          errors.add(:checksum, "is required unless a file or direct_url is supplied")
        end
        define_method(:propagate_file) do
          raise(StandardError, "propagate_file called multiple times") if @propagated
          @propagated = true
          final = nil
          raise(StandardError, "Cannot propagate file unless media asset is present") if send(attribute).blank?
          if !file.nil?
            final = file
          elsif direct_url.present?
            download = Downloads::File.new(direct_url, exception: false, user: creator)
            if download.valid?
              begin
                final = download.download!
              rescue Downloads::File::Error => e
                errors.add(:base, e.message)
              end
            else
              errors.merge!(download.errors)
            end
          end
          return if errors.any?
          send(attribute).append_all!(final, save: false) # simultaneous append_chunk!(1, data) and finalize! rolled into one call, without saving
          if send(attribute).errors.any?
            errors.merge!(send(attribute).errors)
          end
        end
        define_method(:validate_not_duplicate) do
          if send(attribute).duplicate?
            errors.add(:base, send(attribute).status_message || "duplicate")
            return false
          end
          true
        end
      end
    end
  end
end

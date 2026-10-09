# frozen_string_literal: true

class DomainIconMediaAsset < MediaAsset
  has_one(:domain_icon)

  # the same icon can be used for more than one domain
  scope(:duplicate_relevant, -> { none })

  module StorageMethods
    def path_prefix
      GayFurCity.config.domain_icon_path_prefix
    end

    def is_protected?
      false
    end
  end

  module FileMethods
    def validate_file
      size = AdminConfig.domain_icon_size
      FileValidator.new(self, file.path).validate(max_file_sizes: AdminConfig.max_domain_icon_file_sizes.transform_values { |v| v * 1.kilobyte }, min_width: size[:min], max_width: size[:max], min_height: size[:min], max_height: size[:max])
      errors.add(:file, "must be square") if image_width != image_height
    end
  end

  include(StorageMethods)
  include(FileMethods)

  def self.available_includes
    %i[creator domain_icon]
  end
end

# frozen_string_literal: true

class MascotMediaAsset < MediaAsset
  has_one(:mascot)

  module StorageMethods
    def path_prefix
      GayFurCity.config.mascot_path_prefix
    end

    def is_protected?
      false
    end
  end

  module FileMethods
    def validate_file
      FileValidator.new(self, file.path).validate(max_file_sizes: AdminConfig.max_mascot_file_sizes.transform_values { |v| v * 1.kilobyte }, min_width: AdminConfig.mascot_width[:min], max_width: AdminConfig.mascot_width[:max], min_height: AdminConfig.mascot_height[:min], max_height: AdminConfig.mascot_height[:max])
    end
  end

  include(StorageMethods)
  include(FileMethods)

  def self.available_includes
    %i[creator mascot]
  end
end

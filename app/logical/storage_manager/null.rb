# frozen_string_literal: true

module StorageManager
  class Null < StorageManager::Base
    def store(io, path)
      # no-op
    end

    def delete(path)
      # no-op
    end

    def delete_dir(path)
      # no-op
    end

    def open(path)
      # no-op
    end

    def exists?(_path)
      # no-op
      false
    end

    def move_file(old_path, new_path)
      # no-op
    end
  end
end

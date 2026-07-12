# frozen_string_literal: true

module StorageManager
  class Local < StorageManager::Base
    class InvalidPathError < StandardError; end
    DEFAULT_PERMISSIONS = 0o644

    def store(io, dest_path)
      with_metrics(:store) do
        log(%{store(io, "#{dest_path}")}) do
          temp_file = Tempfile.new(binmode: true)

          FileUtils.mkdir_p(File.dirname(p(dest_path)))
          io.rewind
          bytes_copied = IO.copy_stream(io, temp_file)
          raise(Error, "store failed: #{bytes_copied}/#{io.size} bytes copied") if bytes_copied != io.size

          temp_file.flush
          FileUtils.chmod(DEFAULT_PERMISSIONS, temp_file.path)
          FileUtils.mv(temp_file.path, p(dest_path))
        rescue StandardError => e
          temp_file.close!
          raise(Error, e)
        ensure
          temp_file.close
        end
      end
    end

    def delete(path)
      with_metrics(:delete) do
        log(%{delete("#{path}")}) do
          FileUtils.rm_f(p(path))
        end
      end
    end

    def open(path, &)
      with_metrics(:open) do
        log(%{open("#{path}")}) do
          file = File.open(p(path), "r", binmode: true) # rubocop:disable Style/FileOpen
          if block_given?
            begin
              yield(file)
            ensure
              file.close
            end
          else
            file
          end
        end
      end
    end

    def exists?(path)
      with_metrics(:exists) do
        log(%{exists("#{path}")}) do
          File.exist?(p(path))
        end
      end
    end

    def move_file(old_path, new_path)
      with_metrics(:move_file) do
        log(%{move_file("#{old_path}", "#{new_path}")}) do
          if exists?(old_path)
            FileUtils.mkdir_p(File.dirname(p(new_path)))
            FileUtils.mv(p(old_path), p(new_path))
            FileUtils.chmod(DEFAULT_PERMISSIONS, p(new_path))
          end
        end
      end
    end

    private

    def p(path)
      raise(InvalidPathError, "path is blank") if path.blank?
      raise(InvalidPathError, "path resolves to root") if %W[#{File::SEPARATOR} .].include?(path)
      path = "#{File::SEPARATOR}#{path}" unless path.start_with?(File::SEPARATOR)
      parts = path.split(File::SEPARATOR).compact_blank
      raise(InvalidPathError, "path resolves to root") if parts.one?
      raise(InvalidPathError, "path contains '..'") if parts.include?("..")
      path = File::SEPARATOR + parts.join(File::SEPARATOR)
      Pathname.new(path).cleanpath.to_s
    end
  end
end

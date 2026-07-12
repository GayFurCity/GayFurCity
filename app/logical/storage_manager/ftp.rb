# frozen_string_literal: true

require("net/ftp")

module StorageManager
  class Ftp < StorageManager::Base
    TEMP_DIR = "/tmp"
    attr_reader(:host, :port, :username, :password)

    def initialize(host:, port:, username:, password:, **)
      @host = host
      @port = port
      @username = username
      @password = password
      super(**)
    end

    def open_ftp
      ftp = Net::FTP.open(host, {
        port:     port,
        username: username,
        password: password,
      })
      if block_given?
        begin
          yield(ftp)
        ensure
          ftp.close
        end
      else
        ftp
      end
    end

    def store(io, dest_path)
      with_metrics(:store) do
        log(%{store(io, "#{dest_path}")}) do
          temp_path = "#{TEMP_DIR}#{dest_path}-#{SecureRandom.uuid}.tmp"

          FileUtils.mkdir_p(File.dirname(temp_path))
          io.rewind
          bytes_copied = IO.copy_stream(io, temp_path)
          raise(Error, "store failed: #{bytes_copied}/#{io.size} bytes copied") if bytes_copied != io.size

          open_ftp do |ftp|
            ftp.putbinaryfile(temp_path, dest_path)
          end
        rescue StandardError => e
          FileUtils.rm_f(temp_path)
          raise(Error, e)
        ensure
          FileUtils.rm_f(temp_path) if temp_path
        end
      end
    end

    def delete(path)
      with_metrics(:delete) do
        log(%{delete("#{path}")}, if: self.class != Bunny) do # overridden
          open_ftp do |ftp|
            ignore_notfound { ftp.delete(path) }
          end
        end
      end
    end

    def open(path, &)
      with_metrics(:open) do
        log(%{open("#{path}"}) do
          file = Tempfile.new(binmode: true)
          open_ftp do |ftp|
            ftp.getbinaryfile(path, file)
          end
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
          exists = false
          open_ftp do |ftp|
            ignore_notfound do
              ftp.size(path)
              exists = true
            end
          end

          exists
        end
      end
    end

    def move_file(old_path, new_path)
      with_metrics(:move_file) do
        log(%{move_file("#{old_path}", "#{new_path}")}) do
          open(old_path) do |file|
            store(file, new_path)
          end
          delete(old_path)
        end
      end
    end

    private

    def ignore_notfound
      yield
    rescue Net::FTPPermError => e
      raise(e) unless e.message =~ /550/
    end
  end
end

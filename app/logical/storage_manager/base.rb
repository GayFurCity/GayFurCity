# frozen_string_literal: true

module StorageManager
  class Base
    attr_reader(:base_url, :base_dir, :base_path, :hierarchical)

    DB_EXPORT_PREFIX = "db_export"

    def initialize(base_url: default_base_url, base_path: default_base_path, base_dir: DEFAULT_BASE_DIR, hierarchical: false)
      @base_url = base_url.chomp("/")
      @base_dir = base_dir
      @base_path = base_path
      @hierarchical = hierarchical
    end

    def default_base_path
      "/data"
    end

    def default_base_url
      GayFurCity.config.cdn_hostname
    end

    # Store the given file at the given path. If a file already exists at that
    # location it should be overwritten atomically. Either the file is fully
    # written, or an error is raised and the original file is left unchanged. The
    # file should never be in a partially written state.
    def store(io, path)
      raise(NotImplementedError, "#{self.class.name}#store not implemented")
    end

    # Delete the file at the given path. If the file doesn't exist, no error
    # should be raised.
    def delete(path)
      raise(NotImplementedError, "#{self.class.name}#delete not implemented")
    end

    # Delete the directory at the given path. If the directory doesn't exist, isn't empty, or the
    # backend has no real notion of directories, no error should be raised - this is best-effort
    # cleanup, not a guarantee.
    def delete_dir(path)
      raise(NotImplementedError, "#{self.class.name}#delete_dir not implemented")
    end

    # Return a readonly copy of the file located at the given path.
    def open(path, &)
      raise(NotImplementedError, "#{self.class.name}#open not implemented")
    end

    def exists?(path)
      raise(NotImplementedError, "#{self.class.name}#exists not implemented")
    end

    # Move a file from the old location to the new location
    def move_file(old_path, new_path)
      raise(NotImplementedError, "#{self.class.name}#move_file not implemented")
    end

    def protected_params(url, secret: GayFurCity.config.protected_file_secret, user: nil)
      raise(ArgumentError, "user is required for protected_params") if user.blank?
      user_id = user.id
      time = (Time.now + 15.minutes).to_i
      hmac = Digest::MD5.base64digest("#{time} #{url} #{user_id} #{secret}").tr("+/", "-_").gsub("==", "")
      "?auth=#{hmac}&expires=#{time}&uid=#{user_id}"
    end

    def file_name(md5, ext, type)
      return "#{md5}_#{type}.#{ext}" if variant_location(type, ext) == :file
      "#{md5}.#{ext}"
    end

    def url_path(md5, file_ext, type, protected: false, prefix: "", protected_prefix: "", hierarchical: :default)
      subdir = ""
      subdir += "#{type}/" if variant_location(type, file_ext) == :path
      subdir += subdir_for(md5, hierarchical: hierarchical)
      file = file_name(md5, file_ext, type)
      clean_path("#{base_path}/#{prefix}#{protected_prefix if protected}#{subdir}#{file}")
    end

    def url(md5, file_ext, type, protected: false, prefix: "", protected_prefix: "", hierarchical: :default, secret: GayFurCity.config.protected_file_secret, user: nil)
      path = url_path(md5, file_ext, type, protected: protected, prefix: prefix, protected_prefix: protected_prefix, hierarchical: hierarchical)
      url = "#{base_url}#{path}"
      url += protected_params(path, secret: secret, user: user) if protected
      url
    end

    def file_path(md5, file_ext, type, protected: false, prefix: "", protected_prefix: "", hierarchical: :default)
      subdir = ""
      subdir += "#{type}/" if variant_location(type, file_ext) == :path
      subdir += subdir_for(md5, hierarchical: hierarchical)
      file = file_name(md5, file_ext, type)
      clean_path("#{base_dir}/#{prefix}#{protected_prefix if protected}#{subdir}#{file}")
    end

    def move_file_delete(md5, file_ext, type, prefix: "", protected_prefix: "", hierarchical: :default)
      old = file_path(md5, file_ext, type, protected: false, prefix: prefix, protected_prefix: protected_prefix, hierarchical: hierarchical)
      new = file_path(md5, file_ext, type, protected: true, prefix: prefix, protected_prefix: protected_prefix, hierarchical: hierarchical)
      move_file(old, new)
    end

    def move_file_undelete(md5, file_ext, type, prefix: "", protected_prefix: "", hierarchical: :default)
      old = file_path(md5, file_ext, type, protected: true, prefix: prefix, protected_prefix: protected_prefix, hierarchical: hierarchical)
      new = file_path(md5, file_ext, type, protected: false, prefix: prefix, protected_prefix: protected_prefix, hierarchical: hierarchical)
      move_file(old, new)
    end

    def db_export_path(file_name)
      clean_path("#{base_dir}/#{DB_EXPORT_PREFIX}/#{file_name}")
    end

    def db_export_dir_path(date)
      clean_path("#{base_dir}/#{DB_EXPORT_PREFIX}/#{date}")
    end

    def db_export_url_path(file_name)
      clean_path("#{base_path}/#{DB_EXPORT_PREFIX}/#{file_name}")
    end

    def db_export_url(file_name)
      "#{base_url}#{db_export_url_path(file_name)}"
    end

    def store_db_export(io, file_name)
      store(io, db_export_path(file_name))
    end

    def delete_db_export(file_name)
      delete(db_export_path(file_name))
    end

    def delete_db_export_dir(date)
      delete_dir(db_export_dir_path(date))
    end

    def subdir_for(md5, hierarchical: :default)
      h = hierarchical == :default ? self.hierarchical : hierarchical
      h ? "#{md5[0..1]}/#{md5[2..3]}/" : ""
    end

    def clean_path(path)
      path.gsub(%r(/{2,}), "/")
    end

    protected

    LOG_LINES = 5
    def log(message, if: true, &)
      cond = binding.local_variable_get(:if)
      format = "\e[34m[\e[36m%s\e[0m\e[34m]\e[0m %s \e[34m- \e[35m%s\e[0m"
      start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC, :nanosecond)
      begin
        yield
      ensure
        end_time = Process.clock_gettime(Process::CLOCK_MONOTONIC, :nanosecond)
        duration = ((end_time - start_time) / 1000 / 1000).round(2)
        if cond
          callers = caller_locations.reject do |loc|
            path = loc.absolute_path || loc.path
            # path.include?("/storage_manager/") ||
            (path.include?("/storage_manager/") && loc.label == "log") || !Rails.backtrace_cleaner.clean_frame("#{path}:#{loc.lineno}")
          end.first(LOG_LINES)
          Rails.logger.debug(format(format, self.class, message, "#{duration.round(2)}ms"))
          callers.each { |c| Rails.logger.debug { "↳ #{c.path.gsub(%r{^/app/}, '')}:#{c.lineno} in `#{c.label}`" } }
        end
        # caller_locations.select { |loc| !Rails.backtrace_cleaner.clean_frame("#{path}:#{loc.lineno}")}
        #                 .each { |c| Rails.logger.debug("↳ #{c.path.gsub(%r{^/app/}, "")}:#{c.lineno} in `#{c.label}`") }
      end
    end

    def variant_location(...)
      GayFurCity.config.variant_location(...)
    end

    def with_metrics(method)
      return yield unless Metrics.enabled?

      result = nil
      tags = { class: self.class.name }
      Yabeda.storage.public_send(method).increment(tags)
      Yabeda.storage.public_send("#{method}_runtime").measure(tags) do
        result = yield
      rescue StandardError
        Yabeda.storage.public_send("#{method}_failures").increment(tags)
        raise
      end
      result
    end
  end
end

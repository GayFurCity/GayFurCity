# frozen_string_literal: true

module ChunkedUpload
  class InvalidChunkError < StandardError; end
  class InvalidStatusError < StandardError; end
  class InvalidChecksumError < StandardError; end
  class EmptyError < StandardError; end
  class FileTooLargeError < StandardError; end
  extend(ActiveSupport::Concern)

  included do
    define_model_callbacks(:finalize, :cancel)
    attr_reader(:is_all, :no_save)

    after_destroy(:remove_tempfile!)
    after_create(:update_tempfile, if: :file_now?)

    def tempfile_path
      part = id.present? ? id : (@temp_id ||= SecureRandom.hex(4))
      "#{Dir.tmpdir}/#{self.class.name.underscore}-#{part}.partial"
    end

    def tempfile_checksum
      MediaAsset.md5(tempfile_path) if File.file?(tempfile_path)
    end

    def remove_tempfile
      MediaAssetDeleteTempfileJob.set(wait: 24.hours).perform_later(self)
    end

    def remove_tempfile!
      FileUtils.rm_f(tempfile_path)
    end

    def tempfile_size
      return File.size(tempfile_path) if File.exist?(tempfile_path)
      0
    end

    def parse_chunk(data)
      pos = 0
      pos = data.pos if data.respond_to?(:pos)
      data.rewind if data.respond_to?(:rewind) && pos != 0
      data = data.read if data.respond_to?(:read)
      data
    end

    def append_chunk!(id, data)
      add_error(InvalidStatusError, :base, "Upload is not in progress") unless in_progress?
      add_error(InvalidChunkError, :chunk_id, "is invalid") if !id.is_a?(Integer) || id < 1
      add_error(InvalidChunkError, :chunk_id, "unexpected: #{id}, expected: #{last_chunk_id + 1}") if (last_chunk_id + 1) != id
      data = parse_chunk(data)
      add_error(EmptyError, :base, "Data is empty") if data.nil? || data.size == 0 # rubocop:disable Style/ZeroLengthPredicate
      return if errors.any?

      if id == 1
        ensure_consistency!
        self.status = "uploading"
      end
      self.last_chunk_id += 1
      save! unless no_save
      File.open(tempfile_path, "ab") { |f| f.write(data) }
      check_size!
    end

    def append_all!(data, save: true)
      @is_all = true
      @no_save = true
      @is_direct = true
      add_error(InvalidChunkError, :last_chunk_id, "Cannot use append_all! if last_chunk_id is not 0") if last_chunk_id != 0
      return if errors.any?
      append_chunk!(1, data)
      return if errors.any?
      finalize!
      save! if save
    end

    def ensure_consistency!
      return unless File.exist?(tempfile_path)
      FileUtils.rm_rf(tempfile_path) if File.directory?(tempfile_path)
      File.truncate(tempfile_path, 0)
    end

    def finalize!
      add_error(InvalidStatusError, :base, "Upload is not in progress") unless in_progress?
      add_error(EmptyError, :base, "Upload is empty") if last_chunk_id == 0
      add_error(InvalidChecksumError, :checksum, "missing") if !is_all && checksum.blank?
      add_error(InvalidChecksumError, :checksum, "mismatch") if checksum.present? && tempfile_checksum != checksum
      return if errors.any?
      self.file = File.open(tempfile_path)
      return unless check_size!(MediaAsset.file_header_to_file_ext(file.path))
      self.status = "active"
      run_callbacks(:finalize, :after)
      save! unless no_save
    end

    def cancel!
      add_error(InvalidStatusError, :base, "Upload is not in progress") unless in_progress?
      return if errors.any?
      run_callbacks(:cancel, :before)
      remove_tempfile!
      self.status = "cancelled"
      run_callbacks(:cancel, :after)
      save! unless no_save
    end

    private

    def add_error(klass, attribute, message, force: false)
      raise(klass, "#{attribute.upcase_first unless attribute == :base} #{message}".strip) if force || @raise_errors
      errors.add(attribute, message)
    end

    def unsaved(&block)
      ns = no_save
      @no_save = true
      block.call
      if ns.nil?
        remove_instance_variable(:@no_save)
      else
        @no_save = ns
      end
    end

    def with_errors(&block)
      @raise_errors = true
      block.call
      @raise_errors = false
    end

    def check_size!(file_ext = nil)
      too_large!(file_ext) if tempfile_size > AdminConfig.instance.max_file_sizes.fetch(file_ext, AdminConfig.instance.max_file_size) * 1.megabyte
      return true unless failed? && status_message.starts_with?("File size is too large.")
      false
    end

    def too_large!(file_ext = nil)
      unsaved { cancel! }
      self.status = "failed"
      self.status_message = "File size is too large. Maximum allowed for this file type is #{ApplicationController.helpers.number_to_human_size(AdminConfig.instance.max_file_sizes.fetch(file_ext, AdminConfig.instance.max_file_size) * 1.megabyte)}"
      save! unless no_save
    end

    # when the file is propagated down from the upload it's stored with a temporary id due to the media asset not yet having an id,
    # once the media asset is created and has an id we need to move it so it's in the correct spot for the future
    def update_tempfile
      return unless instance_variable_defined?(:@temp_id) && file.present? && File.exist?(file.path)
      if %r{#{Dir.tmpdir}/#{self.class.name.underscore}-(\w+)\.partial} =~ file.path && (!/\d+$/.match?($1) || $1.to_i != id)
        FileUtils.mv(file.path, tempfile_path)
        self.file = File.open(tempfile_path)
        # puts "moved tempfile #{@temp_id} to #{id}"
      end
    end
  end

  # both of the after callbacks are before a forced save, this may cause unexpected behavior
  module ClassMethods
    def after_finalize(*, &)
      set_callback(:finalize, :after, *, &)
    end

    def before_cancel(*, &)
      set_callback(:cancel, :before, *, &)
    end

    def after_cancel(*, &)
      set_callback(:cancel, :after, *, &)
    end
  end
end

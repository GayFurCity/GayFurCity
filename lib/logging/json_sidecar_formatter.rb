# frozen_string_literal: true

module Logging
  # Wraps the normal plain-text Logger::Formatter so the primary log file's format doesn't
  # change at all, while every line is *also* appended as a JSON object (via JsonFormatter) to
  # a separate file - e.g. for a log shipper to ingest without needing to parse freeform text.
  #
  # Uses flock around the JSON write (like Middleware::JsonLog) since, unlike the primary
  # ::Logger, this holds one file handle open for the process's lifetime and multiple
  # processes/threads may be writing to it at once.
  class JsonSidecarFormatter < ::Logger::Formatter
    def initialize(path)
      super()
      @json_formatter = JsonFormatter.new
      FileUtils.mkdir_p(File.dirname(path))
      @device = File.open(path, "a")
      @device.sync = true
    end

    def call(severity, timestamp, progname, msg)
      json_line = @json_formatter.call(severity, timestamp, progname, msg)
      @device.flock(File::LOCK_EX)
      @device.write(json_line)
      @device.flock(File::LOCK_UN)

      super
    end
  end
end

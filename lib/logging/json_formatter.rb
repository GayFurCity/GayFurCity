# frozen_string_literal: true

module Logging
  # A Logger::Formatter that emits each line as a single JSON object instead of the default
  # freeform text line, so the log file can be parsed/ingested without losing any of the detail
  # a plain-text line would have had (message, exception class, backtrace, tags from
  # ActiveSupport::TaggedLogging, etc - anything callers would normally pass to Rails.logger).
  #
  # ActiveSupport::TaggedLogging wraps the configured logger and extends its formatter to prepend
  # any active tags (e.g. request_id) as plain text onto `msg` before calling here - #msg2str below
  # just captures whatever text ends up in `msg` as-is, tags included, so nothing is lost.
  class JsonFormatter < ::Logger::Formatter
    def call(severity, timestamp, progname, msg)
      "#{{
        time:     timestamp.utc.iso8601(6),
        severity: severity,
        pid:      Process.pid,
        progname: progname,
        message:  msg2str(msg),
      }.compact.to_json}\n"
    end
  end
end

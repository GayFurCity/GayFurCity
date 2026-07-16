# frozen_string_literal: true

require("test_helper")

module Logging
  class JsonFormatterTest < ActiveSupport::TestCase
    def build_logger
      @io = StringIO.new
      ActiveSupport::TaggedLogging.new(::Logger.new(@io, formatter: JsonFormatter.new))
    end

    def logged_lines
      @io.string.lines.map { |line| JSON.parse(line) }
    end

    should("emit a single valid JSON object per line") do
      logger = build_logger
      logger.info("hello world")

      lines = @io.string.lines

      assert_equal(1, lines.size)
      parsed = JSON.parse(lines.first)

      assert_equal("hello world", parsed["message"])
      assert_equal("INFO", parsed["severity"])
      assert_predicate(parsed["time"], :present?)
      assert_equal(Process.pid, parsed["pid"])
    end

    should("preserve multi-line messages (e.g. exception backtraces) without breaking JSON parsing") do
      logger = build_logger
      exception = begin
        raise("boom")
      rescue StandardError => e
        e
      end
      backtrace = Rails.backtrace_cleaner.clean(exception.backtrace).join("\n")
      logger.error("#{exception.class}: #{exception.message}\n#{backtrace}")

      lines = @io.string.lines

      assert_equal(1, lines.size)
      parsed = JSON.parse(lines.first)

      assert_includes(parsed["message"], "RuntimeError: boom")
      assert_includes(parsed["message"], backtrace)
    end

    should("fold active tags into the message without breaking JSON validity") do
      logger = build_logger
      logger.tagged("req-123") { logger.info("tagged message") }

      lines = @io.string.lines

      assert_equal(1, lines.size)
      parsed = JSON.parse(lines.first)

      assert_equal("[req-123] tagged message", parsed["message"])
    end
  end
end

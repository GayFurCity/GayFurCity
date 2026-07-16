# frozen_string_literal: true

require("test_helper")

module Logging
  class JsonSidecarFormatterTest < ActiveSupport::TestCase
    setup do
      @json_path = Rails.root.join("tmp/json_sidecar_formatter_test.jsonl")
      FileUtils.rm_f(@json_path)
      @formatter = JsonSidecarFormatter.new(@json_path)
    end

    teardown do
      FileUtils.rm_f(@json_path)
    end

    should("return the normal plain-text formatted line, unchanged") do
      time = Time.now
      line = @formatter.call("INFO", time, nil, "hello world")

      assert_equal(::Logger::Formatter.new.call("INFO", time, nil, "hello world"), line)
      assert_not(line.start_with?("{"))
    end

    should("append a JSON copy of the same line to the sidecar file") do
      @formatter.call("ERROR", Time.now, nil, "boom\nwith a backtrace line")
      @formatter.call("INFO", Time.now, nil, "second line")

      lines = File.readlines(@json_path)

      assert_equal(2, lines.size)

      first = JSON.parse(lines.first)

      assert_equal("ERROR", first["severity"])
      assert_equal("boom\nwith a backtrace line", first["message"])

      second = JSON.parse(lines.second)

      assert_equal("INFO", second["severity"])
      assert_equal("second line", second["message"])
    end
  end
end

# frozen_string_literal: true

require("test_helper")

module Middleware
  class JsonLogTest < ActiveSupport::TestCase
    # Each test gets its own log files - the real ones in log/ are shared with every other
    # parallel worker's requests, so "the last line" there isn't necessarily ours.
    def setup
      @dir = Dir.mktmpdir
      @request_path = File.join(@dir, "requests.jsonl")
      @performance_path = File.join(@dir, "performance.jsonl")
    end

    def teardown
      FileUtils.remove_entry(@dir)
    end

    def build_middleware(app)
      JsonLog.new(app).tap do |middleware|
        middleware.instance_variable_set(:@request_path, @request_path)
        middleware.instance_variable_set(:@performance_path, @performance_path)
      end
    end

    def last_request_line
      File.readlines(@request_path).last
    end

    def last_performance_line
      File.readlines(@performance_path).last
    end

    should("log the request summary to the requests file and queries/renders to the performance file") do
      app = ->(_env) do
        ActiveSupport::Notifications.instrument("sql.active_record", sql: "SELECT 1", name: "Test Load", connection: ::ActiveRecord::Base.connection)
        ActiveSupport::Notifications.instrument("render_partial.action_view", identifier: Rails.root.join("app/views/posts/_post.html.erb").to_s)
        [200, {}, [""]]
      end
      middleware = build_middleware(app)

      middleware.call(Rack::MockRequest.env_for("/test"))

      request_json = JSON.parse(last_request_line)

      assert_equal("/test", request_json["path"])
      assert_not(request_json.key?("queries"))
      assert_not(request_json.key?("renders"))

      performance_json = JSON.parse(last_performance_line)

      assert_equal(request_json["request_id"], performance_json["request_id"])

      assert_equal(1, performance_json["queries"].size)
      assert_equal("SELECT 1", performance_json["queries"].first["sql"])
      assert(performance_json["queries"].first.key?("allocations"))
      assert(performance_json["queries"].first.key?("duration"))

      assert_equal(1, performance_json["renders"].size)
      assert_equal("posts/_post.html.erb", performance_json["renders"].first["file"])
      assert_equal("render_partial", performance_json["renders"].first["type"])
      assert(performance_json["renders"].first.key?("allocations"))
    end

    should("ignore internal SCHEMA/EXPLAIN queries") do
      app = ->(_env) do
        ActiveSupport::Notifications.instrument("sql.active_record", sql: "PRAGMA foreign_keys", name: "SCHEMA", connection: ::ActiveRecord::Base.connection)
        [200, {}, [""]]
      end
      middleware = build_middleware(app)

      middleware.call(Rack::MockRequest.env_for("/test"))

      performance_json = JSON.parse(last_performance_line)

      assert_empty(performance_json["queries"])
    end

    should("tag the bang-prefixed full template render with its type") do
      app = ->(_env) do
        ActiveSupport::Notifications.instrument("!render_template.action_view", identifier: Rails.root.join("app/views/posts/index.html.erb").to_s)
        [200, {}, [""]]
      end
      middleware = build_middleware(app)

      middleware.call(Rack::MockRequest.env_for("/test"))

      performance_json = JSON.parse(last_performance_line)

      assert_equal(1, performance_json["renders"].size)
      assert_equal("posts/index.html.erb", performance_json["renders"].first["file"])
      assert_equal("render_template", performance_json["renders"].first["type"])
    end
  end
end

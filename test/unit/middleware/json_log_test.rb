# frozen_string_literal: true

require("test_helper")

module Middleware
  class JsonLogTest < ActiveSupport::TestCase
    def setup
      @request_path = Rails.root.join("log", "requests.#{Rails.env}.jsonl")
      @performance_path = Rails.root.join("log", "performance.#{Rails.env}.jsonl")
      @existing_request_size = File.exist?(@request_path) ? File.size(@request_path) : 0
      @existing_performance_size = File.exist?(@performance_path) ? File.size(@performance_path) : 0
    end

    def last_logged_line(path, existing_size)
      File.open(path) do |f|
        f.seek(existing_size)
        f.read.lines.last
      end
    end

    def last_request_line
      last_logged_line(@request_path, @existing_request_size)
    end

    def last_performance_line
      last_logged_line(@performance_path, @existing_performance_size)
    end

    should("log the request summary to the requests file and queries/renders to the performance file") do
      app = ->(_env) do
        ActiveSupport::Notifications.instrument("sql.active_record", sql: "SELECT 1", name: "Test Load", connection: ::ActiveRecord::Base.connection)
        ActiveSupport::Notifications.instrument("render_partial.action_view", identifier: Rails.root.join("app/views/posts/_post.html.erb").to_s)
        [200, {}, [""]]
      end
      middleware = JsonLog.new(app)

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
      middleware = JsonLog.new(app)

      middleware.call(Rack::MockRequest.env_for("/test"))

      performance_json = JSON.parse(last_performance_line)

      assert_empty(performance_json["queries"])
    end

    should("tag the bang-prefixed full template render with its type") do
      app = ->(_env) do
        ActiveSupport::Notifications.instrument("!render_template.action_view", identifier: Rails.root.join("app/views/posts/index.html.erb").to_s)
        [200, {}, [""]]
      end
      middleware = JsonLog.new(app)

      middleware.call(Rack::MockRequest.env_for("/test"))

      performance_json = JSON.parse(last_performance_line)

      assert_equal(1, performance_json["renders"].size)
      assert_equal("posts/index.html.erb", performance_json["renders"].first["file"])
      assert_equal("render_template", performance_json["renders"].first["type"])
    end
  end
end

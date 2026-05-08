# frozen_string_literal: true

require("test_helper")

class ExceptionLogTest < ActiveSupport::TestCase
  self.use_transactional_tests = false

  context("An exception log") do
    should("log for query timeout errors with bind parameters") do
      Post.connection.execute("SET STATEMENT_TIMEOUT = 50")
      e = assert_raises(ActiveRecord::QueryCanceled) do
        Post.from("pg_sleep(1), posts").where(description: "bind param").count
      end
      log = ExceptionLog.add!(e, user_id: 1, request: ActionDispatch::TestRequest.new("rack.input" => "abc", "REMOTE_ADDR" => "127.0.0.1"))

      assert_equal(["bind param"], log.extra_params["sql"]["binds"])
    ensure
      Post.connection.execute("SET STATEMENT_TIMEOUT = 3000")
      ExceptionLog.destroy_all
    end
  end
end

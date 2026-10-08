# frozen_string_literal: true

require("test_helper")

class SystemsControllerTest < ActionDispatch::IntegrationTest
  context("The systems controller") do
    setup do
      @user = create(:owner_user)
    end

    context("show action") do
      setup do
        GayFurCity.config.stubs(:eris_server).returns("http://eris:5588")
        stub_request(:get, "http://eris:5588/status").to_return(body: { version: "1.0.1", ready: true, images: 2, chunks: 1, tombstones: 1, tombstone_ratio: 0.5, index_heap_bytes: 1024, cursor: 3, lag_seconds: 0.0, bootstrap_seconds: 0.01, uptime_seconds: 60 }.to_json)
        stub_request(:get, "http://eris:5588/metrics").to_return(body: <<~METRICS)
          # TYPE eris_http_requests_total counter
          eris_http_requests_total{route="/query",status="200"} 3
          # TYPE eris_writes_total counter
          eris_writes_total{op="upsert"} 3
          # TYPE eris_query_duration_seconds summary
          eris_query_duration_seconds{kind="hash",quantile="0.5"} 0.001
          eris_query_duration_seconds_sum{kind="hash"} 0.003
          eris_query_duration_seconds_count{kind="hash"} 3
        METRICS
      end

      should("render") do
        get_auth(system_path, @user)

        assert_response(:success)
        assert_select("th", text: "Eris")
        assert_select("td", text: "1.0.1")
        assert_select("dt", text: "upsert")
      end

      should("render when eris is unreachable") do
        stub_request(:get, "http://eris:5588/status").to_timeout
        get_auth(system_path, @user)

        assert_response(:success)
        assert_select("td", text: "Error")
      end

      should("render without eris when it is not configured") do
        GayFurCity.config.stubs(:eris_server).returns(nil)
        get_auth(system_path, @user)

        assert_response(:success)
        assert_select("th", text: "Eris", count: 0)
      end

      context("access control") do
        asserts do
          access.gte(User::Levels::OWNER).get { system_path }
        end
      end
    end

    context("dbsize action") do
      should("render") do
        get_auth(dbsize_system_path, @user)

        assert_response(:success)
      end

      context("access control") do
        asserts do
          access.gte(User::Levels::OWNER).get { dbsize_system_path }
        end
      end
    end
  end
end

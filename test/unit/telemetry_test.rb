# frozen_string_literal: true

require("test_helper")

class TelemetryTest < ActiveSupport::TestCase
  def stub_config(enabled:)
    GayFurCity.config.stubs(:telemetry_enabled).returns(enabled)
    GayFurCity.config.stubs(:telemetry_endpoint).returns("https://telemetry.example.com")
    GayFurCity.config.stubs(:telemetry_organization).returns("default")
    GayFurCity.config.stubs(:telemetry_stream).returns("gayfurcity")
    GayFurCity.config.stubs(:telemetry_username).returns("root@example.com")
    GayFurCity.config.stubs(:telemetry_password).returns("password")
  end

  context("report!") do
    context("disabled") do
      should("not make any request") do
        stub_config(enabled: false)
        Telemetry.report!(exception: "StandardError")

        assert_not_requested(:post, /telemetry\.example\.com/)
      end
    end

    context("enabled") do
      should("post the data as a JSON document") do
        stub_config(enabled: true)
        request_stub = stub_request(:post, "https://telemetry.example.com/api/default/gayfurcity/_json")
                       .with { |req| JSON.parse(req.body).first["exception"] == "StandardError" }

        Telemetry.report!(exception: "StandardError")

        assert_requested(request_stub)
      end

      should("not raise if the request fails") do
        stub_config(enabled: true)
        stub_request(:post, "https://telemetry.example.com/api/default/gayfurcity/_json").to_timeout

        assert_nothing_raised do
          Telemetry.report!(exception: "StandardError")
        end
      end
    end
  end

  context("exception") do
    should("not enqueue anything when disabled") do
      stub_config(enabled: false)

      assert_no_enqueued_jobs(only: ReportTelemetryJob) do
        Telemetry.exception(StandardError.new("boom"), source: "Test")
      end
    end

    should("report the exception through ReportTelemetryJob") do
      stub_config(enabled: true)
      request_stub = stub_request(:post, "https://telemetry.example.com/api/default/gayfurcity/_json")
                     .with do |req|
                       body = JSON.parse(req.body).first
                       body["exception"] == "StandardError" && body["message"] == "boom" && body["source"] == "Test"
                     end

      with_inline_jobs { Telemetry.exception(StandardError.new("boom"), source: "Test") }

      assert_requested(request_stub)
    end
  end

  context("track") do
    should("not enqueue anything when disabled") do
      stub_config(enabled: false)
      user = create(:user)

      assert_no_enqueued_jobs(only: ReportTelemetryJob) do
        Telemetry.track(:login, user: user, ip: "127.0.0.1")
      end
    end

    # track rescues StandardError internally (logging it via ExceptionLog, which itself reports
    # through Telemetry.exception) so bad input never propagates to the caller - a telemetry call
    # shouldn't be able to crash whatever triggered it. The invalid call still results in one
    # ReportTelemetryJob: a report of the ArgumentError it raised internally, not the original
    # (never-sent) tracked event.
    should("report the internal error instead of raising for an event that isn't a known UserEvent category") do
      stub_config(enabled: true)
      user = create(:user)
      request_stub = stub_request(:post, "https://telemetry.example.com/api/default/gayfurcity/_json")
                     .with { |req| JSON.parse(req.body).first["exception"] == "ArgumentError" }

      with_inline_jobs { Telemetry.track(:not_a_real_event, user: user, ip: "127.0.0.1") }

      assert_requested(request_stub)
    end

    should("report the internal error instead of raising without an ip") do
      stub_config(enabled: true)
      # resolvable: false - a plain (non-UserResolvable) User, so track's `ip.nil? && user.is_a?
      # (UserResolvable)` fallback doesn't silently default ip to "127.0.0.1" the way the factory's
      # normal UserResolvable wrapper would, and the "ip required" path actually gets exercised.
      user = create(:user, resolvable: false)
      request_stub = stub_request(:post, "https://telemetry.example.com/api/default/gayfurcity/_json")
                     .with { |req| JSON.parse(req.body).first["exception"] == "ArgumentError" }

      with_inline_jobs { Telemetry.track(:login, user: user, ip: nil) }

      assert_requested(request_stub)
    end

    should("report the event through ReportTelemetryJob") do
      stub_config(enabled: true)
      user = create(:user)
      request_stub = stub_request(:post, "https://telemetry.example.com/api/default/gayfurcity/_json")
                     .with do |req|
                       body = JSON.parse(req.body).first
                       body["event"] == "login" && body["user_id"] == user.id && body["ip"] == "127.0.0.1"
                     end

      with_inline_jobs { Telemetry.track(:login, user: user, ip: "127.0.0.1") }

      assert_requested(request_stub)
    end
  end
end

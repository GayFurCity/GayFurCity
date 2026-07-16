# frozen_string_literal: true

require("test_helper")

class OpenObserveReporterTest < ActiveSupport::TestCase
  def stub_config(enabled:)
    GayFurCity.config.stubs(:openobserve_enabled).returns(enabled)
    GayFurCity.config.stubs(:openobserve_endpoint).returns("https://openobserve.example.com")
    GayFurCity.config.stubs(:openobserve_organization).returns("default")
    GayFurCity.config.stubs(:openobserve_stream).returns("gayfurcity_exceptions")
    GayFurCity.config.stubs(:openobserve_username).returns("root@example.com")
    GayFurCity.config.stubs(:openobserve_password).returns("password")
  end

  context("disabled") do
    should("not make any request") do
      stub_config(enabled: false)
      OpenObserveReporter.report!(StandardError.new("boom"))

      assert_not_requested(:post, /openobserve\.example\.com/)
    end
  end

  context("enabled") do
    should("post the exception as a JSON document") do
      stub_config(enabled: true)
      request_stub = stub_request(:post, "https://openobserve.example.com/api/default/gayfurcity_exceptions/_json")
                     .with { |req| JSON.parse(req.body).first["exception"] == "StandardError" && JSON.parse(req.body).first["message"] == "boom" }

      OpenObserveReporter.report!(StandardError.new("boom"), source: "Test")

      assert_requested(request_stub)
    end

    should("not raise if the request fails") do
      stub_config(enabled: true)
      stub_request(:post, "https://openobserve.example.com/api/default/gayfurcity_exceptions/_json").to_timeout

      assert_nothing_raised do
        OpenObserveReporter.report!(StandardError.new("boom"))
      end
    end
  end
end

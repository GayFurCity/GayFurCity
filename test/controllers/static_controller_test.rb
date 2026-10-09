# frozen_string_literal: true

require("test_helper")

class StaticControllerTest < ActionDispatch::IntegrationTest
  context("The static controller") do
    context("the robots action") do
      should("render") do
        assert_nothing_raised { get(robots_path) }
      end
    end

    context("the browserconfig action") do
      should("use the site icons") do
        get("/browserconfig.xml")

        assert_response(:success)
        tile = Nokogiri::XML(response.body).at("msapplication tile")

        assert_equal(SiteAsset.file_url("ms-icon-150x150.png"), tile.at("square150x150logo")["src"])
        assert_equal("#222222", tile.at("TileColor").text)
      end
    end

    context("the manifest action") do
      should("use the configured app name") do
        AdminConfig.any_instance.stubs(:app_name).returns("Test Site")
        get("/manifest.json")

        assert_response(:success)
        assert_equal("Test Site", response.parsed_body["name"])
        assert_equal(6, response.parsed_body["icons"].length)
      end
    end
  end
end

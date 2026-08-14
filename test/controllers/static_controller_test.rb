# frozen_string_literal: true

require("test_helper")

class StaticControllerTest < ActionDispatch::IntegrationTest
  context("The static controller") do
    context("the robots action") do
      should("render") do
        assert_nothing_raised { get(robots_path) }
      end
    end
  end
end

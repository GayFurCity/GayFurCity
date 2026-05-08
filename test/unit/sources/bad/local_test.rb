# frozen_string_literal: true

require("test_helper")

module Sources
  module Bad
    class LocalTest < ActiveSupport::TestCase
      context("Local sources") do
        setup do
          @post1 = create(:post, source: GayFurCity.config.hostname)
          @post2 = create(:post, source: "#{GayFurCity.config.hostname}/posts/1")
          @post3 = create(:post, source: "#{GayFurCity.config.hostname}/artists/gaokun")
        end

        should("always be bad") do
          assert_equal(true, @post1.bad_source?)
          assert_equal(true, @post2.bad_source?)
          assert_equal(true, @post3.bad_source?)
        end
      end
    end
  end
end

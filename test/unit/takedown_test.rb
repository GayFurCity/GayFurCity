# frozen_string_literal: true

require("test_helper")

class TakedownTest < ActiveSupport::TestCase
  context("matching_post_ids") do
    should("accept ids and links to this site") do
      # the digit in the domain would otherwise be picked up as an id
      GayFurCity.config.stubs(:domain).returns("site2.test")

      assert_equal([5, 6, 7], Takedown.new.matching_post_ids("5 https://site2.test/posts/6 http://site2.test/posts/7"))
    end
  end
end

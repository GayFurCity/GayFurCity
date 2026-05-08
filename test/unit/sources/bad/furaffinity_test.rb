# frozen_string_literal: true

require("test_helper")

module Sources
  module Bad
    class FuraffinityTest < ActiveSupport::TestCase
      context("Furaffinity sources") do
        setup do
          @post1 = create(:post, source: "https://www.furaffinity.net/user/gaokun")
          @post2 = create(:post, source: "https://www.furaffinity.net/gallery/gaokun")
          @post3 = create(:post, source: "https://d.furaffinity.net/art/gaokun/1472453307/1472453307.gaokun_gaydog.png")
          @post4 = create(:post, source: "https://furaffinity.net/view/20990406")
          @post5 = create(:post, source: "https://www.furaffinity.net/user/gaokun\nhttps://www.furaffinity.net/view/20990406")
          @post6 = create(:post, source: "https://www.furaffinity.net/user/gaokun\nhttps://www.furaffinity.net/view/20990406\nhttps://d.furaffinity.net/art/gaokun/1472453307/1472453307.gaokun_gaydog.png")
        end

        should("be bad if only a user link is provided") do
          assert_predicate(@post1, :bad_source?)
        end

        should("be bad if only a gallery link is provided") do
          assert_predicate(@post2, :bad_source?)
        end

        should("be bad if only a direct link is provided") do
          assert_predicate(@post3, :bad_source?)
        end

        should("not be bad if a submission link is provided") do
          assert_not(@post4.bad_source?)
        end

        should("not be bad if a submission link is provided with a user link") do
          assert_not(@post5.bad_source?)
        end

        should("not be bad if a submission link is provided with a user link and direct link") do
          assert_not(@post6.bad_source?)
        end
      end
    end
  end
end

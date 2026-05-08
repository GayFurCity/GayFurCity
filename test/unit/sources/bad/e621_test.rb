# frozen_string_literal: true

require("test_helper")

module Sources
  module Bad
    class E621Test < ActiveSupport::TestCase
      context("E621 sources") do
        setup do
          stub_request(:get, "https://e621.net/posts.json?md5=b919c42410b3e90a3dd2667612ccebc2").to_return(status: 200, body: %({"post":{"id":3242510}}), headers: {})
          stub_request(:get, "https://e621.net/posts.json?md5=00000000000000000000000000000000").to_return(status: 404, body: %({}), headers: {})
          @post1 = create(:post, source: "https://static1.e621.net/data/00/00/00000000000000000000000000000000.png")
          @post2 = create(:post, source: "https://static1.e926.net/data/00/00/00000000000000000000000000000000.png")
          @post3 = create(:post, source: "https://e621.net/posts/3242510")
          @post4 = create(:post, source: "https://e926.net/posts/3242510")
          @post5 = create(:post, source: "https://e621.net/posts/3242510\nhttps://static1.e926.net/data/b9/19/b919c42410b3e90a3dd2667612ccebc2.png")
          @post6 = create(:post, source: "https://e621.net/artists/gaokun")
        end

        should("be bad if only a direct link is provided (e621)") do
          assert_predicate(@post1, :bad_source?)
        end

        should("be bad if only a direct link is provided (e926)") do
          assert_predicate(@post2, :bad_source?)
        end

        should("not be bad if a post link is provided (e621)") do
          assert_not(@post3.bad_source?)
        end

        should("not be bad if a post link is provided (e926)") do
          assert_not(@post4.bad_source?)
        end

        should("not be bad if both a post link and a direct link is provided") do
          assert_not(@post5.bad_source?)
        end

        should("be bad if only an other link is provided") do
          assert_predicate(@post6, :bad_source?)
        end
      end
    end
  end
end

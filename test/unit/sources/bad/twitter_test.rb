# frozen_string_literal: true

require("test_helper")

module Sources
  module Bad
    class TwitterTest < ActiveSupport::TestCase
      context("Twitter sources") do
        setup do
          @post1 = create(:post, source: "https://x.com/Gaokunx3")
          @post2 = create(:post, source: "https://x.com/Gaokunx3/status/1408869837489704967")
          @post3 = create(:post, source: "https://x.com/i/web/status/1408869837489704967")
          @post4 = create(:post, source: "https://pbs.twimg.com/media/E41PpSFWUAE9qnO?format=jpg&name=orig")
          @post5 = create(:post, source: "https://x.com/intent/user?user_id=604636622")
          @post6 = create(:post, source: "https://x.com/intent/user?screen_name=Gaokunx3")
        end

        should("be bad if only a profile link is provided") do
          assert_predicate(@post1, :bad_source?)
        end

        should("not be bad if only a tweet link is provided") do
          assert_not(@post2.bad_source?)
        end

        should("not be bad if only an intent link is provided") do
          assert_not(@post3.bad_source?)
        end

        should("be bad if a direct link is provided") do
          assert_predicate(@post4, :bad_source?)
        end

        should("be bad if a only a user intent link is provided (user_id)") do
          assert_predicate(@post5, :bad_source?)
        end

        should("be bad if a only a user intent link is provided (screen_name)") do
          assert_predicate(@post6, :bad_source?)
        end
      end
    end
  end
end

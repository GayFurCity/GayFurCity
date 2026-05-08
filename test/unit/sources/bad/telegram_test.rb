# frozen_string_literal: true

require("test_helper")

module Sources
  module Bad
    class TelegramTest < ActiveSupport::TestCase
      context("Telegram sources") do
        setup do
          @post1 = create(:post, source: "https://t.me/hajnalskiart\nhttps://telegram.me/hajnalskiart\nhttps://telegram.dog/hajnalskiart")
          @post2 = create(:post, source: "https://t.me/hajnalskiart/65\nhttps://telegram.me/hajnalskiart/65\nhttps://telegram.dog/hajnalskiart/65")
          @post3 = create(:post, source: "https://t.me/c/1278229598\nhttps://telegram.me/c/1278229598\nhttps://telegram.dog/c/1278229598")
          @post4 = create(:post, source: "https://t.me/c/1278229598/105\nhttps://telegram.me/c/1278229598/105\nhttps://telegram.dog/c/1278229598/105")
          @post5 = create(:post, source: "https://t.me/+17628675309")
          @post6 = create(:post, source: "https://t.me/joinchat/ABC123")
        end

        should("be bad if only a public channel link is provided") do
          assert_predicate(@post1, :bad_source?)
        end

        should("not be bad if a public message link is provided") do
          assert_not(@post2.bad_source?)
        end

        should("be bad if a private channel link is provided") do
          assert_predicate(@post3, :bad_source?)
        end

        should("be bad if only a private message link is provided") do
          assert_predicate(@post4, :bad_source?)
        end

        should("be bad if only a phone number link is provided") do
          assert_predicate(@post5, :bad_source?)
        end

        should("be bad if only a group link is provided") do
          assert_predicate(@post6, :bad_source?)
        end
      end
    end
  end
end

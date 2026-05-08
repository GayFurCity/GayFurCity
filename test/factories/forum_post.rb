# frozen_string_literal: true

FactoryBot.define do
  factory(:forum_post) do
    creator(factory: %i[old_user])
    topic { association(:forum_topic, creator: creator) }
    sequence(:body) { |n| "forum_post_body_#{n}" }
  end
end

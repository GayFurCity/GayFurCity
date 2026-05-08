# frozen_string_literal: true

FactoryBot.define do
  factory(:forum_topic_status) do
    user
    forum_topic
  end
end

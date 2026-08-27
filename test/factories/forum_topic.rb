# frozen_string_literal: true

FactoryBot.define do
  factory(:forum_topic) do
    creator(factory: %i[old_user])
    sequence(:title) { |n| "forum_topic_title_#{n}" }
    is_sticky { false }
    is_locked { false }
    category_id { AdminConfig.instance.alias_and_implication_forum_category }

    transient do
      sequence(:body) { |n| "forum_topic_body_#{n}" }
    end

    after(:build) do |topic, evaluator|
      topic.original_post ||= build(:forum_post, topic: topic, body: evaluator.body, creator: evaluator.creator)
    end

    before(:create) do |topic, evaluator|
      topic.original_post ||= build(:forum_post, topic: topic, body: evaluator.body, creator: evaluator.creator)
    end
  end
end

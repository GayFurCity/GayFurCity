#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative("base")

TOPIC = nil

users = User.where(level: User::Levels::MEMBER, forum_post_count: ..10).order(:id).limit(100)
topics = (TOPIC.nil? ? ForumTopic.order("RANDOM()") : ForumTopic.where(id: TOPIC).order(id: :asc)).limit(100)

TOPIC_COUNT = topics.count
TOTAL = 1000
STEP = (TOTAL * 0.1).to_i
EACH = (TOTAL / TOPIC_COUNT).to_i
RANGE = Range.new((EACH * 0.5).to_i, (EACH * 1.5).to_i) # 50% - 150%

ApplicationRecord.transaction do
  topics.find_each.with_index do |topic, i|
    puts("Creating posts.. #{i + 1}/#{TOPIC_COUNT}")
    users.sample(Random.rand(RANGE)).each do |user|
      topic.posts.create!(user: user.resolvable, body: 4.times.map { 4.times.map { Faker::Hacker.unique.say_something_smart }.join("\n") }.join("\n\n"))
    end
  end
end

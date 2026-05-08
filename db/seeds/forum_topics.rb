#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative("base")

CATEGORY = 2

users = User.where(level: User::Levels::MEMBER, forum_post_count: ..10).order(:id).limit(100)

TOTAL = 250
STEP = (TOTAL * 0.1).to_i

category = ForumCategory.find(CATEGORY)
ApplicationRecord.transaction do
  TOTAL.times do |i|
    Faker::UniqueGenerator.clear
    puts("Creating topics.. #{i + 1}/#{TOTAL}") if (i + 1) % STEP == 0 || (i + 1) == TOTAL
    user = users.sample
    category.topics.create!(creator: user.resolvable, title: "Topic #{i + 1}", original_post_attributes: { body: 4.times.map { 4.times.map { Faker::Hacker.unique.say_something_smart }.join("\n") }.join("\n\n") })
  end
end

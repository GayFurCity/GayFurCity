#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative("base")

users = User.where(level: User::Levels::MEMBER, forum_post_vote_count: ..10).order(:id).limit(50)

CATEGORY = 2
IP_ADDR = "127.0.0.1"
ApplicationRecord.transaction do
  posts = ForumCategory.find(CATEGORY).posts.joins(:topic).where("forum_topics.id": 100).where(allow_voting: true)
  total = posts.count
  posts.find_each.with_index do |post, i|
    puts("#{i + 1}/#{total}")
    users.each do |user|
      next if post.creator_id == user.id
      r = rand(1..100)
      score = if r.in?(1..65)
                1
              else
                r.in?(66..85) ? 0 : -1
              end
      post.votes.create!(user: user.resolvable, score: score)
    end
  end
end
puts("Done")

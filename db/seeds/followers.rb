#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative("base")

users = User.left_joins(:followed_tags).where("tag_followers.user_id": nil, "level": User::Levels::MEMBER).limit(1000).order("users.id asc")

total = users.count
MIN_FOLLOWS = 15
MAX_FOLLOWS = AdminConfig.get_user(:followed_tag_limit, User.new(level: User::Levels::MEMBER))
users.each_with_index do |user, i|
  count = rand(MIN_FOLLOWS..MAX_FOLLOWS)
  puts("Creating #{count} follows for #{user.name} (#{i + 1}/#{total})")
  documents = []
  Tag.where("post_count > 0").order("RANDOM()").limit(count).each do |tag|
    posts = Post.sql_raw_tag_match(tag.name).limit(50).pluck(:id)
    next if posts.empty?
    offset = rand(0..(posts.length - 1))
    # user.followed_tags.create!(tag: tag, last_post_id: posts[offset].id)
    documents << { tag_id: tag.id, last_post_id: posts[offset], user_id: user.id }
  end
  TagFollower.insert_all(documents)
  user.update_columns(followed_tag_count: TagFollower.for_user(user.id).count)
end
TagFollower.recount_all!

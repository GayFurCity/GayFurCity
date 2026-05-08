#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative("base")

users = User.where(level: User::Levels::MEMBER, favorite_count: ...1000).order(:id)

MIN_FAVORITES = 500
MAX_FAVORITES = Post.count
users.each_with_index do |user, i|
  count = rand(MIN_FAVORITES..MAX_FAVORITES)
  step = if count > 5000
           500
         else
           count > 1000 ? 250 : 100
         end
  puts("Creating #{count} favorites for #{user.name} (#{i + 1}/#{users.count})")
  favorites = []
  votes = []
  Post.select(:id, :fav_string, :vote_string).limit(count).order("RANDOM()").find_each.with_index do |post, ii|
    puts("  #{ii}/#{count}") if ii % step == 0
    fav = false
    vote = false
    unless post.is_favorited?(user)
      # Favorite.create(user: CurrentUser.user, post_id: post.id)
      favorites << { user_id: user.id, post_id: post.id }
      post.append_user_to_fav_string(user.id)
      fav = true
    end
    # FavoriteManager.add!(user: CurrentUser.user, post: post)
    # VoteManager::Posts.vote!(user: CurrentUser.user, ip_addr: CurrentUser.ip_addr,, post: post, score: rand(1..100) > 90 ? -1 : 1)
    unless post.is_voted?(user)
      score = rand(1..100) > 90 ? -1 : 1
      # PostVote.create(user: CurrentUser.user, score: score, post_id: post.id)
      votes << { user_id: user.resolvable, score: score, post_id: post.id }
      post.append_user_to_vote_string(user.id, score == -1 ? "down" : "up")
      vote = true
    end
    attr = {}
    attr.merge!({ fav_string: post.fav_string.strip, fav_count: post.fav_count }) if fav
    attr.merge!({ vote_string: post.vote_string.strip, up_score: post.up_score, down_score: post.down_score, score: post.score }) if vote
    post.update_columns(**attr)
  rescue ActiveRecord::RecordInvalid
    # ignore
  end
  Favorite.insert_all(favorites)
  PostVote.insert_all(votes)
  user.update_columns(favorite_count: Favorite.for_user(user.id).count)
  puts("  #{user.favorite_count}/#{count}")
end

Post.document_store.import # we ignored index updates for all posts, we must now update everything

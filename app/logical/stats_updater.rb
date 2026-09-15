# frozen_string_literal: true

module StatsUpdater
  module_function

  def run!
    user = User.system
    stats = {}
    stats[:started] = user.created_at

    daily_average = ->(total) do
      (total / ((Time.now - stats[:started]) / (60 * 60 * 24))).round
    end

    ### Posts ###

    stats[:total_posts] = Post.maximum("id") || 0
    stats[:active_posts] = Post.tag_match("status:active", user).count_only
    stats[:deleted_posts] = Post.tag_match("status:deleted", user).count_only
    stats[:existing_posts] = stats[:active_posts] + stats[:deleted_posts]
    stats[:destroyed_posts] = stats[:total_posts] - stats[:existing_posts]
    stats[:total_votes] = PostVote.count
    stats[:total_notes] = Note.count
    stats[:total_favorites] = Favorite.count
    stats[:total_pools] = Pool.count
    stats[:public_sets] = PostSet.where(is_public: true).count
    stats[:private_sets] = PostSet.where(is_public: false).count
    stats[:total_sets] = stats[:public_sets] + stats[:private_sets]

    stats[:average_posts_per_pool] = Pool.average(Arel.sql("cardinality(post_ids)")).to_i
    stats[:average_posts_per_set] = PostSet.average(Arel.sql("cardinality(post_ids)")).to_i

    stats[:safe_posts] = Post.tag_match("status:any rating:s", user).count_only
    stats[:questionable_posts] = Post.tag_match("status:any rating:q", user).count_only
    stats[:explicit_posts] = Post.tag_match("status:any rating:e", user).count_only
    stats[:jpg_posts] = Post.tag_match("status:any type:jpg", user).count_only
    stats[:png_posts] = Post.tag_match("status:any type:png", user).count_only
    stats[:gif_posts] = Post.tag_match("status:any type:gif", user).count_only
    stats[:webp_posts] = Post.tag_match("status:any type:webp", user).count_only
    stats[:webm_posts] = Post.tag_match("status:any type:webm", user).count_only
    stats[:mp4_posts] = Post.tag_match("status:any type:mp4", user).count_only
    sizes = Post.file_sizes
    stats[:total_file_size] = sizes[:total]
    stats[:posts_file_size] = sizes[:posts]
    stats[:variants_file_size] = sizes[:variants]
    stats[:average_file_size] = sizes[:average]
    stats[:average_posts_per_day] = daily_average.call(stats[:total_posts])

    ### Users ###

    stats[:total_users] = User.count
    User::Levels.hash.each do |name, level|
      stats[:"#{name.downcase}_users"] = User.where(level: level).count
    end
    stats[:unactivated_users] = User.email_not_verified.count
    stats[:total_dmails] = Dmail.maximum("id") || 0
    stats[:average_registrations_per_day] = daily_average.call(stats[:total_users])

    ### Comments ###

    stats[:total_comments] = Comment.maximum("id") || 0
    stats[:active_comments] = Comment.where(is_hidden: false).count
    stats[:hidden_comments] = Comment.where(is_hidden: true).count
    stats[:deleted_comments] = stats[:total_comments] - (stats[:active_comments] + stats[:hidden_comments])
    stats[:average_comments_per_day] = daily_average.call(stats[:total_comments])

    ### Forum posts ###

    stats[:total_forum_topics] = ForumTopic.count
    stats[:total_forum_posts] = ForumPost.maximum("id") || 0
    stats[:average_posts_per_topic] = stats[:total_forum_topics] == 0 ? 0 : (stats[:total_forum_posts] / stats[:total_forum_topics]).round
    stats[:average_forum_posts_per_day] = daily_average.call(stats[:total_forum_posts])

    ### Tags ###

    stats[:total_tags] = Tag.count
    TagCategory.category_names.each do |cat|
      stats[:"#{cat}_tags"] = Tag.where(category: TagCategory.mapping[cat]).count
    end
    stats
  end

  def get
    Cache.fetch("ffstats", expires_in: 1.day) do
      run!.as_json
    end
  end
end

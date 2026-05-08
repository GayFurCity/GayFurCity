# frozen_string_literal: true

module Recommender
  module_function

  MIN_POST_FAVS = 5
  MIN_USER_FAVS = 50

  def enabled?
    GayFurCity.config.recommender_server.present?
  end

  def available_for_post?(post)
    enabled? && post.fav_count > MIN_POST_FAVS
  end

  def available_for_user?(user)
    enabled? && user.favorite_count > MIN_USER_FAVS
  end

  def recommend_for_user(ruser, user:, tags: nil, limit: 50)
    response = Faraday.new(GayFurCity.config.faraday_options).get("#{GayFurCity.config.recommender_server}/recommend/#{ruser.id}?limit=#{limit}")
    return [] unless response.success?

    process_recs(JSON.parse(response.body), tags: tags, uploader: ruser, favoriter: ruser, user: user)
  end

  def recommend_for_post(post, user:, tags: nil, limit: 50)
    response = Faraday.new(GayFurCity.config.faraday_options).get("#{GayFurCity.config.recommender_server}/similar/#{post.id}?limit=#{limit}")
    return [] unless response.success?

    process_recs(JSON.parse(response.body), ogpost: post, tags: tags, user: user)
  end

  # factors: int
  # model_size: int
  # post_count: int
  # trained_at: string (date)
  # training_time: string (00:00:00)
  # user_count: int
  def metrics
    response = Faraday.new(GayFurCity.config.faraday_options).get("#{GayFurCity.config.recommender_server}/metrics")
    JSON.parse(response.body)
  end

  def train!
    return if Rails.env.test?
    Faraday.new(GayFurCity.config.faraday_options).put("#{GayFurCity.config.recommender_server}/train")
  end

  def process_recs(recs, user:, ogpost: nil, uploader: nil, favoriter: nil, tags: nil)
    posts = Post.where(id: recs.map(&:first))
    posts = posts.where.not(id: ogpost.id) if ogpost
    posts = posts.where.not(uploader_id: uploader.id) if uploader
    posts = posts.where.not(id: favoriter.favorites.select(:post_id)) if favoriter
    posts = posts.where(id: Post.tag_match_sql(tags, user).reorder(nil).select(:id)) if tags.present?

    id_to_score = recs.to_h
    recs = posts.map { |post| { score: id_to_score[post.id], post: post } }
    recs.sort_by { |rec| -rec[:score] }
  end

  def search(params, current_user)
    if params[:user_name].present?
      user = User.find(User.name_to_id(params[:user_name]))
    elsif params[:user_id].present?
      user = User.find(params[:user_id])
    elsif params[:post_id].present?
      post = Post.find(params[:post_id])
    end

    if user.present?
      raise(User::PrivacyModeError) if user.hide_favorites?(current_user)
      max_recommendations = params.fetch(:max_recommendations, user.favorite_count + 500).to_i.clamp(0, 50_000)
      recs = recommend_for_user(user, tags: params[:post_tags_match], limit: max_recommendations, user: current_user)
    elsif post.present?
      max_recommendations = params.fetch(:max_recommendations, 100).to_i.clamp(0, 1000)
      recs = recommend_for_post(post, tags: params[:post_tags_match], limit: max_recommendations, user: current_user)
    else
      recs = []
    end

    recs
  end
end

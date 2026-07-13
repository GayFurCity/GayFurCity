# frozen_string_literal: true

class FavoritesController < ApplicationController
  respond_to(:html, :json)
  before_action(:ensure_lockdown_disabled, except: %i[index])
  skip_before_action(:api_check)

  def index
    if params[:tags]
      authorize(Favorite)
      redirect_to(posts_path(tags: params[:tags]))
    else
      user_id = params[:user_id] || CurrentUser.user.id
      @user = User.find(user_id)
      authorize(@user, policy_class: FavoritePolicy)

      raise(User::PrivacyModeError) if @user.hide_favorites?(CurrentUser.user)

      @favorite_set = PostSets::Favorites.new(@user, params[:page], limit: params[:limit], current_user: CurrentUser.user)
      @favorite_set.load_view_counts! # force load view counts all at once
      respond_with(@favorite_set.posts) do |fmt|
        fmt.json do
          render(json: @favorite_set.api_posts)
        end
      end
    end
  end

  def create
    @post = authorize(Post.find(params[:post_id]), policy_class: FavoritePolicy)
    fav = FavoriteManager.add!(user: CurrentUser.user, post: @post)
    if params[:upvote].to_s.truthy?
      VoteManager::Posts.vote!(user: CurrentUser.user, ip_addr: CurrentUser.ip_addr, post: @post, score: 1)
      fav.reload
    end
    notice("You have favorited this post")

    respond_with(fav)
  rescue Favorite::Error, ActiveRecord::RecordInvalid => e
    render_expected_error(422, e.message)
  end

  def destroy
    @post = authorize(Post.find(params[:id]), policy_class: FavoritePolicy)
    FavoriteManager.remove!(user: CurrentUser.user, post: @post)

    notice("You have unfavorited this post")
    respond_with(@post)
  rescue Favorite::Error => e
    render_expected_error(422, e.message)
  end

  def clear
    authorize(Favorite)
    return if request.get? # will render the confirmation page
    if RateLimiter.check_limit("clear_favorites:#{CurrentUser.user.id}", 1, 7.days)
      return render_expected_error(429, "You can only clear your favorites once per week")
    end
    RateLimiter.hit("clear_favorites:#{CurrentUser.user.id}", 7.days)
    CurrentUser.user.clear_favorites
    respond_to do |format|
      format.html { redirect_to(favorites_path, notice: "Your favorites are being cleared. Give it some time if you have a lot") }
      format.json { head(:no_content) }
    end
  end

  def ensure_lockdown_disabled
    access_denied if Security::Lockdown.favorites_disabled? && !CurrentUser.user.is_staff?
  end
end

# frozen_string_literal: true

class PoolsController < ApplicationController
  before_action(:ensure_lockdown_disabled, except: %i[index show gallery])
  respond_to(:html, :json)

  def index
    @pools = authorize(Pool).search_current(search_params(Pool))
                            .paginate(params[:page], limit: params[:limit])
    respond_with(@pools) do |format|
      format.json do
        render(json: @pools.to_json)
        expires_in(params[:expiry].to_i.days) if params[:expiry]
      end
    end
  end

  def show
    @pool = authorize(Pool.find(params[:id]))
    respond_with(@pool) do |format|
      format.html do
        @posts = @pool.posts.includes(:media_asset).paginate_posts(params[:page], limit: params[:limit], total_count: @pool.post_ids.count, user: CurrentUser.user)
      end
    end
  end

  def new
    @pool = authorize(Pool.new_with_current(:creator, permitted_attributes(Pool)))
    respond_with(@pool)
  end

  def edit
    @pool = authorize(Pool.find(params[:id]))
    respond_with(@pool)
  end

  def gallery
    @pools = authorize(Pool).search_current(search_params(Pool))
                            .includes(cover_post: :media_asset)
                            .paginate_posts(params[:page], limit: params[:limit], user: CurrentUser.user)
  end

  def create
    @pool = authorize(Pool.new_with_current(:creator, permitted_attributes(Pool)))
    @pool.save
    notice(@pool.valid? ? "Pool created" : @pool.errors.full_messages.join("; "))
    respond_with(@pool)
  end

  def update
    @pool = authorize(Pool.find(params[:id]))
    @pool.update_with_current(:updater, permitted_attributes(@pool))
    notice(@pool.valid? ? "Pool updated" : @pool.errors.full_messages.join("; "))
    respond_with(@pool)
  end

  def destroy
    @pool = authorize(Pool.find(params[:id]))
    @pool.destroy_with_current(:destroyer)
    notice("Pool deleted")
    respond_with(@pool)
  end

  def revert
    @pool = authorize(Pool.find(params[:id]))
    @version = @pool.versions.find(params[:version_id])
    @pool.revert_to!(@version, CurrentUser.user)
    flash[:notice] = "Pool reverted"
    respond_with(@pool, &:js)
  end

  def clear_indexing
    @pool = authorize(Pool.find(params[:id]))
    @pool.update_column(:is_indexing, false)
    notice("Indexing notice cleared")
    respond_with(@pool, status: 200) do |format|
      format.html { redirect_back_or_to(pool_path(@pool)) }
    end
  end

  def ensure_lockdown_disabled
    access_denied if Security::Lockdown.pools_disabled? && !CurrentUser.user.is_staff?
  end
end

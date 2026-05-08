# frozen_string_literal: true

class PostSetsController < ApplicationController
  before_action(:ensure_lockdown_disabled, except: %i[index show])
  respond_to(:html, :json)

  def index
    authorize(PostSet)
    sp = search_params(PostSet)
    @post_sets = PostSet.visible(CurrentUser.user)
    if sp[:post_id].present?
      @post_sets = @post_sets.where_has_post(sp[:post_id].to_i)
    elsif sp[:maintainer_id].present?
      @post_sets = @post_sets.where_has_maintainer(sp[:maintainer_id].to_i)
    end

    @post_sets = @post_sets.html_includes(request, :creator)
                           .search_current(sp)
                           .paginate(params[:page], limit: params[:limit])

    respond_with(@post_sets)
  end

  def show
    @post_set = authorize(PostSet.find(params[:id]))

    respond_with(@post_set)
  end

  def new
    @post_set = authorize(PostSet.new_with_current(:creator, permitted_attributes(PostSet)))
  end

  def edit
    @post_set = authorize(PostSet.find(params[:id]))
    respond_with(@post_set)
  end

  def create
    @post_set = authorize(PostSet.new_with_current(:creator, permitted_attributes(PostSet)))
    @post_set.save
    notice(@post_set.valid? ? "Set created" : @post_set.errors.full_messages.join("; "))
    respond_with(@post_set)
  end

  def update
    @post_set = authorize(PostSet.find(params[:id]))
    @post_set.update_with_current(:updater, permitted_attributes(@post_set))
    notice(@post_set.valid? ? "Set updated" : @post_set.errors.full_messages.join("; "))
    respond_with(@post_set)
  end

  def maintainers
    @post_set = authorize(PostSet.find(params[:id]))
  end

  def post_list
    @post_set = authorize(PostSet.find(params[:id]))
  end

  def update_posts
    @post_set = authorize(PostSet.find(params[:id]))
    @post_set.update_with_current(:updater, update_posts_params)
    notice(@post_set.valid? ? "Set posts updated" : @post_set.errors.full_messages.join("; "))
    respond_with(@post_set, status: 200) do |format|
      format.html { redirect_back_or_to(post_list_post_set_path(@post_set)) }
    end
  end

  def destroy
    @post_set = authorize(PostSet.find(params[:id]))
    @post_set.destroy_with_current(:destroyer)
    respond_with(@post_set)
  end

  def for_select
    owned = authorize(PostSet).owned_by(CurrentUser.user).order(:name)
    maintained = PostSet.active_maintainer(CurrentUser.user).order(:name)

    @for_select = {
      "Owned"      => owned.map { |x| [x.name.tr("_", " ").truncate(35), x.id] },
      "Maintained" => maintained.map { |x| [x.name.tr("_", " ").truncate(35), x.id] },
    }

    render(json: @for_select)
  end

  def add_posts
    @post_set = authorize(PostSet.find(params[:id]))
    @post_set.add(add_remove_posts_params.map(&:to_i))
    @post_set.save
    respond_with(@post_set, status: 200)
  end

  def remove_posts
    @post_set = authorize(PostSet.find(params[:id]))
    @post_set.remove(add_remove_posts_params.map(&:to_i))
    @post_set.save
    respond_with(@post_set, status: 200)
  end

  private

  def update_posts_params
    (params.extract!(:post_ids_string).presence || params.require(:post_set)).permit(:post_ids_string)
  end

  def add_remove_posts_params
    (params.extract!(:post_ids).presence || params.require(:post_set)).permit(post_ids: []).require(:post_ids)
  end

  def ensure_lockdown_disabled
    access_denied if Security::Lockdown.post_sets_disabled? && !CurrentUser.user.is_staff?
  end
end

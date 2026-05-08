# frozen_string_literal: true

class TagsController < ApplicationController
  before_action(:load_tag, except: %i[index preview meta_search followed])
  respond_to(:html, :json)

  def index
    @tags = authorize(Tag).search_current(search_params(Tag))
                          .paginate(params[:page], limit: params[:limit])
    respond_with(@tags)
  end

  def preview
    authorize(Tag)
    @preview = TagsPreview.new(tags: params[:tags] || "")
    respond_to do |format|
      format.json do
        render(json: @preview.serializable_hash)
      end
    end
  end

  def meta_search
    authorize(Tag)
    @meta_search = MetaSearches::Tag.new(params)
    @meta_search.load_all
    respond_with(@meta_search)
  end

  def followed
    authorize(Tag)
    @user = User.find(params[:user_id] || CurrentUser.user.id)
    raise(User::PrivacyModeError) if @user.hide_followed_tags?(CurrentUser.user)

    @followed_tags = @user.followed_tags.includes(:tag)
                          .search_current(search_params(Tag))
                          .paginate(params[:page], limit: params[:limit])
    respond_with(@followed_tags.map(&:tag))
  end

  def followers
    @tag = authorize(Tag.find(params[:id]))
    query = User.joins(:followed_tags)
    unless CurrentUser.user.is_moderator?
      query = query.where.not_has_bits(bit_prefs: User::Preferences::ENABLE_PRIVACY_MODE).or(query.where("tag_followers.user_id": CurrentUser.user.id))
    end
    query = query.where("tag_followers.tag_id": @tag.id)
    query = query.order("users.name": :asc)
    @users = query.paginate(params[:page], limit: params[:limit])
    respond_with(@users)
  end

  def show
    authorize(@tag)
    respond_with(@tag)
  end

  def edit
    authorize(@tag)
    respond_with(@tag)
  end

  def update
    authorize(@tag)
    @tag.update_with_current(:updater, permitted_attributes(@tag))
    respond_with(@tag)
  end

  def correct
    authorize(Tag)
    @correction = TagCorrection.new(params[:id])
    @correction.fix!

    respond_to do |format|
      format.html { redirect_back_or_to(tags_path(search: { name_matches: @correction.tag.name, hide_empty: "no" }), notice: "Tag will be fixed in a few seconds") }
      format.json
    end
  end

  def follow
    @follower = authorize(@tag).follow!(CurrentUser.user)
    respond_with(@follower) do |format|
      format.html { redirect_back_or_to(tag_path(@tag), notice: "#{@tag.name} added to followed tags") }
    end
  rescue TagFollower::AliasedTagError
    respond_to do |format|
      format.html { redirect_back_or_to(tag_path(@tag), notice: "You cannot follow aliased tags") }
      format.json { render_expected_error(400, "You cannot follow aliased tags.") }
    end
  end

  def unfollow
    @follower = authorize(@tag).unfollow!(CurrentUser.user)
    respond_with(@follower) do |format|
      format.html { redirect_back_or_to(tag_path(@tag), notice: "#{@tag.name} removed from followed tags") }
    end
  end

  private

  def load_tag
    if params[:id] =~ /\A\d+\z/
      @tag = Tag.find(params[:id])
    else
      @tag = Tag.find_by!(name: params[:id])
    end
  end
end

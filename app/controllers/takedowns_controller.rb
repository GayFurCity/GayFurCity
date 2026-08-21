# frozen_string_literal: true

class TakedownsController < ApplicationController
  respond_to(:html, :json)
  before_action(:load_takedown, except: %i[index new create count_matching_posts])

  def index
    @takedowns = authorize(Takedown).search_current(search_params(Takedown))
                                    .paginate(params[:page], limit: params[:limit])
    respond_with(@takedowns)
  end

  def show
    authorize(@takedown)
    @show_instructions = (CurrentUser.ip_addr == @takedown.creator_ip_addr) || (@takedown.vericode == params[:code])
    respond_with(@takedown)
  end

  def new
    @takedown = authorize(Takedown.new_with_current(:creator, permitted_attributes(Takedown)))
    respond_with(@takedown)
  end

  def edit
    authorize(@takedown)
  end

  def create
    @takedown = authorize(Takedown.new_with_current(:creator, permitted_attributes(Takedown)))
    @takedown.save
    flash[:notice] = @takedown.errors.any? ? @takedown.errors.full_messages.join(". ") : "Takedown created"
    if @takedown.errors.any?
      respond_with(@takedown)
    else
      redirect_to(takedown_path(id: @takedown.id, code: @takedown.vericode))
    end
  end

  def update
    authorize(@takedown)
    @takedown.apply_posts(params[:takedown_posts])
    update_params = permitted_attributes(@takedown).slice(:notes, :reason_hidden, :status)

    if @takedown.update_with_current(:updater, update_params)
      flash[:notice] = "Takedown request updated"
      if params[:process_takedown].to_s.truthy?
        @takedown.process!(CurrentUser.user, params[:delete_reason])
      end
    end
    respond_with(@takedown)
  end

  def destroy
    authorize(@takedown).destroy_with_current(:destroyer)
    respond_with(@takedown)
  end

  def add_by_ids
    added = authorize(@takedown).add_posts_by_ids!(params[:post_ids], CurrentUser.user)
    respond_with(@takedown) do |fmt|
      fmt.json do
        render(json: { added_count: added.size, added_post_ids: added })
      end
    end
  end

  def add_by_tags
    added = authorize(@takedown).add_posts_by_tags!(params[:post_tags], CurrentUser.user)
    respond_with(@takedown) do |fmt|
      fmt.json do
        render(json: { added_count: added.size, added_post_ids: added })
      end
    end
  end

  def count_matching_posts
    authorize(Takedown)
    post_count = Post.tag_match_system(params[:post_tags]).count_only
    render(json: { matched_post_count: post_count })
  end

  def remove_by_ids
    authorize(@takedown).remove_posts_by_ids!(params[:post_ids], CurrentUser.user)
  end

  private

  def load_takedown
    @takedown = Takedown.find(params[:id])
  end
end

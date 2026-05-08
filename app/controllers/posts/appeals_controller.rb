# frozen_string_literal: true

module Posts
  class AppealsController < ApplicationController
    respond_to(:html, :json)

    def index
      @search_params = search_params(PostAppeal)
      @post_appeals = authorize(PostAppeal).html_includes(request, :creator, post: %i[appeals uploader approver])
                                           .search_current(@search_params)
                                           .paginate(params[:page], limit: params[:limit])
      respond_with(@post_appeals)
    end

    def show
      @post_appeal = authorize(PostAppeal.find(params[:id]))
      respond_with(@post_appeal) do |format|
        format.html { redirect_to(post_appeals_path(search: { id: @post_appeal.id })) }
      end
    end

    def new
      @post_appeal = authorize(PostAppeal.new_with_current(:creator, permitted_attributes(PostAppeal)))
      respond_with(@post_appeal)
    end

    def create
      @post_appeal = authorize(PostAppeal.new_with_current(:creator, permitted_attributes(PostAppeal)))
      @post_appeal.save
      notice(@post_appeal.errors.none? ? "Post appeal submitted" : @post_appeal.errors.full_messages.join("; "))
      respond_with(@post_appeal) do |format|
        format.html { redirect_to(post_path(@post_appeal.post)) }
      end
    end

    def destroy
      @post_appeal = authorize(PostAppeal.find(params[:id]))
      @post_appeal.reject!(CurrentUser.user)
      respond_with(@post_appeal) do |format|
        format.html do
          notice("Post appeal rejected")
          redirect_back_or_to(post_path(@post_appeal.post))
        end
      end
    end
  end
end

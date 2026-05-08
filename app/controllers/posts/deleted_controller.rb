# frozen_string_literal: true

module Posts
  class DeletedController < ApplicationController
    respond_to(:html, :json)

    def index
      authorize(Post, :deleted?)
      if params[:user_id].present?
        @user = User.find(params[:user_id])
        @posts = Post.includes(:uploader, :flags)
                     .where(is_deleted: true, uploader_id: @user.id)
                     .where.not("post_flags.id": nil)
                     .order("post_flags.created_at": :desc)
                     .paginate(params[:page], limit: params[:limit])
      else
        post_flags = PostFlag.includes(post: %i[uploader flags])
                             .where(is_deletion: true)
                             .order(id: :desc)
                             .paginate(params[:page], limit: params[:limit])
        new_opts = { pagination_mode: :numbered, records_per_page: post_flags.records_per_page, total_count: post_flags.total_count, current_page: post_flags.current_page }
        @posts = GayFurCity::Paginator::PaginatedArray.new(post_flags.map(&:post), new_opts)
      end
      respond_with(@posts)
    end
  end
end

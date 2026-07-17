# frozen_string_literal: true

module Posts
  class ReplacementsController < ApplicationController
    before_action(:ensure_uploads_enabled, only: %i[new create])
    respond_to(:html, :json)

    content_security_policy(only: %i[new]) do |p|
      p.img_src(:self, :data, :blob, "*")
      p.media_src(:self, :data, :blob, "*")
    end

    def index
      params[:search][:post_id] = params.delete(:post_id) if params.key?(:post_id)
      @post_replacements = authorize(PostReplacement).html_includes(request, :post, :creator)
                                                     .search_current(search_params(PostReplacement))
                                                     .paginate(params[:page], limit: params[:limit])

      respond_with(@post_replacements)
    end

    def new
      @post = Post.find(params[:post_id])
      @post_replacement = authorize(@post.replacements.new_with_current(:creator, permitted_attributes(PostReplacement)))
      respond_with(@post_replacement)
    end

    def create
      @post = Post.find(params[:post_id])
      @post_replacement = authorize(@post.replacements.new_with_current(:creator, permitted_attributes(PostReplacement)))
      @post_replacement.save
      if @post_replacement.media_asset.expunged?
        return render(json: { success: false, reason: "invalid", message: "That image #{@post_replacement.media_asset.status_message}" }, status: :precondition_failed)
      end
      if @post_replacement.errors.none?
        flash.now[:notice] = "Post replacement submitted"
      end
      # Posts being actively worked on (imports, etc.) get instant replacements - no approval
      # queue - regardless of who's replacing them or whether they can normally approve posts.
      if @post_replacement.pending? && (@post.is_in_progress? || (CurrentUser.user.can_approve_posts? && @post_replacement.as_pending.to_s.falsy?))
        @post_replacement.approve!(CurrentUser.user, penalize_current_uploader: @post_replacement.post.uploader != @post_replacement.creator)
      end
      respond_to do |format|
        format.json do
          return render(json: { success: false, message: @post_replacement.errors.full_messages.join("; ") }, status: :precondition_failed) if @post_replacement.errors.any?
          return render(json: { success: true, id: @post_replacement.id, media_asset_id: @post_replacement.media_asset_id }, status: :accepted) unless @post_replacement.is_direct?
          render(json: { success: true, location: post_path(@post), id: @post_replacement.id })
        end
      end
    end

    def approve
      @post_replacement = authorize(PostReplacement.find(params[:id]))
      @post_replacement.approve!(CurrentUser.user, penalize_current_uploader: params[:penalize_current_uploader])

      respond_with(@post_replacement, location: post_path(@post_replacement.post))
    end

    def toggle_penalize
      @post_replacement = authorize(PostReplacement.find(params[:id]))
      @post_replacement.toggle_penalize!(CurrentUser.user)

      respond_with(@post_replacement)
    end

    def reject
      @post_replacement = authorize(PostReplacement.find(params[:id]))
      if params[:commit] != "Cancel"
        @post_replacement.reject!(CurrentUser.user, params.dig(:post_replacement, :reason).presence || params[:reason].presence || "")
      end

      respond_with(@post_replacement, location: post_path(@post_replacement.post))
    end

    def reject_with_reason
      @post_replacement = authorize(PostReplacement.find(params[:id]))
      respond_with(@post_replacement)
    end

    def destroy
      @post_replacement = authorize(PostReplacement.find(params[:id]))
      @post_replacement.destroy_with_current(:destroyer)

      respond_with(@post_replacement, location: post_path(@post_replacement.post))
    end

    def promote
      @post_replacement = authorize(PostReplacement.find(params[:id]))
      @upload = @post_replacement.promote!(CurrentUser.user)
      if @post_replacement.errors.any?
        respond_with(@post_replacement)
      elsif @upload.errors.any?
        respond_with(@upload)
      else
        respond_with(@upload.post)
      end
    end

    private

    def check_allow_create
      return if CurrentUser.can_replace?

      raise(User::PrivilegeError, "You cannot create replacements")
    end

    def ensure_uploads_enabled
      access_denied if Security::Lockdown.uploads_disabled? || CurrentUser.user.level < Security::Lockdown.uploads_min_level
    end
  end
end

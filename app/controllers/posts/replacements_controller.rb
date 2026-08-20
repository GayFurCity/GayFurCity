# frozen_string_literal: true

module Posts
  class ReplacementsController < ApplicationController
    before_action(:ensure_replacements_enabled, only: %i[new create])
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
      # The timeline (shared rail + version dots) only reads correctly for a single
      # post's version history; a mixed list would jumble unrelated posts together.
      @timeline = single_post_search?

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
      @post_replacement.approve!(CurrentUser.user, penalize_current_uploader: params[:penalize_current_uploader], force_missing_backup: params[:force_missing_backup])

      if @post_replacement.errors.any?
        render(plain: "Replacement approval failed: #{@post_replacement.errors.full_messages.join('; ')}", status: :bad_request)
        return
      end

      respond_with(@post_replacement) do |format|
        format.html { render(partial: "card", locals: { post_replacement: @post_replacement, timeline: card_timeline? }) }
        format.json
      end
    end

    def toggle_penalize
      @post_replacement = authorize(PostReplacement.find(params[:id]))
      @post_replacement.toggle_penalize!(CurrentUser.user)

      respond_with(@post_replacement) do |format|
        format.html { render(partial: "card", locals: { post_replacement: @post_replacement, timeline: card_timeline? }) }
        format.json
      end
    end

    def reject
      @post_replacement = authorize(PostReplacement.find(params[:id]))
      if params[:commit] != "Cancel"
        @post_replacement.reject!(CurrentUser.user, params.dig(:post_replacement, :reason).presence || params[:reason].presence || "")
      end

      respond_with(@post_replacement) do |format|
        format.html { render(partial: "card", locals: { post_replacement: @post_replacement, timeline: card_timeline? }) }
        format.json
      end
    end

    def reject_with_reason
      @post_replacement = authorize(PostReplacement.find(params[:id]))
      respond_with(@post_replacement)
    end

    def transfer
      @post_replacement = authorize(PostReplacement.find(params[:id]))
      @post_replacement.transfer(Post.find(params[:new_post_id]), CurrentUser.user, force_missing_backup: params[:force_missing_backup])

      if @post_replacement.errors.any?
        message = @post_replacement.errors.full_messages.join("; ")
        respond_to do |format|
          format.html { render(plain: message, status: :precondition_failed) }
          format.json { render(json: { success: false, message: message }, status: :precondition_failed) }
        end
        return
      end

      respond_with(@post_replacement) do |format|
        format.html { render(partial: "card", locals: { post_replacement: @post_replacement, timeline: card_timeline? }) }
        format.json
      end
    end

    def destroy
      @post_replacement = authorize(PostReplacement.find(params[:id]))
      @post_replacement.destroy_with_current(:destroyer)

      respond_with(@post_replacement) do |format|
        format.html { head(:ok) }
        format.json
      end
    end

    def promote
      @post_replacement = authorize(PostReplacement.find(params[:id]))
      @upload = @post_replacement.promote!(CurrentUser.user)

      object_to_respond = if @post_replacement.errors.any?
                            @post_replacement
                          else
                            @upload.errors.any? ? @upload : @upload.post
                          end

      respond_with(object_to_respond) do |format|
        format.html do
          if @post_replacement.errors.any? || @upload.errors.any?
            head(:unprocessable_content)
          else
            render(partial: "card", locals: { post_replacement: @post_replacement, timeline: card_timeline? })
          end
        end
        format.json
      end
    end

    private

    # Timeline mode only makes sense scoped to one post's version history, i.e. when
    # search[post_id] holds a single id (the search supports a comma-separated list).
    def single_post_search?
      search_params(PostReplacement)[:post_id].to_s.match?(/\A\d+\z/)
    end

    # AJAX card re-renders carry the timeline context of the page they'll be swapped
    # into, so the fragment matches its neighbours (dot + rail, or a plain card).
    def card_timeline?
      ActiveModel::Type::Boolean.new.cast(params[:timeline])
    end

    def check_allow_create
      return if CurrentUser.can_replace?

      raise(User::PrivilegeError, "You cannot create replacements")
    end

    def ensure_replacements_enabled
      access_denied if Security::Lockdown.uploads_disabled? || Security::Lockdown.post_replacements_disabled? || CurrentUser.user.level < Security::Lockdown.uploads_min_level
    end
  end
end

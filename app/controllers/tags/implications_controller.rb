# frozen_string_literal: true

module Tags
  class ImplicationsController < ApplicationController
    respond_to(:html, :json)
    wrap_parameters(:tag_implication)
    before_action(:ensure_lockdown_disabled)

    def index
      @tag_implications = authorize(TagImplication).html_includes(request, :antecedent_tag, :consequent_tag, :approver, :creator)
                                                   .search_current(search_params(TagImplication))
                                                   .paginate(params[:page], limit: params[:limit])
      respond_with(@tag_implications)
    end

    def show
      @tag_implication = authorize(TagImplication.find(params[:id]))
      respond_with(@tag_implication)
    end

    def new
      @tag_implication = authorize(TagImplication.new_with_current(:creator))
    end

    def edit
      @tag_implication = authorize(TagImplication.find(params[:id]))
    end

    def create
      @tag_implication_request = authorize(TagImplicationRequest.new(**permitted_attributes(TagImplication).to_h.symbolize_keys, user: CurrentUser.user), policy_class: TagImplicationPolicy)
      @tag_implication_request.create

      if @tag_implication_request.invalid?
        respond_with(@tag_implication_request) do |format|
          format.html { redirect_back_or_to(new_tag_alias_path, notice: @tag_implication_request.errors.full_messages.join("; ")) }
        end
      elsif @tag_implication_request.forum_topic
        respond_with(@tag_implication_request.tag_relationship, location: forum_topic_path(@tag_implication_request.forum_topic, page: @tag_implication_request.tag_relationship.forum_post.forum_topic_page, anchor: "forum_post_#{@tag_implication_request.tag_relationship.forum_post_id}"))
      else
        respond_with(@tag_implication_request.tag_relationship)
      end
    end

    def update
      @tag_implication = authorize(TagImplication.find(params[:id]))

      if @tag_implication.is_pending? && @tag_implication.editable_by?(CurrentUser.user)
        @tag_implication.update_with_current(:updater, permitted_attributes(@tag_implication))
      end

      respond_with(@tag_implication)
    end

    def destroy
      @tag_implication = authorize(TagImplication.find(params[:id]))
      @tag_implication.reject!(CurrentUser.user)
      respond_with(@tag_implication) do |format|
        format.html do
          flash[:notice] = @tag_implication.errors.any? ? @tag_implication.errors.full_messages.join("; ") : "Tag implication was deleted"
          redirect_to(tag_implications_path)
        end
      end
    end

    def approve
      @tag_implication = authorize(TagImplication.find(params[:id]))
      @tag_implication.approve!(CurrentUser.user)
      respond_with(@tag_implication, location: tag_implication_path(@tag_implication))
    end

    private

    def ensure_lockdown_disabled
      access_denied if Security::Lockdown.aiburs_disabled? && !CurrentUser.user.is_staff?
    end
  end
end

# frozen_string_literal: true

module Moderator
  class UserTextVersionsController < ApplicationController
    respond_to(:html)

    def index
      @text_versions = authorize(UserTextVersion).html_includes(request, :user, :updater)
                                                 .search_current(search_params(UserTextVersion))
                                                 .paginate(params[:page], limit: params[:limit] || 20)
      respond_with(@text_versions)
    end

    def for_user
      @user = authorize(User.find(params[:user_id]), policy_class: UserTextVersionPolicy)
      @text_versions = @user.text_versions
                            .html_includes(request, :user, :updater)
                            .search_current(search_params(UserTextVersion))
                            .paginate(params[:page], limit: params[:limit] || 20)
      render(:index)
    end

    def show
      @text_version = authorize(UserTextVersion.find(params[:id]))
      respond_with(@text_version)
    end

    def diff
      if params[:otherversion].blank? || params[:thisversion].blank?
        redirect_back_or_to({ action: :index }, notice: "You must select two versions to diff")
        return
      end

      @otherversion = authorize(UserTextVersion.find(params[:otherversion]))
      @thisversion = authorize(UserTextVersion.find(params[:thisversion]))
      @user = @thisversion.user
      redirect_back_or_to({ action: :index }, notice: "You cannot diff two different users") if @otherversion.user_id != @thisversion.user_id
    end
  end
end

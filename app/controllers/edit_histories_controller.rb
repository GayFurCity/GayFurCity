# frozen_string_literal: true

class EditHistoriesController < ApplicationController
  respond_to(:html)

  def index
    @edit_histories = authorize(EditHistory).html_includes(request, :updater)
                                            .search_current(search_params(EditHistory))
                                            .paginate(params[:page], limit: params[:limit])
    respond_with(@edit_histories)
  end

  def show
    @edit_class = edit_class
    @id_param = id_param
    @edit_histories = authorize(EditHistory).html_includes(request, :updater)
                                            .where(versionable_id: params[@id_param], versionable_type: @edit_class)
    @original = @edit_histories.original
    @edit_histories = @edit_histories.order(id: :asc).paginate(params[:page], limit: params[:limit])
    @content_edits = @edit_histories.select(&:is_contentful?)
    respond_with(@edit_histories)
  end

  def diff
    if params[:otherversion].blank? || params[:thisversion].blank?
      redirect_back_or_to({ action: :index }, notice: "You must select two versions to diff")
      return
    end

    @otherversion = authorize(EditHistory.find(params[:otherversion]))
    @thisversion = authorize(EditHistory.find(params[:thisversion]))
    redirect_back_or_to({ action: :index }, notice: "You cannot diff different versionables") if @otherversion.versionable_type != @thisversion.versionable_type || @otherversion.versionable_id != @thisversion.versionable_id
  end

  private

  def edit_class
    if request.path.start_with?(comments_path)
      "Comment"
    elsif request.path.start_with?(forum_posts_path)
      "ForumPost"
    else
      value = params[:type].to_s
      if EditHistory::VERSIONABLE_TYPES.exclude?(value)
        raise(User::PrivilegeError, "Invalid versionable type: #{value}")
      end
      value
    end
  end

  def id_param
    case edit_class
    when "Comment"
      :comment_id
    when "ForumPost"
      :forum_post_id
    else
      :id
    end
  end
end

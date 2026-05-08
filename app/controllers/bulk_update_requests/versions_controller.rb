# frozen_string_literal: true

module BulkUpdateRequests
  class VersionsController < ApplicationController
    respond_to(:html, :json)

    def index
      if (bulk_update_request_id = params.dig(:search, :bulk_update_request_id)).present?
        @bulk_update_request = BulkUpdateRequest.find_by(id: bulk_update_request_id)
      end

      @bulk_update_request_versions = authorize(BulkUpdateRequestVersion).html_includes(request, :updater)
                                                                         .search_current(search_params(BulkUpdateRequestVersion))
                                                                         .paginate(params[:page], limit: params[:limit])
      respond_with(@bulk_update_request_versions)
    end

    def diff
      @bulk_update_request_version = authorize(BulkUpdateRequestVersion.find(params[:id]))
    end

    def undo
      @bulk_update_request_version = authorize(BulkUpdateRequestVersion.find(params[:id]))
      @bulk_update_request_version.undo!(CurrentUser.user)

      text = ""
      if @bulk_update_request_version.errors.any?
        text += @bulk_update_request_version.errors.full_messages.join(", ")
      elsif @bulk_update_request_version.bulk_update_request.errors.any?
        text += "; " if text.present?
        text += @bulk_update_request_version.bulk_update_request.errors.full_messages.join(", ")
      end

      return render_expected_error(422, text) if text.present?
      notice("Bulk update request version undone")
      respond_with(@bulk_update_request_version) do |format|
        format.html { redirect_back_or_to(bulk_update_request_versions_path) }
      end
    end
  end
end

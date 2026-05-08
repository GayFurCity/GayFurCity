# frozen_string_literal: true

module MediaAssets
  class StatusesController < ApplicationController
    respond_to(:html, :json)

    def show
      authorize(MediaAsset, :show_statuses?)
      PostFilesStatus.clear_cache if params[:refresh].to_s.truthy?
      if PostFilesStatus.cached?
        @status = PostFilesStatus.get_cached
      else
        @status = nil
      end
      respond_with(PostFilesStatus)
    end

    def update
      authorize(MediaAsset, :queue_statuses?)
      PostFilesStatus.queue
      respond_to do |format|
        format.html { redirect_back_or_to(media_asset_status_path) }
        format.json
      end
    end
  end
end

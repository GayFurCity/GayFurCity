# frozen_string_literal: true

module MediaAssets
  class BaseController < ApplicationController
    respond_to(:json)
    respond_to(:html, only: %i[index])

    def index
      @assets = authorize(asset_class).html_includes(request, :creator, :"#{asset_child_class.name.underscore}", (:post if asset_class == UploadMediaAsset))
                                      .search_current(search_params(asset_class))
                                      .paginate(params[:page], limit: params[:limit])
      respond_with(@assets)
    end

    def append
      @asset = authorize(asset_class.find(params[:id]))
      chunk_id = params.dig(asset_class.model_name.param_key, :chunk_id)
      data = params.dig(asset_class.model_name.param_key, :data)
      return render_expected_error(422, "Invalid data") if chunk_id.nil? || data.nil?
      @asset.append_chunk!(chunk_id.to_i, data)
      return render_expected_error(422, "#{@asset.status}: #{@asset.status_message}") if @asset.failed?
      respond_with(@asset)
    end

    def cancel
      @asset = authorize(asset_class.find(params[:id]))
      @asset.cancel!
      respond_with(@asset) do |format|
        format.html { redirect_back_or_to(send("#{asset_class.model_name.route_key}_path"), notice: "Upload canceled") }
      end
    end

    protected

    def asset_class
      raise
    end

    def asset_child_class
      asset_class.name.gsub("MediaAsset", "").constantize
    end
  end
end

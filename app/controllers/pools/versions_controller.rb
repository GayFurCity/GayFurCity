# frozen_string_literal: true

module Pools
  class VersionsController < ApplicationController
    respond_to(:html, :json)

    def index
      if (pool_id = params.dig(:search, :pool_id)).present?
        @pool = Pool.find_by(id: pool_id)
      end

      @pool_versions = authorize(PoolVersion).html_includes(request, :updater)
                                             .search_current(search_params(PoolVersion))
                                             .paginate(params[:page], limit: params[:limit])
      respond_with(@pool_versions)
    end

    def diff
      @pool_version = authorize(PoolVersion.find(params[:id]))
    end

    def undo
      @pool_version = authorize(PoolVersion.find(params[:id]))
      @pool_version.undo!(CurrentUser.user)

      text = ""
      if @pool_version.errors.any?
        text += @pool_version.errors.full_messages.join(", ")
      elsif @pool_version.pool.errors.any?
        text += "; " if text.present?
        text += @pool_version.pool.errors.full_messages.join(", ")
      end

      return render_expected_error(422, text) if text.present?
      notice("Pool version undone")
      respond_with(@pool_version) do |format|
        format.html { redirect_back_or_to(pool_versions_path) }
      end
    end
  end
end

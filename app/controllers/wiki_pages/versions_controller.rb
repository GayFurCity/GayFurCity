# frozen_string_literal: true

module WikiPages
  class VersionsController < ApplicationController
    respond_to(:html, :json)

    def index
      @wiki_page_versions = authorize(WikiPageVersion).html_includes(request, :updater)
                                                      .search_current(search_params(WikiPageVersion))
                                                      .paginate(params[:page], limit: params[:limit])
      respond_with(@wiki_page_versions)
    end

    def show
      @wiki_page_version = authorize(WikiPageVersion.find(params[:id]))
      respond_with(@wiki_page_version)
    end

    def diff
      if params[:thispage].blank? || params[:otherpage].blank?
        redirect_back_or_to(wiki_pages_path, notice: "You must select two versions to diff")
        return
      end

      @thispage = authorize(WikiPageVersion.find(params[:thispage]))
      @otherpage = authorize(WikiPageVersion.find(params[:otherpage]))
    end
  end
end

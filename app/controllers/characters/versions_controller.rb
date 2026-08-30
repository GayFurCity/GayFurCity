# frozen_string_literal: true

module Characters
  class VersionsController < ApplicationController
    respond_to(:html, :json)

    def index
      @character_versions = authorize(CharacterVersion).html_includes(request, :updater, character: :wiki_page).search_current(search_params(CharacterVersion)).paginate(params[:page], limit: params[:limit])
      respond_with(@character_versions)
    end
  end
end

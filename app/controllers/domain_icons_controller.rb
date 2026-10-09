# frozen_string_literal: true

class DomainIconsController < ApplicationController
  respond_to(:html, :json)
  before_action(:load_domain_icon, only: %i[edit update destroy])

  def index
    @domain_icons = authorize(DomainIcon).with_assets
                                         .search_current(search_params(DomainIcon))
                                         .paginate(params[:page], limit: params[:limit])
    respond_with(@domain_icons)
  end

  def new
    @domain_icon = authorize(DomainIcon.new_with_current(:creator, permitted_attributes(DomainIcon)))
  end

  def edit
    authorize(@domain_icon)
  end

  def create
    @domain_icon = authorize(DomainIcon.new_with_current(:creator, permitted_attributes(DomainIcon)))
    @domain_icon.save
    respond_with(@domain_icon, location: domain_icons_path)
  end

  def update
    authorize(@domain_icon)
    @domain_icon.update_with_current(:updater, permitted_attributes(@domain_icon))
    respond_with(@domain_icon, location: domain_icons_path)
  end

  def destroy
    authorize(@domain_icon)
    @domain_icon.destroy_with_current(:destroyer)
    respond_with(@domain_icon, location: domain_icons_path)
  end

  private

  def load_domain_icon
    @domain_icon = DomainIcon.find(params[:id])
  end
end

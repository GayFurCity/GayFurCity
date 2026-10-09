# frozen_string_literal: true

class SiteAssetsController < ApplicationController
  respond_to(:html, :json)
  skip_before_action(:check_valid_username, only: %i[file])

  def index
    authorize(SiteAsset)
    @site_assets = SiteAsset.includes(:site_media_asset, :creator, :updater).index_by(&:name)
    respond_with(@site_assets.values)
  end

  def update
    raise(ActiveRecord::RecordNotFound) unless SiteAsset::SLOTS.key?(params[:name])
    @site_asset = SiteAsset.find_or_initialize_by(name: params[:name])
    authorize(@site_asset)
    if @site_asset.new_record?
      @site_asset = SiteAsset.new_with_current(:creator, { name: params[:name] }, permitted_attributes(@site_asset))
      @site_asset.save
    else
      @site_asset.update_with_current(:updater, permitted_attributes(@site_asset))
    end
    flash[:notice] = @site_asset.errors.any? ? @site_asset.errors.full_messages.join("; ") : "#{@site_asset.slot.title} updated"
    respond_with(@site_asset) do |format|
      format.html { redirect_to(site_assets_path) }
    end
  end

  def destroy
    @site_asset = authorize(SiteAsset.find_by!(name: params[:name]))
    @site_asset.destroy_with_current(:destroyer)
    flash[:notice] = "#{@site_asset.slot.title} reset to the default"
    respond_with(@site_asset) do |format|
      format.html { redirect_to(site_assets_path) }
    end
  end

  # Public files like /favicon.ico, redirects to the uploaded version or the default
  def file
    expires_in(1.hour, public: true)
    redirect_to(SiteAsset.file_url(params[:file]), allow_other_host: true)
  end
end

# frozen_string_literal: true

module SiteAssetsHelper
  def site_asset_url(file)
    SiteAsset.file_url(file)
  end

  def site_logo_url
    SiteAsset.url_for("icon", "png_512") || image_pack_path("main-icon.png")
  end

  def site_logo_size
    SiteAsset.url_for("icon", "png_512") ? 512 : 710
  end
end

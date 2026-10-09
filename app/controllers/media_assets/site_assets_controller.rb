# frozen_string_literal: true

module MediaAssets
  class SiteAssetsController < BaseController
    undef_method(:append)
    undef_method(:cancel)

    protected

    def asset_class
      SiteMediaAsset
    end
  end
end

# frozen_string_literal: true

module MediaAssets
  class DomainIconsController < BaseController
    undef_method(:append)
    undef_method(:cancel)

    protected

    def asset_class
      DomainIconMediaAsset
    end
  end
end

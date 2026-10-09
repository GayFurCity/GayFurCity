# frozen_string_literal: true

require("test_helper")

module MediaAssets
  class SiteAssetsControllerTest < ActionDispatch::IntegrationTest
    context("The site media assets controller") do
      setup do
        @owner = create(:owner_user)
        @media_asset = create(:site_media_asset, creator: @owner)
      end

      context("index action") do
        should("list media assets") do
          get_auth(site_media_assets_path, @owner)

          assert_response(:success)
          assert_select("#site-media-asset-#{@media_asset.id}", count: 1)
        end

        should("list the variants") do
          media_asset = create(:site_asset, creator: @owner).site_media_asset
          get_auth(site_media_assets_path, @owner)

          assert_select("#site-media-asset-#{media_asset.id} a", text: "png_16", count: 1)
          assert_select("#site-media-asset-#{media_asset.id} a", text: "ico", count: 1)
        end

        context("access control") do
          asserts do
            access.gte(User::Levels::OWNER).get(site_media_assets_path)
            access.gte(User::Levels::OWNER).json.get(site_media_assets_path)
          end
        end
      end
    end
  end
end

# frozen_string_literal: true

require("test_helper")

module MediaAssets
  class DomainIconsControllerTest < ActionDispatch::IntegrationTest
    context("The domain icon media assets controller") do
      setup do
        @janitor = create(:janitor_user)
        @media_asset = create(:domain_icon_media_asset)
      end

      context("index action") do
        should("list media assets for staff") do
          get_auth(domain_icon_media_assets_path, @janitor)

          assert_response(:success)
          assert_select("#domain-icon-media-asset-#{@media_asset.id}", count: 1)
        end

        context("access control") do
          asserts do
            access.gte(User::Levels::MEMBER).get(domain_icon_media_assets_path)
            access.gte(User::Levels::MEMBER).json.get(domain_icon_media_assets_path)
          end
        end
      end
    end
  end
end

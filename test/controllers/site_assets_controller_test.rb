# frozen_string_literal: true

require("test_helper")

class SiteAssetsControllerTest < ActionDispatch::IntegrationTest
  context("The site assets controller") do
    setup do
      @owner = create(:owner_user)
    end

    context("index action") do
      should("render") do
        create(:site_asset, creator: @owner)
        get_auth(site_assets_path, @owner)

        assert_response(:success)
      end

      context("access control") do
        asserts do
          access.gte(User::Levels::OWNER).get(site_assets_path)
        end
      end
    end

    context("update action") do
      should("upload a new asset") do
        assert_difference(-> { SiteAsset.count } => 1, -> { ModAction.where(action: "site_asset_create").count } => 1) do
          put_auth(site_asset_path("icon"), @owner, params: { site_asset: { file: fixture_file_upload("test-square.png") } })
        end

        assert_redirected_to(site_assets_path)
        assert_predicate(SiteAsset.find_by(name: "icon").site_media_asset, :active?)
      end

      should("replace an existing asset") do
        asset = create(:site_asset, creator: @owner)

        assert_difference(-> { ModAction.where(action: "site_asset_update").count } => 1) do
          put_auth(site_asset_path("icon"), @owner, params: { site_asset: { file: fixture_file_upload("test-square-568.png") } })
        end

        assert_equal(568, asset.reload.site_media_asset.image_width)
      end

      should("show errors for invalid files") do
        put_auth(site_asset_path("icon"), @owner, params: { site_asset: { file: fixture_file_upload("test.png") } })

        assert_redirected_to(site_assets_path)
        assert_match("must be square", flash[:notice])
        assert_not(SiteAsset.exists?(name: "icon"))
      end

      should("404 for unknown names") do
        put_auth(site_asset_path("nope"), @owner, params: { site_asset: { file: fixture_file_upload("test-square.png") } })

        assert_response(:not_found)
      end

      context("access control") do
        asserts do
          access.gte(User::Levels::OWNER).put { site_asset_path("icon") }.params { { site_asset: { file: fixture_file_upload("test-square.png") } } }.success(:redirect)
        end
      end
    end

    context("destroy action") do
      setup do
        @asset = create(:site_asset, creator: @owner)
      end

      should("reset to the default") do
        assert_difference(-> { SiteAsset.count } => -1, -> { ModAction.where(action: "site_asset_delete").count } => 1) do
          delete_auth(site_asset_path("icon"), @owner)
        end

        assert_redirected_to(site_assets_path)
      end

      context("access control") do
        asserts do
          access.gte(User::Levels::OWNER).delete { site_asset_path("icon") }.success(:redirect)
        end
      end
    end

    context("file action") do
      should("redirect to the default file") do
        get("/favicon.ico")

        assert_redirected_to("/images/main-icon.png")
      end

      should("redirect to the uploaded file") do
        create(:site_asset, creator: @owner)
        get("/apple-icon-57x57.png")

        assert_response(:redirect)
        assert_match(/_png_57\.png\z/, response.location)
      end

      should("not match other files") do
        get("/favicon-17x17.png")

        assert_response(:not_found)
      end
    end
  end
end

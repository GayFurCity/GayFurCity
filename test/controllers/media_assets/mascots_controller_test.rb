# frozen_string_literal: true

require("test_helper")

module MediaAssets
  class MascotsControllerTest < ActionDispatch::IntegrationTest
    context("The mascot media assets controller") do
      setup do
        @user = create(:user, created_at: 2.weeks.ago)
        @user2 = create(:user)
        @janitor = create(:janitor_user)
        @media_asset = create(:jpg_mascot_media_asset, creator: @user)
      end

      context("index action") do
        should("render") do
          get_auth(mascot_media_assets_path, @user)

          assert_response(:success)
        end

        should("list created media assets") do
          get_auth(mascot_media_assets_path, @user)

          assert_response(:success)
          assert_select("#mascot-media-asset-#{@media_asset.id}", count: 1)
        end

        should("list all media assets for staff") do
          get_auth(mascot_media_assets_path, @janitor)

          assert_response(:success)
          assert_select("#mascot-media-asset-#{@media_asset.id}", count: 1)
        end

        should("not list media assets created by others") do
          get_auth(mascot_media_assets_path, @user2)

          assert_response(:success)
          assert_select("#mascot-media-asset-#{@media_asset.id}", count: 0)
        end

        should("restrict access") do
          assert_access(User::Levels::MEMBER) { |user| get_auth(mascot_media_assets_path, user) }
        end

        context("search parameters") do
          subject { mascot_media_assets_path }
          setup do
            MascotMediaAsset.delete_all
            @janitor = create(:janitor_user)
            @creator = create(:user)
            @admin = create(:admin_user)
            @mascot = create(:mascot, creator: @creator, creator_ip_addr: "127.0.0.2")
            @media_asset = @mascot.media_asset
            @media_asset.update(status_message: "foo")
          end

          assert_search_param(:checksum, "ecef68c44edb8a0d6a3070b5f8e8ee76", -> { [@media_asset] }, -> { @janitor })
          assert_search_param(:md5, "ecef68c44edb8a0d6a3070b5f8e8ee76", -> { [@media_asset] }, -> { @janitor })
          assert_search_param(:file_ext, "jpg", -> { [@media_asset] }, -> { @janitor })
          assert_search_param(:pixel_hash, "01cb481ec7730b7cfced57ffa5abd196", -> { [@media_asset] }, -> { @janitor })
          assert_search_param(:status, "active", -> { [@media_asset] }, -> { @janitor })
          assert_search_param(:status_message_matches, "foo", -> { [@media_asset] }, -> { @janitor })
          assert_search_param(:mascot_id, -> { @mascot.id }, -> { [@media_asset] }, -> { @janitor })
          assert_search_param(:creator_id, -> { @creator.id }, -> { [@media_asset] }, -> { @janitor })
          assert_search_param(:creator_name, -> { @creator.name }, -> { [@media_asset] }, -> { @janitor })
          assert_search_param(:ip_addr, "127.0.0.2", -> { [@media_asset] }, -> { @admin })
          assert_shared_search_params(-> { [@media_asset] }, -> { @janitor })
        end
      end
    end
  end
end

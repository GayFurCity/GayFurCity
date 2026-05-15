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

        context("access control") do
          asserts do
            access.gte(User::Levels::MEMBER).get(mascot_media_assets_path)
            access.gte(User::Levels::MEMBER).json.get(mascot_media_assets_path)
          end
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

          asserts do
            search(:checksum, "ecef68c44edb8a0d6a3070b5f8e8ee76").records { [@media_asset] }.user { @janitor }
            search(:md5, "ecef68c44edb8a0d6a3070b5f8e8ee76").records { [@media_asset] }.user { @janitor }
            search(:file_ext, "jpg").records { [@media_asset] }.user { @janitor }
            search(:pixel_hash, "01cb481ec7730b7cfced57ffa5abd196").records { [@media_asset] }.user { @janitor }
            search(:status, "active").records { [@media_asset] }.user { @janitor }
            search(:status_message_matches, "foo").records { [@media_asset] }.user { @janitor }
            search(:mascot_id).value { @mascot.id }.records { [@media_asset] }.user { @janitor }
            search(:creator_id).value { @creator.id }.records { [@media_asset] }.user { @janitor }
            search(:creator_name).value { @creator.name }.records { [@media_asset] }.user { @janitor }
            search(:ip_addr, "127.0.0.2").records { [@media_asset] }.user { @admin }
            search.shared.records { [@media_asset] }.user { @janitor }
          end
        end
      end
    end
  end
end

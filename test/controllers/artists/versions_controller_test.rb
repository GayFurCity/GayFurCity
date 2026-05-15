# frozen_string_literal: true

require("test_helper")

module Artists
  class VersionsControllerTest < ActionDispatch::IntegrationTest
    context("An artist versions controller") do
      setup do
        @user = create(:trusted_user)
        @artist = create(:artist, creator: @user)
      end

      should("get the index page") do
        get_auth(artist_versions_path, @user)

        assert_response(:success)
      end

      should("get the index page when searching for something") do
        get_auth(artist_versions_path(search: { artist_name: @artist.name }), @user)

        assert_response(:success)
      end

      context("access control") do
        asserts do
          access.gte(User::Levels::ANONYMOUS).get(artist_versions_path)
          access.gte(User::Levels::ANONYMOUS).json.get(artist_versions_path)
        end
      end

      context("search parameters") do
        subject { artist_versions_path }
        setup do
          ArtistUrl.delete_all
          ArtistVersion.delete_all
          Artist.delete_all
          @updater = create(:user)
          @admin = create(:admin_user)
          @artist = create(:artist, updater: @updater, updater_ip_addr: "127.0.0.2")
          @artist_version = @artist.versions.first
        end

        asserts do
          search(:artist_id).value { @artist.id }.records { [@artist_version] }
          search(:artist_name).value { @artist.name }.records { [@artist_version] }
          search(:updater_id).value { @updater.id }.records { [@artist_version] }
          search(:updater_name).value { @updater.name }.records { [@artist_version] }
          search(:ip_addr, "127.0.0.2").records { [@artist_version] }.user { @admin }
          search.shared.records { [@artist_version] }
        end
      end
    end
  end
end

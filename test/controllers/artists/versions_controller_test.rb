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

      should("restrict access") do
        assert_access(User::Levels::ANONYMOUS) { |user| get_auth(artist_versions_path, user) }
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

        assert_search_param(:artist_id, -> { @artist.id }, -> { [@artist_version] })
        assert_search_param(:artist_name, -> { @artist.name }, -> { [@artist_version] })
        assert_search_param(:artist_name, -> { @artist.name }, -> { [@artist_version] })
        assert_search_param(:updater_id, -> { @updater.id }, -> { [@artist_version] })
        assert_search_param(:updater_name, -> { @updater.name }, -> { [@artist_version] })
        assert_search_param(:ip_addr, "127.0.0.2", -> { [@artist_version] }, -> { @admin })
        assert_shared_search_params(-> { [@artist_version] })
      end
    end
  end
end

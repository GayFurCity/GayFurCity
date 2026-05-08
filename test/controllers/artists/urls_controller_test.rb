# frozen_string_literal: true

require("test_helper")

module Artists
  class UrlsControllerTest < ActionDispatch::IntegrationTest
    context("The artist urls controller") do
      context("index page") do
        should("render") do
          get(artist_urls_path)

          assert_response(:success)
        end

        should("render for a complex search") do
          @user = create(:user)
          @artist = create(:artist, name: "bkub", url_string: "-http://bkub.com", creator: @user)

          get(artist_urls_path(search: {
            artist_name: "bkub",
            url_matches: "*bkub*",
            is_active:   "false",
            order:       "created_at",
          }))

          assert_response(:success)
        end

        should("restrict access") do
          assert_access(User::Levels::ANONYMOUS) { |user| get_auth(artist_urls_path, user) }
        end

        context("search parameters") do
          subject { artist_urls_path }
          setup do
            ArtistUrl.delete_all
            ArtistVersion.delete_all
            Artist.delete_all
            @user = create(:user)
            @artist = create(:artist, url_string: "https://google.com")
            @artist_url = @artist.urls.first
          end

          assert_search_param(:artist_id, -> { @artist.id }, -> { [@artist_url] }, include: %i[artist])
          assert_search_param(:artist_name, -> { @artist.name }, -> { [@artist_url] }, include: %i[artist])
          assert_search_param(:is_active, "true", -> { [@artist_url] }, include: %i[artist])
          assert_search_param(:url, "https://google.com", -> { [@artist_url] }, include: %i[artist])
          assert_search_param(:url_matches, "https://google.com", -> { [@artist_url] }, include: %i[artist])
          assert_search_param(:normalized_url, "http://google.com", -> { [@artist_url] }, include: %i[artist])
          assert_search_param(:normalized_url_matches, "http://google.com", -> { [@artist_url] }, include: %i[artist])
          assert_shared_search_params(-> { [@artist_url] }, include: %i[artist])
        end
      end
    end
  end
end

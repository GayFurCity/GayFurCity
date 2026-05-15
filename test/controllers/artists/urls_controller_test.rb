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

        context("access control") do
          asserts do
            access.gte(User::Levels::ANONYMOUS).get(artist_urls_path)
          end
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

          asserts do
            search(:artist_id).value { @artist.id }.records { [@artist_url] }.include(%i[artist])
            search(:artist_name).value { @artist.name }.records { [@artist_url] }.include(%i[artist])
            search(:is_active, "true").records { [@artist_url] }.include(%i[artist])
            search(:url, "https://google.com").records { [@artist_url] }.include(%i[artist])
            search(:url_matches, "https://google.com").records { [@artist_url] }.include(%i[artist])
            search(:normalized_url, "http://google.com").records { [@artist_url] }.include(%i[artist])
            search(:normalized_url_matches, "http://google.com").records { [@artist_url] }.include(%i[artist])
            search.shared.records { [@artist_url] }.include(%i[artist])
          end
        end
      end
    end
  end
end

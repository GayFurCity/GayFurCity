# frozen_string_literal: true

require("test_helper")

module Characters
  class UrlsControllerTest < ActionDispatch::IntegrationTest
    context("The character urls controller") do
      context("index page") do
        should("render") do
          get(character_urls_path)

          assert_response(:success)
        end

        should("render for a complex search") do
          @user = create(:user)
          @character = create(:character, name: "bkub", url_string: "-http://bkub.com", creator: @user)

          get(character_urls_path(search: {
            character_name: "bkub",
            url_matches:    "*bkub*",
            is_active:      "false",
            order:          "created_at",
          }))

          assert_response(:success)
        end

        context("access control") do
          asserts do
            access.gte(User::Levels::ANONYMOUS).get(character_urls_path)
          end
        end

        context("search parameters") do
          subject { character_urls_path }
          setup do
            CharacterUrl.delete_all
            CharacterVersion.delete_all
            Character.delete_all
            @user = create(:user)
            @character = create(:character, url_string: "https://google.com")
            @character_url = @character.urls.first
          end

          asserts do
            search(:character_id).value { @character.id }.records { [@character_url] }.include(%i[character])
            search(:character_name).value { @character.name }.records { [@character_url] }.include(%i[character])
            search(:is_active, "true").records { [@character_url] }.include(%i[character])
            search(:url, "https://google.com").records { [@character_url] }.include(%i[character])
            search(:url_matches, "https://google.com").records { [@character_url] }.include(%i[character])
            search(:normalized_url, "http://google.com").records { [@character_url] }.include(%i[character])
            search(:normalized_url_matches, "http://google.com").records { [@character_url] }.include(%i[character])
            search.shared.records { [@character_url] }.include(%i[character])
          end
        end
      end
    end
  end
end

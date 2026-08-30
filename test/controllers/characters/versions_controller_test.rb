# frozen_string_literal: true

require("test_helper")

module Characters
  class VersionsControllerTest < ActionDispatch::IntegrationTest
    context("A character versions controller") do
      setup do
        @user = create(:trusted_user)
        @character = create(:character, creator: @user)
      end

      should("get the index page") do
        get_auth(character_versions_path, @user)

        assert_response(:success)
      end

      should("get the index page when searching for something") do
        get_auth(character_versions_path(search: { character_name: @character.name }), @user)

        assert_response(:success)
      end

      context("access control") do
        asserts do
          access.gte(User::Levels::ANONYMOUS).get(character_versions_path)
          access.gte(User::Levels::ANONYMOUS).json.get(character_versions_path)
        end
      end

      context("search parameters") do
        subject { character_versions_path }
        setup do
          CharacterUrl.delete_all
          CharacterVersion.delete_all
          Character.delete_all
          @updater = create(:user)
          @admin = create(:admin_user)
          @character = create(:character, updater: @updater, updater_ip_addr: "127.0.0.2")
          @character_version = @character.versions.first
        end

        asserts do
          search(:character_id).value { @character.id }.records { [@character_version] }
          search(:character_name).value { @character.name }.records { [@character_version] }
          search(:updater_id).value { @updater.id }.records { [@character_version] }
          search(:updater_name).value { @updater.name }.records { [@character_version] }
          search(:ip_addr, "127.0.0.2").records { [@character_version] }.user { @admin }
          search.shared.records { [@character_version] }
        end
      end
    end
  end
end

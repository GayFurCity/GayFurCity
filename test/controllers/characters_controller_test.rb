# frozen_string_literal: true

require("test_helper")

class CharactersControllerTest < ActionDispatch::IntegrationTest
  context("The characters controller") do
    setup do
      @admin = create(:admin_user)
      @user = create(:janitor_user)
      @character = create(:character, notes: "message")
      @masao = create(:character, name: "masao", url_string: "http://toyhou.se/masao")
      @artgerm = create(:character, name: "artgerm", url_string: "http://toyhou.se/artgerm")
    end

    context("new action") do
      should("render") do
        get_auth(new_character_path, @user)

        assert_response(:success)
      end

      context("access control") do
        asserts do
          access.gte(User::Levels::MEMBER).get(new_character_path)
        end
      end
    end

    context("show_or_new action") do
      should("get the show_or_new page for an existing character") do
        get_auth(show_or_new_characters_path(name: "masao"), @user)

        assert_redirected_to(@masao)
      end

      should("get the show_or_new page for a nonexisting character") do
        get_auth(show_or_new_characters_path(name: "nobody"), @user)

        assert_response(:success)
      end

      context("access control") do
        asserts do
          access.gte(User::Levels::ANONYMOUS).get(show_or_new_characters_path)
        end
      end
    end

    context("edit action") do
      should("render") do
        get_auth(edit_character_path(@character), @user)

        assert_response(:success)
      end

      context("access control") do
        asserts do
          access.gte(User::Levels::MEMBER).get { edit_character_path(@character) }
        end
      end
    end

    context("update action") do
      should("work") do
        put_auth(character_path(@character), @user, params: { character: { notes: "xyz" } })
        @character.reload

        assert_equal("xyz", @character.notes)
      end

      context("access control") do
        asserts do
          access.gte(User::Levels::MEMBER).put { character_path(@character) }.params({ character: { notes: "xyz" } }).success(:redirect)
          access.gte(User::Levels::MEMBER).json.put { character_path(@character) }.params({ character: { notes: "xyz" } })
        end
      end
    end

    context("show action") do
      should("render") do
        get(character_path(@character))

        assert_response(:success)
      end

      context("access control") do
        asserts do
          access.gte(User::Levels::ANONYMOUS).get { character_path(@character) }
          access.gte(User::Levels::ANONYMOUS).json.get { character_path(@character) }
        end
      end
    end

    context("index action") do
      should("render") do
        get(characters_path)

        assert_response(:success)
      end

      context("access control") do
        asserts do
          access.gte(User::Levels::ANONYMOUS).get(characters_path)
          access.gte(User::Levels::ANONYMOUS).json.get(characters_path)
        end
      end

      context("search parameters") do
        subject { characters_path }
        setup do
          CharacterUrl.delete_all
          CharacterVersion.delete_all
          Character.delete_all
          @user = create(:user)
          @owner = create(:user)
          @admin = create(:admin_user)
          @character = create(:character, name: "foo", url_string: "https://google.com", owner_user: @owner, creator: @user, creator_ip_addr: "127.0.0.2")
        end

        asserts do
          search(:name, "foo").records { [@character] }.include(%i[urls])
          search(:ip_addr, "127.0.0.2").records { [@character] }.include(%i[urls]).user { @admin }
          search(:any_name_matches, "foo").records { [@character] }.include(%i[urls])
          search(:any_name_or_url_matches, "https://google.com").records { [@character] }.include(%i[urls])
          search(:url_matches, "google.com").records { [@character] }.include(%i[urls])
          search(:is_owned, "true").records { [@character] }.include(%i[urls])
          search(:has_tag, "true").records { [create(:character, name: create(:tag, post_count: 10).name)] }.include(%i[urls])
          search(:creator_id).value { @user.id }.records { [@character] }.include(%i[urls])
          search(:creator_name).value { @user.name }.records { [@character] }.include(%i[urls])
          search(:owner_user_id).value { @owner.id }.records { [@character] }.include(%i[urls])
          search(:owner_user_name).value { @owner.name }.records { [@character] }.include(%i[urls])
          search.shared(%i[id created_at]).records { [@character] }.include(%i[urls])
        end
      end
    end

    context("create action") do
      should("work") do
        attributes = attributes_for(:character)
        assert_difference("Character.count", 1) do
          post_auth(characters_path, @user, params: { character: attributes })
        end

        character = Character.find_by(name: attributes[:name])

        assert_not_nil(character)
        assert_redirected_to(character_path(character.id))
      end

      should("work (with url string)") do
        attributes = attributes_for(:character)
        attributes[:url_string] ||= GayFurCity.config.hostname
        assert_difference(%w[Character.count CharacterUrl.count], 1) do
          post_auth(characters_path, @user, params: { character: attributes })
        end

        character = Character.find_by(name: attributes[:name])

        assert_not_nil(character)
        assert_redirected_to(character_path(character.id))
      end

      should("return expected errors") do
        post_auth(characters_path, @user, params: { character: { name: @character.name }, format: "json" })

        assert_error_response("name", "has already been taken")

        post_auth(characters_path, @user, params: { character: { name: "" }, format: "json" })

        assert_error_response("name", "'' cannot be blank")

        post_auth(characters_path, @user, params: { character: { name: "a" * 101 }, format: "json" })

        assert_error_response("name", "is too long (maximum is 100 characters)")
      end

      context("access control") do
        asserts do
          access.gte(User::Levels::MEMBER).post(characters_path).params { { character: { name: SecureRandom.hex(6) } } }.success(:redirect)
          access.gte(User::Levels::MEMBER).json.post(characters_path).params { { character: { name: SecureRandom.hex(6) } } }
        end
      end
    end

    context("with a character that has notes") do
      setup do
        @character = create(:character, name: "aaa", notes: "testing", url_string: "http://example.com")
        @wiki_page = @character.wiki_page
        @another_user = create(:user)
      end

      should("update a character") do
        old_timestamp = @wiki_page.updated_at
        travel_to(1.minute.from_now) do
          put_auth(character_path(@character.id), @user, params: { character: { notes: "rex", url_string: "http://example.com\nhttp://toyhou.se/monet" } })
        end
        @character.reload
        @wiki_page = @character.wiki_page

        assert_equal("rex", @character.notes)
        assert_not_equal(old_timestamp, @wiki_page.updated_at)
        assert_redirected_to(character_path(@character.id))
      end

      should("not touch the updater_id and updated_at fields when nothing is changed") do
        old_timestamp = @wiki_page.updated_at
        old_updater_id = @wiki_page.updater_id

        travel_to(1.minute.from_now) do
          @character.update_with(@another_user, notes: "testing")
        end

        @character.reload
        @wiki_page = @character.wiki_page

        assert_in_delta(old_timestamp.to_i, @wiki_page.updated_at.to_i, 1)
        assert_equal(old_updater_id, @wiki_page.updater_id)
      end

      context("when renaming a character") do
        should("automatically rename the character's wiki page") do
          assert_difference("WikiPage.count", 0) do
            put_auth(character_path(@character), @user, params: { character: { name: "bbb", notes: "more testing" } })
          end
          @wiki_page.reload

          assert_equal("bbb", @wiki_page.title)
          assert_equal("more testing", @wiki_page.body)
        end
      end

      should("propagate is_locked") do
        put_auth(character_path(@character), @user, params: { character: { is_locked: true } })
        @character.reload
        @wiki_page.reload

        assert_predicate(@character, :is_locked?)
        assert_equal(User::Levels.min_staff_level, @wiki_page.protection_level)
      end

      should("not lower the protection level") do
        @wiki_page.update_column(:protection_level, User::Levels::ADMIN)
        put_auth(character_path(@character), @user, params: { character: { is_locked: true } })
        @character.reload
        @wiki_page.reload

        assert_predicate(@character, :is_locked?)
        assert_equal(User::Levels::ADMIN, @wiki_page.protection_level)
      end

      should("enforce protections") do
        @wiki_page.update_column(:protection_level, User::Levels::ADMIN)
        put_auth(character_path(@character), @user, params: { character: { notes: "xxx" } })
        @character.reload

        assert_equal("testing", @character.notes)
      end
    end

    context("destroy action") do
      should("delete a character") do
        @admin = create(:admin_user)
        delete_auth(character_path(@character), @admin)

        assert_redirected_to(characters_path)
      end

      context("access control") do
        asserts do
          access.gte(User::Levels::ADMIN).delete { character_path(create(:character)) }.success(:redirect)
          access.gte(User::Levels::ADMIN).json.delete { character_path(create(:character)) }.success(:no_content)
        end
      end
    end

    context("revert action") do
      should("work") do
        @character.update_with(@user, name: "xyz")
        @character.update_with(@user, name: "abc")
        assert_nothing_raised { put_auth(revert_character_path(@character), @user, params: { version_id: @character.versions.first.id }) }
      end

      should("not allow reverting to a previous version of another character") do
        @character2 = create(:character)
        put_auth(character_path(@character), @user, params: { version_id: @character2.versions.first.id })
        @character.reload

        assert_not_equal(@character.name, @character2.name)
        assert_redirected_to(character_path(@character.id))
      end

      context("access control") do
        asserts do
          access.gte(User::Levels::MEMBER).json.put { revert_character_path(@character) }.params { { version_id: @character.versions.first.id } }
        end
      end
    end
  end
end

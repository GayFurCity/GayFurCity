# frozen_string_literal: true

require("test_helper")

class CharacterTest < ActiveSupport::TestCase
  context("A character") do
    setup do
      @user = create(:user, created_at: 1.month.ago)
    end

    should("parse inactive urls") do
      @character = create(:character, name: "blah", url_string: "-http://toyhou.se/blah")

      assert_equal(["-http://toyhou.se/blah"], @character.urls.map(&:to_s))
      assert_not(@character.urls[0].is_active?)
    end

    should("not allow duplicate active+inactive urls") do
      @character = create(:character, name: "blah", url_string: "-http://toyhou.se/blah\nhttp://toyhou.se/blah")

      assert_equal(1, @character.urls.count)
      assert_equal(["-http://toyhou.se/blah"], @character.urls.map(&:to_s))
      assert_not(@character.urls[0].is_active?)
    end

    should("allow deactivating a url") do
      @character = create(:character, name: "blah", url_string: "http://toyhou.se/blah")
      @character.update_with(@user, url_string: "-http://toyhou.se/blah")

      assert_equal(1, @character.urls.count)
      assert_not(@character.urls[0].is_active?)
    end

    should("allow activating a url") do
      @character = create(:character, name: "blah", url_string: "-http://toyhou.se/blah")
      @character.update_with(@user, url_string: "http://toyhou.se/blah")

      assert_equal(1, @character.urls.count)
      assert_predicate(@character.urls[0], :is_active?)
    end

    context("with an invalid name") do
      subject { build(:character) }

      should_not(allow_value("-blah").for(:name))
      should_not(allow_value("_").for(:name))
      should_not(allow_value("").for(:name))
    end

    should("create a new wiki page to store any note information") do
      character = nil
      assert_difference("WikiPage.count") do
        character = create(:character, name: "aaa", notes: "testing")
      end
      assert_equal("testing", character.notes)
      assert_equal("testing", character.wiki_page.body)
      assert_equal(character.name, character.wiki_page.title)
    end

    should("update the wiki page when notes are assigned") do
      character = create(:character, name: "aaa", notes: "testing")
      character.update_attribute(:notes, "kokoko")
      character.reload

      assert_equal("kokoko", character.notes)
      assert_equal("kokoko", character.wiki_page.body)
    end

    should("normalize its name") do
      character = create(:character, name: "  AAA BBB  ")

      assert_equal("aaa_bbb", character.name)
    end

    should("parse urls") do
      character = create(:character, name: "rembrandt", url_string: "http://rembrandt.com/test.jpg http://aaa.com")
      character.reload

      assert_equal(["http://aaa.com", "http://rembrandt.com/test.jpg"], character.urls.map(&:to_s).sort)
    end

    should("not allow invalid urls") do
      character = build(:character, url_string: "blah")

      assert_not(character.valid?)
      assert_equal(["'blah' must begin with http:// or https:// "], character.errors["urls.url"])
    end

    should("allow fixing invalid urls") do
      character = build(:character)
      character.urls << build(:character_url, url: "www.example.com", normalized_url: "www.example.com")
      character.save(validate: false)

      character.update(url_string: "http://www.example.com")

      assert_predicate(character, :valid?)
      assert_equal("http://www.example.com", character.urls.join)
    end

    should("make sure old urls are deleted") do
      character = create(:character, name: "rembrandt", url_string: "http://rembrandt.com/test.jpg")
      character.url_string = "http://not.rembrandt.com/test.jpg"
      character.save
      character.reload

      assert_equal(["http://not.rembrandt.com/test.jpg"], character.urls.map(&:to_s).sort)
    end

    should("not delete urls that have not changed") do
      character = create(:character, name: "rembrandt", url_string: "http://rembrandt.com/test.jpg")
      old_url_ids = CharacterUrl.order(:id).pluck(&:id)
      character.url_string = "http://rembrandt.com/test.jpg"
      character.save

      assert_equal(old_url_ids, CharacterUrl.order(:id).pluck(&:id))
    end

    should("not include duplicate urls") do
      character = create(:character, url_string: "http://foo.com http://foo.com")

      assert_equal(["http://foo.com"], character.url_array)
    end

    context("with a cover post") do
      should("allow a post tagged with the character") do
        character = create(:character, name: "bkub")
        post = create(:post, tag_string: "bkub")

        character.update_with(@user, cover_post_id: post.id, cover_caption: "hello there")

        assert_equal(post.id, character.reload.cover_post_id)
        assert_equal("hello there", character.cover_caption)
      end

      should("not allow a post that isn't tagged with the character") do
        character = create(:character, name: "bkub")
        post = create(:post, tag_string: "not_bkub")

        character.update_with(@user, cover_post_id: post.id)

        assert_not(character.errors["cover_post"].empty?)
        assert_nil(character.reload.cover_post_id)
      end

      should("blank out a cover post that no longer exists") do
        character = create(:character, name: "bkub")
        character.update_column(:cover_post_id, 999_999)

        character.update_with(@user, notes: "testing")

        assert_nil(character.reload.cover_post_id)
      end

      should("create a new version and set cover_post_changed/cover_caption_changed") do
        character = create(:character, name: "bkub")
        post = create(:post, tag_string: "bkub")

        assert_difference("CharacterVersion.count") do
          character.update_with(@user, cover_post_id: post.id, cover_caption: "hi")
        end

        version = character.versions.last

        assert(version.cover_post_changed)
        assert(version.cover_caption_changed)
      end

      should("not set cover_post_changed/cover_caption_changed when neither changed") do
        character = create(:character, name: "bkub", url_string: "http://foo.com")

        character.update_with(@user, url_string: "http://bar.com")

        version = character.versions.last

        assert_not(version.cover_post_changed)
        assert_not(version.cover_caption_changed)
      end
    end

    context("with custom attributes") do
      should("set name/value pairs from form-style params") do
        character = create(:character, name: "bkub")

        character.update_with(@user, custom_attributes: { "0" => { "name" => "Height", "value" => "5ft" }, "1" => { "name" => "Age", "value" => "24" } })

        assert_equal([{ "name" => "Height", "value" => "5ft" }, { "name" => "Age", "value" => "24" }], character.reload.custom_attributes)
      end

      should("set name/value pairs from a literal array") do
        character = create(:character, name: "bkub", custom_attributes: [{ "name" => "Height", "value" => "5ft" }])

        assert_equal([{ "name" => "Height", "value" => "5ft" }], character.reload.custom_attributes)
      end

      should("drop entries with a blank name") do
        character = create(:character, name: "bkub", custom_attributes: [{ "name" => "", "value" => "x" }, { "name" => "Height", "value" => "5ft" }])

        assert_equal([{ "name" => "Height", "value" => "5ft" }], character.custom_attributes)
      end

      should("truncate to the maximum of 25 entries") do
        attrs = 30.times.map { |i| { "name" => "attr#{i}", "value" => i.to_s } }
        character = create(:character, name: "bkub", custom_attributes: attrs)

        assert_equal(25, character.custom_attributes.size)
      end

      should("not allow \"owner\" or \"user\" as a name, case-insensitively") do
        character = build(:character, name: "bkub", custom_attributes: [{ "name" => "Owner", "value" => "x" }])

        assert_not(character.valid?)

        character = build(:character, name: "bkub", custom_attributes: [{ "name" => "USER", "value" => "x" }])

        assert_not(character.valid?)
      end

      should("not allow duplicate names, case-insensitively") do
        character = build(:character, name: "bkub", custom_attributes: [{ "name" => "Height", "value" => "5ft" }, { "name" => "height", "value" => "6ft" }])

        assert_not(character.valid?)
      end

      should("create a new version and set custom_attributes_changed when attributes change") do
        character = create(:character, name: "bkub")

        assert_difference("CharacterVersion.count") do
          character.update_with(@user, custom_attributes: [{ "name" => "Height", "value" => "5ft" }])
        end

        version = character.versions.last

        assert_equal([{ "name" => "Height", "value" => "5ft" }], version.custom_attributes)
        assert(version.custom_attributes_changed)
      end

      should("not set custom_attributes_changed when attributes did not change") do
        character = create(:character, name: "bkub", url_string: "http://foo.com")

        character.update_with(@user, url_string: "http://bar.com")

        assert_not(character.versions.last.custom_attributes_changed)
      end
    end

    should("search on its name should return results") do
      character = create(:character, name: "character")

      assert_equal(character.id, Character.search({ name: "character" }, @user).first&.id)
      assert_equal(character.id, Character.search({ any_name_matches: "character" }, @user).first&.id)
      assert_equal(character.id, Character.search({ any_name_matches: "*char*" }, @user).first&.id)
    end

    should("search on url and return matches") do
      bkub = create(:character, name: "bkub", url_string: "http://bkub.com")

      assert_equal([bkub.id], Character.search({ url_matches: "bkub" }, @user).map(&:id))
      assert_equal([bkub.id], Character.search({ url_matches: "*bkub*" }, @user).map(&:id))
      assert_equal([], Character.search({ url_matches: "*rifyu*" }, @user).map(&:id))
    end

    should("search on has_tag and return matches") do
      create(:post, tag_string: "bkub")
      bkub = create(:character, name: "bkub")
      none = create(:character, name: "none")

      assert_equal(bkub.id, Character.search({ has_tag: "true" }, @user).first.id)
      assert_equal(none.id, Character.search({ has_tag: "false" }, @user).first.id)
    end

    should("revert to prior versions") do
      create(:user)
      create(:user)
      character = nil
      assert_difference("CharacterVersion.count") do
        character = create(:character, url_string: "http://foo.com")
      end

      assert_difference("CharacterVersion.count") do
        character.url_string = "http://bar.com"
        character.save
      end

      first_version = CharacterVersion.first

      assert_equal(%w[http://foo.com], first_version.urls)
      character.revert_to!(first_version, @user)
      character.reload

      assert_equal(%w[http://foo.com], character.url_array)
    end

    should("update the category of the tag when created") do
      tag = create(:tag, name: "abc")
      create(:character, name: "abc")
      tag.reload

      assert_equal(TagCategory.character, tag.category)
      assert_equal("character creation", TagVersion.last.reason)
    end

    context("when saving") do
      setup do
        @character = create(:character, url_string: "http://foo.com")
      end

      should("create a new version when a url is added") do
        assert_difference("CharacterVersion.count") do
          @character.update(url_string: "http://foo.com http://bar.com")

          assert_equal(%w[http://bar.com http://foo.com], @character.versions.last.urls)
        end
      end

      should("create a new version when a url is removed") do
        assert_difference("CharacterVersion.count") do
          @character.update(url_string: "")

          assert_equal(%w[], @character.versions.last.urls)
        end
      end

      should("not create a new version when nothing has changed") do
        assert_no_difference("CharacterVersion.count") do
          @character.save

          assert_equal(%w[http://foo.com], @character.versions.last.urls)
        end
      end

      should("not save invalid urls") do
        assert_no_difference("CharacterVersion.count") do
          @character.update(url_string: "http://foo.com www.example.com")

          assert_equal(%w[http://foo.com], @character.versions.last.urls)
        end
      end
    end

    context("that is updated") do
      setup do
        @character = create(:character, name: "test")
      end

      should("log the correct data when renamed") do
        @character.update_with(@user, name: "new_name")

        assert_equal({ "new_name" => "new_name", "old_name" => "test" }, ModAction.last.values)
      end

      should("log the correct data when owner is set/unset") do
        user = create(:user)

        @character.update_with(@user, owner_user: user)
        mod_action = ModAction.last

        assert_equal("character_owner_link", mod_action.action)
        assert_equal({ "user_id" => user.id }, mod_action.values)

        @character.update_with(@user, owner_user: nil)
        mod_action = ModAction.last

        assert_equal("character_owner_unlink", mod_action.action)
        assert_equal({ "user_id" => user.id }, mod_action.values)
      end

      should("fail if the user is limited") do
        @character.update_with(@user, url_string: "https://gayfur.city")

        @character.reload

        assert_equal("https://gayfur.city", @character.url_string)

        GayFurCity.config.stubs(:disable_throttles).returns(false)
        AdminConfig.any_instance.stubs(:character_edit_limit).returns(0)

        assert_no_difference("CharacterVersion.count") do
          @character.update_with(@user, url_string: "")
        end

        @character.reload

        assert_equal("https://gayfur.city", @character.url_string)
      end

      should("not change urls when locked") do
        @character.update_with(@user, url_string: "https://gayfur.city")

        @character.reload

        assert_equal("https://gayfur.city", @character.url_string)

        @character.update_column(:is_locked, true)

        assert_no_difference(-> { CharacterVersion.count }) do
          @character.update_with(@user, url_string: "https://sfw.gayfur.city")
        end

        @character.reload

        assert_equal("https://gayfur.city", @character.url_string)
      end

      should("not change notes when locked") do
        @character.update_with(@user, notes: "abababab")

        assert_equal("abababab", @character.wiki_page.body)

        @character.wiki_page.update_columns(protection_level: User::Levels::JANITOR)

        assert_no_difference(-> { CharacterVersion.count }) do
          @character.update_with(@user, notes: "babababa")
        end

        assert_equal("abababab", @character.wiki_page.body)

        assert_equal(["Wiki page is locked"], @character.errors.full_messages)
      end
    end
  end
end

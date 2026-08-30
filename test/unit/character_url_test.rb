# frozen_string_literal: true

require("test_helper")

class CharacterUrlTest < ActiveSupport::TestCase
  def assert_search_equals(results, conditions, user)
    assert_equal(results.map(&:id), subject.search(conditions, user).map(&:id))
  end

  context("A character url") do
    setup do
      @user = create(:user)
    end

    should("allow urls to be marked as inactive") do
      url = create(:character_url, url: "http://toyhou.se/blah", is_active: false)

      assert_equal("http://toyhou.se/blah", url.url)
      assert_equal("http://toyhou.se/blah/", url.normalized_url)
      assert_equal("-http://toyhou.se/blah", url.to_s)
    end

    should("disallow invalid urls") do
      url = build(:character_url, url: "www.example.com")

      assert_not(url.valid?)
      assert_match(/must begin with http/, url.errors.full_messages.join)
    end

    should("always add a trailing slash when normalized") do
      url = create(:character_url, url: "http://toyhou.se/blah")

      assert_equal("http://toyhou.se/blah", url.url)
      assert_equal("http://toyhou.se/blah/", url.normalized_url)

      url = create(:character_url, url: "http://toyhou.se/blah/")

      assert_equal("http://toyhou.se/blah/", url.url)
      assert_equal("http://toyhou.se/blah/", url.normalized_url)
    end

    should("normalise https") do
      url = create(:character_url, url: "https://google.com")

      assert_equal("https://google.com", url.url)
      assert_equal("http://google.com/", url.normalized_url)
    end

    should("normalise domains to lowercase") do
      url = create(:character_url, url: "https://CharacterName.example.com")

      assert_equal("http://charactername.example.com/", url.normalized_url)
    end

    context("#search") do
      subject { CharacterUrl }

      should("work") do
        @bkub = create(:character, name: "bkub", url_string: "https://bkub.com")
        @bkub_url = @bkub.urls.first

        assert_search_equals([@bkub_url], { is_active: true }, @user)
        assert_search_equals([@bkub_url], { character: { name: "bkub" } }, @user)

        assert_search_equals([@bkub_url], { url_matches: "*bkub*" }, @user)

        assert_search_equals([@bkub_url], { normalized_url_matches: "*bkub*" }, @user)
        assert_search_equals([@bkub_url], { normalized_url_matches: "http://bkub.com" }, @user)

        assert_search_equals([@bkub_url], { url: "https://bkub.com" }, @user)
      end
    end
  end
end

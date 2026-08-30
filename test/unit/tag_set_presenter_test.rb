# frozen_string_literal: true

require("test_helper")

class TagSetPresenterTest < ActiveSupport::TestCase
  context("TagSetPresenter") do
    setup do
      create(:tag, name: "bkub", category: TagCategory.artist)
      create(:tag, name: "chen", category: TagCategory.character)
      create(:tag, name: "cirno", category: TagCategory.character)
      create(:tag, name: "solo", category: TagCategory.general)
      create(:tag, name: "touhou", category: TagCategory.copyright)
    end

    context("#split_tag_list_text method") do
      should("list all categories in order") do
        text = TagSetPresenter.new(%w[bkub chen cirno solo touhou]).split_tag_list_text

        assert_equal("bkub \ntouhou \nchen cirno \nsolo", text)
      end

      should("skip empty categories") do
        text = TagSetPresenter.new(%w[bkub solo]).split_tag_list_text

        assert_equal("bkub \nsolo", text)
      end
    end

    context("#post_show_sidebar_tag_list_html method") do
      setup do
        @user = create(:user)
        character_groups = [{ characters: ["chen"], tags: ["solo"] }]
        @presenter = TagSetPresenter.new(%w[bkub chen cirno solo touhou], character_groups: character_groups)
      end

      should("group tags by character when the viewer has grouping enabled") do
        CurrentUser.scoped(@user) do # rubocop:disable YiffSpace/CurrentOutsideOfRequests
          html = @presenter.post_show_sidebar_tag_list_html(highlighted_tags: [], followed_tags: [])

          assert_includes(html, "character-group-header")
          assert_includes(html, "chen")
          assert_includes(html, %(href="/characters/show_or_new?name=chen"))
        end
      end

      should("fall back to the flat, ungrouped list when the viewer has grouping disabled") do
        @user.disable_character_tag_grouping = true
        CurrentUser.scoped(@user) do # rubocop:disable YiffSpace/CurrentOutsideOfRequests
          html = @presenter.post_show_sidebar_tag_list_html(highlighted_tags: [], followed_tags: [])

          assert_not_includes(html, "character-group-header")
          assert_includes(html, "chen")
        end
      end

      should("fall back to the flat list when there are no character groups, even with grouping enabled") do
        presenter = TagSetPresenter.new(%w[bkub chen cirno solo touhou])
        CurrentUser.scoped(@user) do # rubocop:disable YiffSpace/CurrentOutsideOfRequests
          html = presenter.post_show_sidebar_tag_list_html(highlighted_tags: [], followed_tags: [])

          assert_not_includes(html, "character-group-header")
        end
      end
    end

    context("#post_show_sidebar_grouped_tag_list_html method") do
      should("label a group with no character-category tag as an unnamed character") do
        presenter = TagSetPresenter.new(%w[bkub solo], character_groups: [{ characters: [], tags: ["solo"] }])

        html = presenter.post_show_sidebar_grouped_tag_list_html(highlighted_tags: [], followed_tags: [])

        assert_includes(html, "Unnamed Character #1")
      end

      should("put tags not attributed to any character under a trailing General section") do
        presenter = TagSetPresenter.new(%w[bkub chen solo], character_groups: [{ characters: ["chen"], tags: [] }])

        html = presenter.post_show_sidebar_grouped_tag_list_html(highlighted_tags: [], followed_tags: [])

        assert_includes(html, "general-character-group-header")
        assert_includes(html, "bkub")
        assert_includes(html, "solo")
      end

      should("wrap each group's header and tags in a collapsible container") do
        presenter = TagSetPresenter.new(%w[bkub chen solo], character_groups: [{ characters: ["chen"], tags: [] }])

        html = presenter.post_show_sidebar_grouped_tag_list_html(highlighted_tags: [], followed_tags: [])

        assert_includes(html, %(class="character-group"))
        assert_includes(html, "character-group-content")
      end
    end
  end
end

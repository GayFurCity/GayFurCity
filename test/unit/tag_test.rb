# frozen_string_literal: true

require("test_helper")

class TagTest < ActiveSupport::TestCase
  setup do
    @janitor = create(:janitor_user)
  end

  context("A tag category fetcher") do
    should("fetch for a single tag") do
      create(:artist_tag, name: "test")

      assert_equal(TagCategory.artist, Tag.category_for("test"))
    end

    should("fetch for a single tag with strange markup") do
      create(:artist_tag, name: "!@ab")

      assert_equal(TagCategory.artist, Tag.category_for("!@ab"))
    end

    should("return general for a tag that doesn't exist") do
      assert_equal(TagCategory.general, Tag.category_for("missing"))
    end

    should("fetch for multiple tags") do
      create(:artist_tag, name: "aaa")
      create(:copyright_tag, name: "bbb")
      categories = Tag.categories_for(%w[aaa bbb ccc])

      assert_equal(TagCategory.artist, categories["aaa"])
      assert_equal(TagCategory.copyright, categories["bbb"])
      assert_nil(categories["ccc"])
    end
  end

  context("A tag category mapping") do
    should("exist") do
      assert_nothing_raised { TagCategory.categories }
    end

    should("have convenience methods for all categories") do
      assert_equal(0, TagCategory.general)
      assert_equal(1, TagCategory.artist)
      assert_equal(2, TagCategory.contributor)
      assert_equal(3, TagCategory.copyright)
      assert_equal(4, TagCategory.character)
      assert_equal(5, TagCategory.species)
      assert_equal(6, TagCategory.invalid)
      assert_equal(7, TagCategory.meta)
      assert_equal(8, TagCategory.lore)
      assert_equal(9, TagCategory.gender)
      assert_equal(10, TagCategory.important)
    end

    should("have a regular expression for matching category names and shortcuts") do
      regexp = TagCategory.regexp

      assert_match(regexp, "artist")
      assert_match(regexp, "art")
      assert_match(regexp, "copyright")
      assert_match(regexp, "copy")
      assert_match(regexp, "co")
      assert_match(regexp, "character")
      assert_match(regexp, "char")
      assert_match(regexp, "ch")
      assert_match(regexp, "meta")
      assert_no_match(regexp, "c")
      assert_no_match(regexp, "woodle")
    end

    should("map a category name to its value") do
      mapping = [
        [0, %w[general gen unknown]],
        [1, %w[artist art]],
        [2, %w[contributor cont]],
        [3, %w[copyright copy co]],
        [4, %w[character char ch oc]],
        [5, %w[species spec]],
        [6, %w[invalid inv]],
        [7, %w[meta]],
        [8, %w[lore lor]],
        [9, %w[gender]],
        [10, %w[important imp]],
      ]
      mapping.each do |category, matches|
        matches.each do |match|
          assert_equal(category, TagCategory.value_for(match), "value(#{match}) == #{category}")
        end
      end
    end
  end

  context("A tag") do
    should("know its category name") do
      @tag = create(:artist_tag)

      assert_equal("Artist", @tag.category_name)
    end

    should("reset its category after updating") do
      tag = create(:artist_tag)

      assert_equal(TagCategory.artist, Cache.fetch("tc:#{tag.name}"))

      tag.update_attribute(:category, TagCategory.copyright)

      assert_equal(TagCategory.copyright, Cache.fetch("tc:#{tag.name}"))
    end

    context("not be settable to an invalid category") do
      subject do
        Tag.new(creator: create(:owner_user))
      end

      should(validate_inclusion_of(:category).in_array(TagCategory.ids))
    end

    should("create a version upon creation") do
      assert_difference("TagVersion.count", 1) do
        create(:tag)
      end
    end

    should("create a version when category is changed") do
      tag = create(:tag)
      assert_difference("TagVersion.count", 1) do
        tag.update_with!(@janitor, category: TagCategory.artist)
      end
    end

    should("create a version when is_locked is changed") do
      tag = create(:tag)
      assert_difference("TagVersion.count", 1) do
        tag.update_with!(@janitor, is_locked: true)
      end
    end
  end

  context("A tag") do
    should("be found when one exists") do
      tag = create(:tag)
      assert_difference("Tag.count", 0) do
        Tag.find_or_create_by_name(tag.name, user: @janitor)
      end
    end

    should("change the type for an existing tag") do
      tag = create(:tag)
      assert_difference("Tag.count", 0) do
        assert_equal(TagCategory.general, tag.category)
        Tag.find_or_create_by_name("artist:#{tag.name}", user: @janitor)
        tag.reload

        assert_equal(TagCategory.artist, tag.category)
      end
    end

    should("not change the category is the tag is locked") do
      tag = create(:tag, is_locked: true)

      assert_predicate(tag, :is_locked?)
      Tag.find_or_create_by_name("artist:#{tag.name}", user: @janitor)
      tag.reload

      assert_equal(0, tag.category)
    end

    should("not change category when the tag is too large to be changed by a janitor") do
      tag = create(:tag, post_count: 1001)
      Tag.find_or_create_by_name("artist:#{tag.name}", user: @janitor)

      assert_equal(0, tag.reload.category)
    end

    should("not change category when the tag is too large to be changed by a member") do
      tag = create(:tag, post_count: 101)
      Tag.find_or_create_by_name("artist:#{tag.name}", user: create(:member_user))

      assert_equal(0, tag.reload.category)
    end

    should("update post tag counts when the category is changed") do
      post = create(:post, tag_string: "test")

      assert_equal(1, post.tag_count_general)
      assert_equal(0, post.tag_count_character)

      tag = Tag.find_by_normalized_name("test")
      with_inline_jobs { tag.update_attribute(:category, 4) }

      assert_equal([], tag.errors.full_messages)
      post.reload

      assert_equal(0, post.tag_count_general)
      assert_equal(1, post.tag_count_character)
    end

    should("be created when one doesn't exist") do
      assert_difference("Tag.count", 1) do
        tag = Tag.find_or_create_by_name("hoge", user: @janitor)

        assert_equal("hoge", tag.name)
        assert_equal(TagCategory.general, tag.category)
      end
    end

    should("be created with the type when one doesn't exist") do
      assert_difference("Tag.count", 1) do
        tag = Tag.find_or_create_by_name("artist:hoge", user: @janitor)

        assert_equal("hoge", tag.name)
        assert_equal(TagCategory.artist, tag.category)
      end
    end

    context("when deprecated") do
      should("require a wiki page") do
        tag = build(:tag, is_deprecated: true)

        assert_not(tag.valid?)
        assert_includes(tag.errors.full_messages, "Is deprecated cannot be set without a wiki page")
      end

      should("be forced locked") do
        tag = create(:deprecated_tag, is_locked: false)

        assert_predicate(tag, :is_locked?)
      end

      should("stay locked on later saves while still deprecated") do
        tag = create(:deprecated_tag)
        tag.update_columns(is_locked: false)

        tag.update!(post_count: 5)

        assert_predicate(tag.reload, :is_locked?)
      end
    end

    context("during name validation") do
      subject do
        build(:tag) # required because of creator validation
      end

      # tags with spaces or uppercase are allowed because they are normalized
      # to lowercase with underscores.
      should(allow_value(" foo ").for(:name).on(:create))
      should(allow_value("foo bar").for(:name).on(:create))
      should(allow_value("FOO").for(:name).on(:create))

      should_not(allow_value("").for(:name).on(:create))
      should_not(allow_value("___").for(:name).on(:create))
      %w|- ~ + _ ` ( ) { } [ ] /|.each do |x|
        should_not(allow_value("#{x}foo").for(:name).on(:create))
      end
      should_not(allow_value("foo_").for(:name).on(:create))
      should_not(allow_value("foo__bar").for(:name).on(:create))
      should_not(allow_value("foo*bar").for(:name).on(:create))
      should_not(allow_value("foo,bar").for(:name).on(:create))
      should_not(allow_value("foo\abar").for(:name).on(:create))
      should_not(allow_value("café").for(:name).on(:create))
      should_not(allow_value("東方").for(:name).on(:create))
      should_not(allow_value("FAV:blah").for(:name).on(:create))

      should_not(allow_value("foo)").for(:name).on(:create))
      should_not(allow_value("foo(").for(:name).on(:create))
      should_not(allow_value("foo)(").for(:name).on(:create))
      should_not(allow_value("foo(()").for(:name).on(:create))
      should_not(allow_value("foo())").for(:name).on(:create))

      # Valid nested and ordered parentheses
      should(allow_value("foo_(bar)").for(:name).on(:create))
      should(allow_value("foo_(bar_(baz))").for(:name).on(:create))
      should(allow_value("foo_(bar)_(baz)").for(:name).on(:create))
      should(allow_value("foo_(bar_baz)").for(:name).on(:create))

      # Invalid: '(' not preceded by underscore
      should_not(allow_value("foo(bar)").for(:name).on(:create))
      should_not(allow_value("foo(bar)_(baz)").for(:name).on(:create))
      should_not(allow_value("foo(bar)(qux)").for(:name).on(:create))
      should_not(allow_value("foo(bar_(baz))").for(:name).on(:create))

      # Invalid: unbalanced parentheses
      should_not(allow_value("foo_(bar").for(:name).on(:create))
      should_not(allow_value("foo_bar)").for(:name).on(:create))
      should_not(allow_value("foo_(bar_(baz)").for(:name).on(:create))
      should_not(allow_value("foo_(bar))").for(:name).on(:create))

      # Invalid: improperly ordered parentheses
      should_not(allow_value("foo_)bar(").for(:name).on(:create))
      should_not(allow_value("foo_()b)(c").for(:name).on(:create))
      should_not(allow_value("foo_(bar)baz)").for(:name).on(:create))
      should_not(allow_value("foo_)bar_(baz(").for(:name).on(:create))

      # Valid: parentheses properly ordered and balanced even across multiple segments
      should(allow_value("foo_(bar)_baz_(qux)").for(:name).on(:create))

      metatags = TagQuery::METATAGS + TagCategory.mapping.keys
      metatags.each do |metatag|
        should_not(allow_value("#{metatag}:foo").for(:name).on(:create))
      end
    end
  end

  context("A tag with a negative post count") do
    should("be fixed") do
      reset_post_index
      tag = create(:tag, name: "touhou", post_count: -10)
      create(:post, tag_string: "touhou")

      Tag.clean_up_negative_post_counts!

      assert_equal(1, tag.reload.post_count)
    end
  end

  context("An aliased tag with a non-zero post count") do
    should("be fixed") do
      reset_post_index
      tag = create(:tag, name: "foo", post_count: 1)
      create(:post, tag_string: "foo")

      assert_equal(2, tag.reload.post_count)
      ta = create(:tag_alias, antecedent_name: "foo", consequent_name: "bar")
      with_inline_jobs { ta.approve!(@janitor) }
      tag.update_column(:post_count, 1)

      assert_equal(1, tag.reload.post_count)

      TagAlias.fix_nonzero_post_counts!

      assert_equal(0, tag.reload.post_count)
    end

    should("not be fixed if the alias is inactive") do
      reset_post_index
      tag = create(:tag, name: "foo", post_count: 1)
      create(:post, tag_string: "foo")

      assert_equal(2, tag.reload.post_count)
      ta = create(:tag_alias, antecedent_name: "foo", consequent_name: "bar")
      with_inline_jobs { ta.approve!(@janitor) }
      tag.update_column(:post_count, 1)
      with_inline_jobs { ta.reject!(@janitor) }

      assert_equal(1, tag.reload.post_count)

      TagAlias.fix_nonzero_post_counts!

      assert_equal(1, tag.reload.post_count)
    end
  end
end

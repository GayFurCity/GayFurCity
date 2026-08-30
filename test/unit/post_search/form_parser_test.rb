# frozen_string_literal: true

require("test_helper")

module PostSearch
  class FormParserTest < ActiveSupport::TestCase
    context("PostSearch::FormParser") do
      should("put bare tags in general_tags") do
        result = FormParser.parse("solo duo")

        assert_equal("solo duo", result.general_tags)
        assert_empty(result.character_groups)
        assert_empty(result.field_values)
      end

      should("parse a {} group into character_groups with must mode") do
        result = FormParser.parse("{fluffy_(oc) blue_eyes}")

        assert_equal([{ tags: "fluffy_(oc) blue_eyes", mode: "must" }], result.character_groups)
      end

      should("parse a -{} group into character_groups with must_not mode") do
        result = FormParser.parse("-{fluffy_(oc)}")

        assert_equal([{ tags: "fluffy_(oc)", mode: "must_not" }], result.character_groups)
      end

      should("parse a ( ) group into bool_groups with must mode") do
        result = FormParser.parse("( solo duo )")

        assert_equal([{ tags: "solo duo", mode: "must", field_values: {}, field_modes: {} }], result.bool_groups)
      end

      should("parse a -( ) group into bool_groups with must_not mode") do
        result = FormParser.parse("-( solo duo )")

        assert_equal([{ tags: "solo duo", mode: "must_not", field_values: {}, field_modes: {} }], result.bool_groups)
      end

      should("parse a ~( ) group into bool_groups with should mode") do
        result = FormParser.parse("~( solo duo )")

        assert_equal([{ tags: "solo duo", mode: "should", field_values: {}, field_modes: {} }], result.bool_groups)
      end

      should("extract a recognized metatag out of a () group's text into that group's own field_values") do
        result = FormParser.parse("( rating:s solo ~( duo trio ) )")
        group = result.bool_groups.first

        # A nested () group isn't broken down further (the search builder doesn't support
        # editing one structurally) - it stays as part of the group's plain tags text, intact.
        assert_equal("~( duo trio ) solo", group[:tags])
        assert_equal({ rating: "s" }, group[:field_values])
        assert_equal({ rating: "must" }, group[:field_modes])
      end

      should("extract a quoted metatag value out of a () group's text instead of losing it to the top-level quote scan") do
        result = FormParser.parse(%(( parent:any source:"my source" solo )))
        group = result.bool_groups.first

        assert_equal("solo", group[:tags])
        assert_equal({ source: "my source", parent: "any" }, group[:field_values])
        assert_equal("", result.general_tags)
        assert_empty(result.field_values)
      end

      should("parse a recognized metatag into field_values") do
        result = FormParser.parse("rating:s")

        assert_equal({ rating: "s" }, result.field_values)
      end

      should("record a negated metatag's mode without affecting its value") do
        result = FormParser.parse("-score:>100")

        assert_equal({ score: ">100" }, result.field_values)
        assert_equal({ score: "must_not" }, result.field_modes)
      end

      should("record a should (~) metatag's mode") do
        result = FormParser.parse("~score:>100")

        assert_equal({ score: "should" }, result.field_modes)
      end

      should("not record a mode for a non-negatable field") do
        result = FormParser.parse("order:score")

        assert_equal({ order: "score" }, result.field_values)
        assert_empty(result.field_modes)
      end

      should("strip surrounding quotes from a quoted metatag value") do
        result = FormParser.parse('source:"my source"')

        assert_equal({ source: "my source" }, result.field_values)
      end

      should("resolve a known metatag alias to its canonical field") do
        result = FormParser.parse("type:jpg")

        assert_equal({ filetype: "jpg" }, result.field_values)
      end

      should("accumulate a metatag given more than once into an array instead of overwriting it") do
        result = FormParser.parse("locked:rating locked:status")

        assert_equal({ locked: %w[rating status] }, result.field_values)
      end

      should("accumulate per-occurrence modes alongside a repeated metatag's values") do
        result = FormParser.parse("locked:rating -locked:status")

        assert_equal({ locked: %w[rating status] }, result.field_values)
        assert_equal({ locked: %w[must must_not] }, result.field_modes)
      end

      should("leave an unrecognized metatag as a general/bare tag") do
        result = FormParser.parse("not_a_real_metatag:foo")

        assert_equal("not_a_real_metatag:foo", result.general_tags)
        assert_empty(result.field_values)
      end

      should("handle a mix of general tags, groups, and fields together") do
        result = FormParser.parse("solo {fluffy_(oc) blue_eyes} rating:s -score:>100 duo")

        assert_equal("solo duo", result.general_tags)
        assert_equal([{ tags: "fluffy_(oc) blue_eyes", mode: "must" }], result.character_groups)
        assert_equal({ rating: "s", score: ">100" }, result.field_values)
        assert_equal({ rating: "must", score: "must_not" }, result.field_modes)
      end

      should("round-trip through QueryBuilder back to an equivalent query") do
        original = "solo {fluffy_(oc) blue_eyes} rating:s -score:>100 order:id_desc"
        parsed = FormParser.parse(original)

        rebuilt = QueryBuilder.build(
          { general_tags: parsed.general_tags, character_groups: parsed.character_groups }
            .merge(parsed.field_values)
            .merge(parsed.field_modes.transform_keys { |k| :"#{k}_mode" }),
        )

        assert_equal(TagQuery.new(original, create(:user))[:tags], TagQuery.new(rebuilt, create(:user))[:tags])
        assert_equal(TagQuery.new(original, create(:user))[:tag_groups], TagQuery.new(rebuilt, create(:user))[:tag_groups])
        assert_equal(TagQuery.new(original, create(:user))[:rating], TagQuery.new(rebuilt, create(:user))[:rating])
        assert_equal(TagQuery.new(original, create(:user))[:order], TagQuery.new(rebuilt, create(:user))[:order])
      end

      should("round-trip a metatag given more than once without dropping either occurrence") do
        original = "locked:rating -locked:status"
        parsed = FormParser.parse(original)

        rebuilt = QueryBuilder.build(
          { general_tags: parsed.general_tags, character_groups: parsed.character_groups }
            .merge(parsed.field_values)
            .merge(parsed.field_modes.transform_keys { |k| :"#{k}_mode" }),
        )

        assert_equal(TagQuery.new(original, create(:user))[:locked], TagQuery.new(rebuilt, create(:user))[:locked])
        assert_equal(TagQuery.new(original, create(:user))[:locked_must_not], TagQuery.new(rebuilt, create(:user))[:locked_must_not])
      end

      should("round-trip a () group back to an equivalent query") do
        original = "solo -( male duo ) rating:s"
        parsed = FormParser.parse(original)

        rebuilt = QueryBuilder.build(
          { general_tags: parsed.general_tags, bool_groups: parsed.bool_groups }
            .merge(parsed.field_values)
            .merge(parsed.field_modes.transform_keys { |k| :"#{k}_mode" }),
        )

        original_query = TagQuery.new(original, create(:user))
        rebuilt_query = TagQuery.new(rebuilt, create(:user))

        assert_equal(original_query[:tags], rebuilt_query[:tags])
        assert_equal(original_query[:rating], rebuilt_query[:rating])
        assert_equal(1, rebuilt_query[:groups][:must_not].size)
        assert_equal(%w[male duo], rebuilt_query[:groups][:must_not].first[:tags][:must])
      end

      should("round-trip a () group containing a metatag, recomposing its extracted field_values the way the search builder's UI does") do
        original = "solo -( male chartags:>0 )"
        parsed = FormParser.parse(original)
        group = parsed.bool_groups.first

        # Mirrors post_search_builder.vue's composedBoolGroupTags - the group's plain tags text
        # plus a rendered token for each metatag piece added to it (mode prefix included).
        field_tokens = group[:field_values].map do |metatag, value|
          prefix = { "must_not" => "-", "should" => "~" }[group[:field_modes][metatag]] || ""
          "#{prefix}#{metatag}:#{value}"
        end
        recomposed_tags = [group[:tags], *field_tokens].compact_blank.join(" ")

        rebuilt = QueryBuilder.build(general_tags: parsed.general_tags, bool_groups: [{ tags: recomposed_tags, mode: group[:mode] }])

        original_query = TagQuery.new(original, create(:user))
        rebuilt_query = TagQuery.new(rebuilt, create(:user))

        assert_equal(original_query[:groups][:must_not].first.q, rebuilt_query[:groups][:must_not].first.q)
      end
    end
  end
end

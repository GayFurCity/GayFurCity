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
    end
  end
end

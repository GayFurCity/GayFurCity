# frozen_string_literal: true

require("test_helper")

module PostSearch
  class QueryBuilderTest < ActiveSupport::TestCase
    context("PostSearch::QueryBuilder") do
      should("build general tags as bare tokens") do
        assert_equal("solo duo", QueryBuilder.build(general_tags: "solo duo"))
      end

      should("build a positive {} character group") do
        result = QueryBuilder.build(character_groups: [{ tags: ["fluffy_(oc)", "blue_eyes"], mode: "must" }])

        assert_equal("{fluffy_(oc) blue_eyes}", result)
      end

      should("build a negated {} character group when mode is must_not") do
        result = QueryBuilder.build(character_groups: [{ tags: ["fluffy_(oc)"], mode: "must_not" }])

        assert_equal("-{fluffy_(oc)}", result)
      end

      should("skip a character group with no tags") do
        result = QueryBuilder.build(character_groups: [{ tags: [], mode: "must" }])

        assert_equal("", result)
      end

      should("accept character_groups as a Hash keyed by index, matching real form submission") do
        result = QueryBuilder.build(character_groups: { "0" => { tags: ["fluffy_(oc)"], mode: "must" } })

        assert_equal("{fluffy_(oc)}", result)
      end

      should("build a positive () tag group") do
        result = QueryBuilder.build(bool_groups: [{ tags: "solo duo", mode: "must" }])

        assert_equal("(solo duo)", result)
      end

      should("build a negated () tag group when mode is must_not") do
        result = QueryBuilder.build(bool_groups: [{ tags: "solo duo", mode: "must_not" }])

        assert_equal("-(solo duo)", result)
      end

      should("build an optional () tag group when mode is should") do
        result = QueryBuilder.build(bool_groups: [{ tags: "solo duo", mode: "should" }])

        assert_equal("~(solo duo)", result)
      end

      should("skip a () tag group with no tags") do
        result = QueryBuilder.build(bool_groups: [{ tags: "", mode: "must" }])

        assert_equal("", result)
      end

      should("accept bool_groups as a Hash keyed by index, matching real form submission") do
        result = QueryBuilder.build(bool_groups: { "0" => { tags: "solo duo", mode: "must" } })

        assert_equal("(solo duo)", result)
      end

      should("unwrap a bool group's tags from the one-element array a real [] field name submits, not stringify the array itself") do
        params = ActionController::Parameters.new(
          bool_groups: { "0" => { tags: ["rating:s solo"], mode: "must" } },
        ).permit!

        result = QueryBuilder.build(params)

        assert_equal("(rating:s solo)", result)
      end

      should("keep a () tag group's inner text as-is instead of re-tokenizing it") do
        result = QueryBuilder.build(bool_groups: [{ tags: "rating:s ~( solo duo )", mode: "must" }])

        assert_equal("(rating:s ~( solo duo ))", result)
      end

      should("build a () tag group containing a quoted metatag value into a query TagQuery parses back correctly") do
        result = QueryBuilder.build(bool_groups: [{ tags: %(parent:any source:"my source" solo), mode: "must" }])

        assert_equal(%((parent:any source:"my source" solo)), result)

        subquery = TagQuery.new(result, create(:user))[:groups][:must].first

        assert_equal(["solo"], subquery[:tags][:must])
        assert_equal("any", subquery[:parent])
        assert_equal(["my source*"], subquery[:sources])
      end

      should("build a plain field as metatag:value") do
        assert_equal("rating:s", QueryBuilder.build(rating: "s"))
      end

      should("prefix a field with - when its mode is must_not") do
        assert_equal("-score:>100", QueryBuilder.build(score: ">100", score_mode: "must_not"))
      end

      should("prefix a field with ~ when its mode is should") do
        assert_equal("~score:>100", QueryBuilder.build(score: ">100", score_mode: "should"))
      end

      should("not prefix a field when its mode is must (the default)") do
        assert_equal("score:>100", QueryBuilder.build(score: ">100", score_mode: "must"))
      end

      should("build a boolean field as metatag:value without a negation prefix") do
        assert_equal("hassource:true", QueryBuilder.build(hassource: "true"))
      end

      should("quote a field value that contains a space") do
        assert_equal('source:"my source"', QueryBuilder.build(source: "my source"))
      end

      should("omit a field whose value is blank") do
        assert_equal("", QueryBuilder.build(rating: "", score: "  "))
      end

      should("combine general tags, groups, () tag groups, and fields in that order") do
        result = QueryBuilder.build(
          general_tags:     "solo",
          character_groups: [{ tags: ["fluffy_(oc)"], mode: "must" }],
          bool_groups:      [{ tags: "duo trio", mode: "must" }],
          rating:           "s",
        )

        assert_equal("solo {fluffy_(oc)} (duo trio) rating:s", result)
      end

      should("build one token per value when a field's value is an array, matching modes by index") do
        result = QueryBuilder.build(locked: %w[rating status], locked_mode: %w[must must_not])

        assert_equal("locked:rating -locked:status", result)
      end

      should("build a single token for a one-element array the same as a plain scalar") do
        assert_equal("rating:s", QueryBuilder.build(rating: ["s"]))
      end

      should("produce a string TagQuery can parse back without error") do
        result = QueryBuilder.build(
          general_tags:     "solo",
          character_groups: [{ tags: ["fluffy_(oc)", "blue_eyes"], mode: "must" }],
          bool_groups:      [{ tags: "male duo", mode: "must_not" }],
          rating:           "s",
          score:            ">100",
          score_mode:       "must_not",
        )

        query = TagQuery.new(result, create(:user))

        assert_equal(["solo"], query[:tags][:must])
        assert_equal([%w[fluffy_(oc) blue_eyes]], query[:tag_groups][:must])
        assert_equal(%w[male duo], query[:groups][:must_not].first[:tags][:must])
        assert_equal("s", query[:rating]&.first)
      end
    end
  end
end

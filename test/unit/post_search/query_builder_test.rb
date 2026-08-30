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

      should("combine general tags, groups, and fields in that order") do
        result = QueryBuilder.build(
          general_tags:     "solo",
          character_groups: [{ tags: ["fluffy_(oc)"], mode: "must" }],
          rating:           "s",
        )

        assert_equal("solo {fluffy_(oc)} rating:s", result)
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
          rating:           "s",
          score:            ">100",
          score_mode:       "must_not",
        )

        query = TagQuery.new(result, create(:user))

        assert_equal(["solo"], query[:tags][:must])
        assert_equal([%w[fluffy_(oc) blue_eyes]], query[:tag_groups][:must])
        assert_equal("s", query[:rating]&.first)
      end
    end
  end
end

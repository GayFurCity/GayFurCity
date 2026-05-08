# frozen_string_literal: true

require("test_helper")
require_relative("helper")

module ModActions
  class TagImplicationsTest < ActiveSupport::TestCase
    include(Helper)
    include(Rails.application.routes.url_helpers)

    context("mod actions for tag implications") do
      should("format tag_implication_create correctly") do
        @implication = create(:tag_implication, antecedent_name: "aaa", consequent_name: "bbb", creator: @admin)

        assert_matches(
          actions:          %w[tag_implication_create],
          text:             "Created \"tag implication ##{@implication.id}\":[#{tag_implication_path(@implication)}]: [[aaa]] -> [[bbb]]",
          subject:          @implication,
          implication_desc: "\"tag implication ##{@implication.id}\":[#{tag_implication_path(@implication)}]: [[aaa]] -> [[bbb]]",
        )
      end

      should("format tag_implication_update correctly") do
        @implication = create(:tag_implication, antecedent_name: "aaa", consequent_name: "bbb", creator: @admin)
        set_count!
        @implication.update_with!(@admin, status: "pending")

        assert_matches(
          actions:          %w[tag_implication_update],
          text:             "Updated \"tag implication ##{@implication.id}\":[#{tag_implication_path(@implication)}]: [[aaa]] -> [[bbb]]\nchanged status from \"active\" to \"pending\"",
          subject:          @implication,
          implication_desc: "\"tag implication ##{@implication.id}\":[#{tag_implication_path(@implication)}]: [[aaa]] -> [[bbb]]",
          change_desc:      "changed status from \"active\" to \"pending\"",
        )
      end
    end
  end
end

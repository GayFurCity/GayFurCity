# frozen_string_literal: true

require("test_helper")
require_relative("helper")

module ModActions
  class TagAliasesTest < ActiveSupport::TestCase
    include(Helper)
    include(Rails.application.routes.url_helpers)

    context("mod actions for tag aliases") do
      should("format tag_alias_create correctly") do
        @alias = create(:tag_alias, antecedent_name: "aaa", consequent_name: "bbb", creator: @admin)

        assert_matches(
          actions:    %w[tag_alias_create],
          text:       "Created \"tag alias ##{@alias.id}\":[#{tag_alias_path(@alias)}]: [[aaa]] -> [[bbb]]",
          subject:    @alias,
          alias_desc: "\"tag alias ##{@alias.id}\":[#{tag_alias_path(@alias)}]: [[aaa]] -> [[bbb]]",
        )
      end

      should("format tag_alias_update correctly") do
        @alias = create(:tag_alias, antecedent_name: "aaa", consequent_name: "bbb", creator: @admin)
        set_count!
        @alias.update_with!(@admin, status: "pending")

        assert_matches(
          actions:     %w[tag_alias_update],
          text:        "Updated \"tag alias ##{@alias.id}\":[#{tag_alias_path(@alias)}]: [[aaa]] -> [[bbb]]\nchanged status from \"active\" to \"pending\"",
          subject:     @alias,
          alias_desc:  "\"tag alias ##{@alias.id}\":[#{tag_alias_path(@alias)}]: [[aaa]] -> [[bbb]]",
          change_desc: "changed status from \"active\" to \"pending\"",
        )
      end
    end
  end
end

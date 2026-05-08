# frozen_string_literal: true

module ModActions
  include(Rails.application.routes.url_helpers)

  module Helper
    def self.included(mod)
      mod.setup do
        @admin = create(:admin_user)
        @user = create(:user)
        set_count!
      end

      mod.define_method(:set_count!, -> {
        @count = ModAction.count
      })
    end

    def user(user)
      "\"#{user.name}\":#{user_path(user)}"
    end

    def assert_matches(actions:, text:, subject:, creator: @admin, **attributes)
      diff = ModAction.count - @count

      assert_equal(actions.length, diff, "modaction count diff (#{ModAction.last(diff).map(&:action).join(', ')})")
      assert_same_elements(actions, ModAction.last(actions.length).map(&:action), "actions")

      # fetch the modaction we're actually testing
      modaction = ModAction.where(action: actions[0]).last

      assert_not_nil(modaction, "modaction (#{actions[0]})")
      assert_equal(creator.id, modaction.creator_id, "creator")

      # check the subject matches, if present
      if subject.present?
        assert_equal(subject.class.name, modaction.subject_type, "subject type")
        assert_equal(subject.id, modaction.subject_id, "subject id")
      end

      # check the attributes match
      attributes.each do |key, value|
        assert_includes(ModAction.local_stored_attributes[:values], key, "values->#{key} is not included in store")
        if value.nil? # thanks minitest
          assert_nil(modaction.values[key.to_s], "values->#{key} (#{modaction.values.inspect})")
        else
          assert_equal(value, modaction.values[key.to_s], "values->#{key} (#{modaction.values.inspect})")
        end
      end

      # check the formatted text and json match
      assert_equal(text, modaction.format_text, "formatted text")
      assert_equal(attributes, modaction.format_json, "formatted json")
    end
  end
end

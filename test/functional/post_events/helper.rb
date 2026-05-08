# frozen_string_literal: true

module PostEvents
  include(Rails.application.routes.url_helpers)

  module Helper
    def self.included(mod)
      mod.setup do
        @admin = create(:admin_user)
        @user = create(:user)
        set_count!
      end

      mod.define_method(:set_count!, -> {
        @count = PostEvent.count
      })
    end

    def assert_matches(post_id:, actions:, text:, creator: @admin, **attributes)
      diff = PostEvent.count - @count

      assert_equal(actions.length, diff, "post event count diff (#{PostEvent.last(diff).map(&:action).join(', ')})")
      assert_same_elements(actions, PostEvent.last(actions.length).map(&:action), "actions")

      # fetch the post event we're actually testing
      post_event = PostEvent.where(action: actions[0]).last

      assert_not_nil(post_event, "post event (#{actions[0]})")
      assert_equal(creator.id, post_event.creator_id, "creator")
      assert_equal(post_id, post_event.post_id, "post")
      # check the attributes match
      attributes.each do |key, value|
        assert_includes(PostEvent.local_stored_attributes[:extra_data], key, "extra_data->#{key} is not included in store")
        if value.nil? # thanks minitest
          assert_nil(post_event.extra_data[key.to_s], "extra_data->#{key} (#{post_event.extra_data.inspect})")
        else
          assert_equal(value, post_event.extra_data[key.to_s], "extra_data->#{key} (#{post_event.extra_data.inspect})")
        end
      end

      # check the formatted text and json match
      assert_equal(text, post_event.format_text, "formatted text")
      assert_equal(attributes, post_event.format_json, "formatted json")
    end
  end
end

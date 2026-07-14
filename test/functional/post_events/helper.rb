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
      assert_event_count(actions)

      # fetch the post event we're actually testing
      assert_event_matches(action: actions[0], post_id: post_id, text: text, creator: creator, **attributes)
    end

    # Like assert_matches, but for verifying every event in a set of simultaneously-created events
    # (e.g. give_favorites_to_parent! creates both favorites_moved on the child and
    # favorites_received on the parent in one call) - each can have its own post_id/text/attributes,
    # since simultaneous events don't necessarily belong to the same post or format the same way.
    def assert_matches_all(events)
      assert_event_count(events.pluck(:action))

      events.each { |event| assert_event_matches(**event) }
    end

    private

    def assert_event_count(actions)
      diff = PostEvent.count - @count

      assert_equal(actions.length, diff, "post event count diff (#{PostEvent.last(diff).map(&:action).join(', ')})")
      assert_same_elements(actions, PostEvent.last(actions.length).map(&:action), "actions")
    end

    def assert_event_matches(action:, post_id:, text:, creator: @admin, **attributes)
      post_event = PostEvent.where(action: action).last

      assert_not_nil(post_event, "post event (#{action})")
      assert_equal(creator.id, post_event.creator_id, "creator (#{action})")
      assert_equal(post_id, post_event.post_id, "post (#{action})")
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
      assert_equal(text, post_event.format_text, "formatted text (#{action})")
      assert_equal(attributes, post_event.format_json, "formatted json (#{action})")
    end
  end
end

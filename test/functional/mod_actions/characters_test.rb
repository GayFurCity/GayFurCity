# frozen_string_literal: true

require("test_helper")
require_relative("helper")

module ModActions
  class CharactersTest < ActiveSupport::TestCase
    include(Helper)
    include(Rails.application.routes.url_helpers)

    context("mod actions for characters") do
      setup do
        @character = create(:character)
        set_count!
      end

      should("parse character_lock correctly") do
        @character.update_with!(@admin, is_locked: true)

        assert_matches(
          actions: %w[character_lock],
          text:    "Locked character ##{@character.id}",
          subject: @character,
        )
      end

      should("parse character_rename correctly") do
        @original = @character.dup
        @character.update_with!(@admin, name: "xxx")

        assert_matches(
          actions:  %w[character_rename],
          text:     <<~TEXT.strip,
            Renamed character ##{@character.id} ("#{@original.name}":#{show_or_new_characters_path(name: @original.name)} -> "#{@character.name}":#{show_or_new_characters_path(name: @character.name)})
          TEXT
          subject:  @character,
          new_name: @character.name,
          old_name: @original.name,
        )
      end

      should("parse character_unlock correctly") do
        @character.update_columns(is_locked: true)
        @character.update_with!(@admin, is_locked: false)

        assert_matches(
          actions: %w[character_unlock],
          text:    "Unlocked character ##{@character.id}",
          subject: @character,
        )
      end

      should("parse character_owner_link correctly") do
        @character.update_with!(@admin, owner_user_id: @user.id)

        assert_matches(
          actions: %w[character_owner_link],
          text:    "Set #{user(@user)} as owner of character ##{@character.id}",
          subject: @character,
          user_id: @user.id,
        )
      end

      should("parse character_owner_unlink correctly") do
        @character.update_columns(owner_user_id: @user.id)
        @character.update_with!(@admin, owner_user_id: nil)

        assert_matches(
          actions: %w[character_owner_unlink],
          text:    "Removed #{user(@user)} as owner of character ##{@character.id}",
          subject: @character,
          user_id: @user.id,
        )
      end

      should("parse character_delete correctly") do
        @character.destroy_with!(@admin)

        assert_matches(
          actions: %w[character_delete],
          text:    "Deleted character ##{@character.id} (#{@character.name})",
          subject: @character,
          name:    @character.name,
        )
      end
    end
  end
end

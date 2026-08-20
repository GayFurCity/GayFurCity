# frozen_string_literal: true

require("test_helper")
require_relative("helper")

module ModActions
  class ArtistsTest < ActiveSupport::TestCase
    include(Helper)
    include(Rails.application.routes.url_helpers)

    context("mod actions for artists") do
      setup do
        @artist = create(:artist)
        set_count!
      end

      should("parse artist_lock correctly") do
        @artist.update_with!(@admin, is_locked: true)

        assert_matches(
          actions: %w[artist_lock],
          text:    "Locked artist ##{@artist.id}",
          subject: @artist,
        )
      end

      should("parse artist_rename correctly") do
        @original = @artist.dup
        @artist.update_with!(@admin, name: "xxx")

        assert_matches(
          actions:  %w[artist_rename],
          text:     <<~TEXT.strip,
            Renamed artist ##{@artist.id} ("#{@original.name}":#{show_or_new_artists_path(name: @original.name)} -> "#{@artist.name}":#{show_or_new_artists_path(name: @artist.name)})
          TEXT
          subject:  @artist,
          new_name: @artist.name,
          old_name: @original.name,
        )
      end

      should("parse artist_unlock correctly") do
        @artist.update_columns(is_locked: true)
        @artist.update_with!(@admin, is_locked: false)

        assert_matches(
          actions: %w[artist_unlock],
          text:    "Unlocked artist ##{@artist.id}",
          subject: @artist,
        )
      end

      should("parse artist_user_link correctly") do
        @artist.update_with!(@admin, linked_user_id: @user.id)

        assert_matches(
          actions: %w[artist_user_link],
          text:    "Linked #{user(@user)} to artist ##{@artist.id}",
          subject: @artist,
          user_id: @user.id,
        )
      end

      should("parse artist_user_unlink correctly") do
        @artist.update_columns(linked_user_id: @user.id)
        @artist.update_with!(@admin, linked_user_id: nil)

        assert_matches(
          actions: %w[artist_user_unlink],
          text:    "Unlinked #{user(@user)} from artist ##{@artist.id}",
          subject: @artist,
          user_id: @user.id,
        )
      end

      should("parse artist_delete correctly") do
        @artist.destroy_with!(@admin)

        assert_matches(
          actions: %w[artist_delete],
          text:    "Deleted artist ##{@artist.id} (#{@artist.name})",
          subject: @artist,
          name:    @artist.name,
        )
      end
    end
  end
end

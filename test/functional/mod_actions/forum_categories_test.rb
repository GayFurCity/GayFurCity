# frozen_string_literal: true

require("test_helper")
require_relative("helper")

module ModActions
  class ForumCategoriesTest < ActiveSupport::TestCase
    include(Helper)
    include(Rails.application.routes.url_helpers)

    context("mod actions for forum categories") do
      setup do
        @category = create(:forum_category, can_view: User::Levels::TRUSTED, creator: @admin)
        @trusted = create(:trusted_user)
        set_count!
      end

      context("forum_category_create") do
        setup do
          @category = create(:forum_category, can_view: User::Levels::TRUSTED, creator: @admin)
        end

        should("format correctly for users that can see the category") do
          CurrentUser.scoped(@trusted) do # rubocop:disable YiffSpace/CurrentOutsideOfRequests
            assert_matches(
              actions:             %w[forum_category_create],
              text:                <<~TEXT.strip,
                Created forum category ##{@category.id} (#{@category.name})
                Restricted viewing topics to #{User::Levels.id_to_name(@category.can_view)}
                Restricted creating topics to #{User::Levels.id_to_name(@category.can_create)}
              TEXT
              subject:             @category,
              creator:             @admin,
              forum_category_name: @category.name,
              can_view:            @category.can_view,
              can_create:          @category.can_create,
            )
          end
        end

        should("format correctly for users that cannot see the category") do
          CurrentUser.scoped(@user) do # rubocop:disable YiffSpace/CurrentOutsideOfRequests
            assert_matches(
              actions: %w[forum_category_create],
              text:    "Created forum category ##{@category.id}",
              subject: @category,
              creator: @admin,
            )
          end
        end
      end

      context("forum_category_delete") do
        should("format correctly for users that can see the category") do
          @category.destroy_with!(@admin)

          CurrentUser.scoped(@trusted) do # rubocop:disable YiffSpace/CurrentOutsideOfRequests
            assert_matches(
              actions:             %w[forum_category_delete],
              text:                "Deleted forum category ##{@category.id} (#{@category.name})",
              subject:             @category,
              forum_category_name: @category.name,
              can_view:            @category.can_view,
              can_create:          @category.can_create,
            )
          end
        end

        should("format correctly for users that cannot see the category") do
          @category.destroy_with!(@admin)

          CurrentUser.scoped(@user) do # rubocop:disable YiffSpace/CurrentOutsideOfRequests
            assert_matches(
              actions: %w[forum_category_delete],
              text:    "Deleted forum category ##{@category.id}",
              subject: @category,
              creator: @admin,
            )
          end
        end
      end

      context("forum_category_topics_move") do
        setup do
          @topic = create(:forum_topic, category: @category, creator: @admin)
          @category2 = create(:forum_category, can_view: User::Levels::TRUSTED, creator: @admin)
          set_count!
        end

        should("format correctly for users that can see the category") do
          with_inline_jobs { @category.move_all_topics(@category2, @admin) }

          CurrentUser.scoped(@trusted) do # rubocop:disable YiffSpace/CurrentOutsideOfRequests
            assert_matches(
              actions:                 %w[forum_category_topics_move forum_category_update forum_category_update],
              text:                    "Moved all topics in [#{@category.name}](#{forum_category_path(@category)}) to [#{@category2.name}](#{forum_category_path(@category2)})",
              subject:                 @category,
              creator:                 @admin,
              forum_category_name:     @category2.name,
              old_forum_category_name: @category.name,
              can_view:                @category2.can_view,
              old_can_view:            @category.can_view,
              forum_category_id:       @category2.id,
              old_forum_category_id:   @category.id,
            )
          end
        end

        should("format correctly for users that cannot see the category") do
          with_inline_jobs { @category.move_all_topics(@category2, @admin) }

          CurrentUser.scoped(@user) do # rubocop:disable YiffSpace/CurrentOutsideOfRequests
            assert_matches(
              actions:               %w[forum_category_topics_move forum_category_update forum_category_update],
              text:                  "Moved all topics in category ##{@category.id} to category ##{@category2.id}",
              subject:               @category,
              creator:               @admin,
              forum_category_id:     @category2.id,
              old_forum_category_id: @category.id,
            )
          end
        end
      end

      context("forum_category_update") do
        setup do
          @original = @category.dup
        end

        context("with no changes") do
          should("format correctly for users that can see the category") do
            @category.update_with!(@admin)

            CurrentUser.scoped(@trusted) do # rubocop:disable YiffSpace/CurrentOutsideOfRequests
              assert_matches(
                actions:                 %w[forum_category_update],
                text:                    "Updated forum category ##{@category.id} (#{@category.name})",
                subject:                 @category,
                creator:                 @admin,
                forum_category_name:     @category.name,
                old_forum_category_name: @original.name,
                can_view:                @category.can_view,
                old_can_view:            @original.can_view,
                can_create:              @category.can_create,
                old_can_create:          @original.can_create,
              )
            end
          end

          should("format correctly for users that cannot see the category") do
            @category.update_with!(@admin)

            CurrentUser.scoped(@user) do # rubocop:disable YiffSpace/CurrentOutsideOfRequests
              assert_matches(
                actions: %w[forum_category_update],
                text:    "Updated forum category ##{@category.id}",
                subject: @category,
                creator: @admin,
              )
            end
          end
        end

        context("with name change") do
          should("format correctly for users that can see the category") do
            @category.update_with!(@admin, name: "xxx")

            CurrentUser.scoped(@trusted) do # rubocop:disable YiffSpace/CurrentOutsideOfRequests
              assert_matches(
                actions:                 %w[forum_category_update],
                text:                    <<~TEXT.strip,
                  Updated forum category ##{@category.id} (#{@category.name})
                  Changed name from "#{@original.name}" to "#{@category.name}"
                TEXT
                subject:                 @category,
                creator:                 @admin,
                forum_category_name:     @category.name,
                old_forum_category_name: @original.name,
                can_view:                @category.can_view,
                old_can_view:            @original.can_view,
                can_create:              @category.can_create,
                old_can_create:          @original.can_create,
              )
            end
          end

          should("format correctly for users that cannot see the category") do
            @category.update_with!(@admin, name: "xxx")

            CurrentUser.scoped(@user) do # rubocop:disable YiffSpace/CurrentOutsideOfRequests
              assert_matches(
                actions: %w[forum_category_update],
                text:    "Updated forum category ##{@category.id}",
                subject: @category,
                creator: @admin,
              )
            end
          end
        end

        context("with can_view change") do
          should("format correctly for users that can see the category") do
            @category.update_with!(@admin, can_view: User::Levels::ADMIN)

            CurrentUser.scoped(@admin) do # rubocop:disable YiffSpace/CurrentOutsideOfRequests
              assert_matches(
                actions:                 %w[forum_category_update],
                text:                    <<~TEXT.strip,
                  Updated forum category ##{@category.id} (#{@category.name})
                  Restricted viewing topics to #{User::Levels.id_to_name(@category.can_view)} (Previously #{User::Levels.id_to_name(@original.can_view)})
                TEXT
                subject:                 @category,
                creator:                 @admin,
                forum_category_name:     @category.name,
                old_forum_category_name: @original.name,
                can_view:                @category.can_view,
                old_can_view:            @original.can_view,
                can_create:              @category.can_create,
                old_can_create:          @original.can_create,
              )
            end
          end

          should("format correctly for users that cannot see the category") do
            @category.update_with!(@admin, can_view: User::Levels::ADMIN)

            CurrentUser.scoped(@user) do # rubocop:disable YiffSpace/CurrentOutsideOfRequests
              assert_matches(
                actions: %w[forum_category_update],
                text:    "Updated forum category ##{@category.id}",
                subject: @category,
                creator: @admin,
              )
            end
          end
        end

        context("with can_create change") do
          should("format correctly for users that can see the category") do
            @category.update_with!(@admin, can_create: User::Levels::ADMIN)

            CurrentUser.scoped(@admin) do # rubocop:disable YiffSpace/CurrentOutsideOfRequests
              assert_matches(
                actions:                 %w[forum_category_update],
                text:                    <<~TEXT.strip,
                  Updated forum category ##{@category.id} (#{@category.name})
                  Restricted creating topics to #{User::Levels.id_to_name(@category.can_create)} (Previously #{User::Levels.id_to_name(@original.can_create)})
                TEXT
                subject:                 @category,
                creator:                 @admin,
                forum_category_name:     @category.name,
                old_forum_category_name: @original.name,
                can_view:                @category.can_view,
                old_can_view:            @original.can_view,
                can_create:              @category.can_create,
                old_can_create:          @original.can_create,
              )
            end
          end

          should("format correctly for users that cannot see the category") do
            @category.update_with!(@admin, can_create: User::Levels::ADMIN)

            CurrentUser.scoped(@user) do # rubocop:disable YiffSpace/CurrentOutsideOfRequests
              assert_matches(
                actions: %w[forum_category_update],
                text:    "Updated forum category ##{@category.id}",
                subject: @category,
                creator: @admin,
              )
            end
          end
        end

        context("with all changes") do
          should("format correctly for users that can see the category") do
            @category.update_with!(@admin, name: "xxx", can_view: User::Levels::ADMIN, can_create: User::Levels::ADMIN)

            CurrentUser.scoped(@admin) do # rubocop:disable YiffSpace/CurrentOutsideOfRequests
              assert_matches(
                actions:                 %w[forum_category_update],
                text:                    <<~TEXT.strip,
                  Updated forum category ##{@category.id} (#{@category.name})
                  Changed name from "#{@original.name}" to "#{@category.name}"
                  Restricted viewing topics to #{User::Levels.id_to_name(@category.can_view)} (Previously #{User::Levels.id_to_name(@original.can_view)})
                  Restricted creating topics to #{User::Levels.id_to_name(@category.can_create)} (Previously #{User::Levels.id_to_name(@original.can_create)})
                TEXT
                subject:                 @category,
                creator:                 @admin,
                forum_category_name:     @category.name,
                old_forum_category_name: @original.name,
                can_view:                @category.can_view,
                old_can_view:            @original.can_view,
                can_create:              @category.can_create,
                old_can_create:          @original.can_create,
              )
            end
          end

          should("format correctly for users that cannot see the category") do
            @category.update_with!(@admin, name: "xxx", can_view: User::Levels::ADMIN, can_create: User::Levels::ADMIN)

            CurrentUser.scoped(@user) do # rubocop:disable YiffSpace/CurrentOutsideOfRequests
              assert_matches(
                actions: %w[forum_category_update],
                text:    "Updated forum category ##{@category.id}",
                subject: @category,
                creator: @admin,
              )
            end
          end
        end
      end
    end
  end
end

# frozen_string_literal: true

require("test_helper")

class ForumTopicTest < ActiveSupport::TestCase
  context("A forum topic") do
    setup do
      @user = create(:user)
      @topic = create(:forum_topic, title: "xxx", original_post_attributes: { body: "aaa" }, creator: @user)
    end

    context("#read_by?") do
      context("with an existing visit") do
        setup do
          @user.forum_category_visits.find_or_create_by!(forum_category: @topic.category).update!(last_read_at: Time.now)
        end

        context("and last_post_created_at in the future") do
          setup do
            @topic.update_column(:last_post_created_at, 1.day.from_now)
          end

          should("return false") do
            assert_not(@topic.read_by?(@user))
          end

          should("return true if muted") do
            create(:forum_topic_status, user: @user, forum_topic: @topic, mute: true)

            assert(@topic.read_by?(@user))
          end
        end

        context("and last_post_created_at in the past") do
          setup do
            @topic.update_column(:last_post_created_at, 1.day.from_now)
          end

          context("that predates the topic") do
            setup do
              @user.forum_category_visits.find_or_create_by!(forum_category: @topic.category).update!(last_read_at: 16.hours.from_now)
            end

            should("return false") do
              assert_not(@topic.read_by?(@user))
            end

            should("return true if muted") do
              create(:forum_topic_status, user: @user, forum_topic: @topic, mute: true)

              assert(@topic.read_by?(@user))
            end
          end

          context("that postdates the topic") do
            setup do
              @user.forum_category_visits.find_or_create_by!(forum_category: @topic.category).update!(last_read_at: 2.days.from_now)
            end

            should("return true") do
              assert(@topic.read_by?(@user))
            end
          end
        end
      end

      context("with no existing visit") do
        context("and last_post_created_at in the future") do
          should("return false") do
            assert_not(@topic.read_by?(@user))
          end

          should("return true if muted") do
            create(:forum_topic_status, user: @user, forum_topic: @topic, mute: true)

            assert(@topic.read_by?(@user))
          end
        end

        context("and last_post_created_at in the past") do
          context("that predates the topic") do
            setup do
              @user.forum_category_visits.find_or_create_by!(forum_category: @topic.category).update!(last_read_at: 1.day.ago)
            end

            should("return false") do
              assert_not(@topic.read_by?(@user))
            end

            should("return true if muted") do
              create(:forum_topic_status, user: @user, forum_topic: @topic, mute: true)

              assert(@topic.read_by?(@user))
            end
          end

          context("that postdates the topic") do
            setup do
              @user.forum_category_visits.find_or_create_by!(forum_category: @topic.category).update!(last_read_at: 1.day.from_now)
            end

            should("return true") do
              assert(@topic.read_by?(@user))
            end
          end
        end
      end
    end

    context("#mark_as_read!") do
      context("without a previous visit") do
        should("create a new visit") do
          @topic.mark_as_read!(@user)
          visit = @user.forum_category_visits.find_by(forum_category: @topic.category)

          assert(visit)
          assert_in_delta(@topic.updated_at.to_i, visit.last_read_at.to_i, 1)
        end
      end

      context("with a previous visit") do
        setup do
          @user.forum_category_visits.find_or_create_by!(forum_category: @topic.category).update!(last_read_at: 1.day.ago)
        end

        should("update the visit") do
          @topic.mark_as_read!(@user)
          visit = @user.forum_category_visits.find_by(forum_category: @topic.category)

          assert(visit)
          assert_in_delta(@topic.updated_at.to_i, visit.last_read_at.to_i, 1)
        end
      end
    end

    context("constructed with nested attributes for its original post") do
      should("create a matching forum post") do
        assert_difference(%w[ForumTopic.count ForumPost.count], 1) do
          @topic = create(:forum_topic, title: "abc", original_post_attributes: { body: "abc" })
        end
      end
    end

    should("be searchable by title") do
      assert_equal(1, ForumTopic.attribute_matches(:title, "xxx").count)
      assert_equal(0, ForumTopic.attribute_matches(:title, "aaa").count)
    end

    should("be searchable by category id") do
      assert_equal(0, ForumTopic.search_current({ category_id: 0 }).count)
      assert_equal(1, ForumTopic.search_current({ category_id: AdminConfig.instance.alias_and_implication_forum_category }).count)
    end

    should("initialize its creator") do
      assert_equal(@user.id, @topic.creator_id)
    end

    context("updated by a second user") do
      setup do
        @second_user = create(:user)
      end

      should("record its updater") do
        @topic.update_with(@second_user, title: "abc")

        assert_equal(@second_user.id, @topic.updater_id)
      end
    end

    context("with multiple posts that has been deleted") do
      setup do
        create_list(:forum_post, 5, topic_id: @topic.id)
      end

      should("delete any associated posts") do
        assert_difference("ForumPost.count", -6) do
          @topic.destroy_with(@user)
        end
      end
    end

    context("that has an alias, implication, or bulk update request") do
      setup do
        @tag_alias = create(:tag_alias, forum_post: @topic.original_post)
        @topic.original_post.update_columns(tag_change_request_id: @tag_alias.id, tag_change_request_type: "TagAlias", allow_voting: true)
        @mod = create(:moderator_user)
      end

      should("only be hidable by moderators") do
        @topic.hide!(@user)

        assert_equal(["Topic is for an alias, implication, or bulk update request. It cannot be hidden"], @topic.errors.full_messages)
        assert_not(@topic.reload.is_hidden)

        @topic.hide!(@mod)

        assert_equal([], @topic.errors.full_messages)
        assert(@topic.reload.is_hidden)
      end
    end

    context("merge_into!") do
      should("merge the topic into the target topic") do
        @target = create(:forum_topic)
        @post = @topic.original_post
        assert_difference(%w[EditHistory.merged.count ModAction.count], 1) do
          @topic.merge_into!(@target, @user)
        end
        assert_equal(@target.id, @topic.merge_target_id)
        assert_equal(@target.id, @post.reload.topic_id)
        assert_equal({ "old_topic_id" => @topic.id, "old_topic_title" => @topic.title, "new_topic_id" => @target.id, "new_topic_title" => @target.title }, EditHistory.last.extra_data)
        assert_equal("forum_topic_merge", ModAction.last.action)
      end
    end

    context("undo_merge!") do
      setup do
        @target = create(:forum_topic)
        @post = @topic.original_post
        @topic.merge_into!(@target, @user)
      end

      should("undo the topic merge") do
        assert_difference(%w[EditHistory.unmerged.count ModAction.count], 1) do
          @topic.undo_merge!(@user)
        end
        assert_nil(@topic.merge_target_id)
        assert_nil(@topic.merged_at)
        assert_equal(@topic.id, @post.reload.topic_id)
        assert_equal({ "old_topic_id" => @target.id, "old_topic_title" => @target.title, "new_topic_id" => @topic.id, "new_topic_title" => @topic.title }, EditHistory.last.extra_data)
        assert_equal("forum_topic_unmerge", ModAction.last.action)
      end

      should("fail if the target no longer exists") do
        @target.destroy_with!(@user)
        assert_raises(ForumTopic::MergeError, "Merge target does not exist") { @topic.reload.undo_merge!(@user) }
      end
    end
  end
end

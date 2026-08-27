# frozen_string_literal: true

require("test_helper")

class ForumPostTest < ActiveSupport::TestCase
  context("A forum post") do
    setup do
      @user = create(:user)
      @mod = create(:moderator_user)
      @topic = create(:forum_topic, creator: @user)
    end

    context("that has an alias, implication, or bulk update request") do
      setup do
        @post = build(:forum_post, topic_id: @topic.id, body: "[[aaa]] -> [[bbb]]", creator: @user)
        @tag_alias = create(:tag_alias, forum_post: @post, creator: @user)
        @post.update_columns(tag_change_request_id: @tag_alias.id, tag_change_request_type: "TagAlias", allow_voting: true)
      end

      should("be votable") do
        assert_predicate(@post, :has_voting?)
      end

      should("only be hidable by moderators") do
        @post.hide!(@user)

        assert_equal(["Post is for an alias, implication, or bulk update request. It cannot be hidden"], @post.errors.full_messages)
        assert_not(@post.reload.is_hidden)

        @post.hide!(@mod)

        assert_equal([], @post.errors.full_messages)
        assert(@post.reload.is_hidden)
      end
    end

    context("that belongs to a topic with several pages of posts") do
      setup do
        AdminConfig.any_instance.stubs(:records_per_page).returns(3)
        @posts = []
        9.times do
          @posts << create(:forum_post, topic_id: @topic.id)
        end
        travel_to(2.seconds.from_now) do
          @posts << create(:forum_post, topic_id: @topic.id)
        end
      end

      context("that is deleted") do
        should("update the topic's updated_at timestamp") do
          @topic.reload

          assert_in_delta(@posts[-1].updated_at.to_i, @topic.updated_at.to_i, 1)
          @posts[-1].hide!(@user)
          @topic.reload

          assert_in_delta(@posts[-2].updated_at.to_i, @topic.updated_at.to_i, 1)
        end
      end

      should("know which page it's on") do
        assert_equal(2, @posts[3].forum_topic_page)
        assert_equal(2, @posts[4].forum_topic_page)
        assert_equal(3, @posts[5].forum_topic_page)
        assert_equal(3, @posts[6].forum_topic_page)
      end

      should("update the topic's updated_at when destroyed") do
        @posts.last.destroy_with(@user)
        @topic.reload

        assert_equal(@posts[8].updated_at.to_s, @topic.updated_at.to_s)
      end
    end

    context("belonging to a locked topic") do
      setup do
        @post = create(:forum_post, topic_id: @topic.id, body: "zzz")
        @topic.update_attribute(:is_locked, true)
        @post.reload
      end

      should("not be updateable") do
        @post.update_with(@user, body: "xxx")
        @post.reload

        assert_equal("zzz", @post.body)
      end

      should("not be deletable") do
        assert_no_difference("ForumPost.count") do
          @post.destroy_with(@user)
        end
      end
    end

    should("update the topic when created") do
      @original_topic_updated_at = @topic.updated_at
      travel_to(1.second.from_now) do
        create(:forum_post, topic_id: @topic.id)
      end
      @topic.reload

      assert_not_equal(@original_topic_updated_at.to_s, @topic.updated_at.to_s)
    end

    should("be searchable by body content") do
      create(:forum_post, topic_id: @topic.id, body: "xxx")

      assert_equal(1, ForumPost.search_current({ body_matches: "xxx" }).count)
      assert_equal(0, ForumPost.search_current({ body_matches: "aaa" }).count)
    end

    should("initialize its creator") do
      post = create(:forum_post, topic_id: @topic.id, creator: @user)

      assert_equal(@user.id, post.creator_id)
    end

    context("that is edited by a moderator") do
      setup do
        @post = create(:forum_post, topic_id: @topic.id)
      end

      should("create a mod action") do
        assert_difference(-> { ModAction.count }, 1) do
          @post.update_with(@mod, body: "nope")
        end
      end

      should("credit the moderator as the updater") do
        @post.update_with(@mod, body: "test")

        assert_equal(@mod.id, @post.updater_id)
      end
    end

    context("that is hidden by a moderator") do
      setup do
        @post = create(:forum_post, topic_id: @topic.id)
      end

      should("create a mod action") do
        assert_difference(-> { ModAction.count }, 1) do
          @post.hide!(@mod)
        end
      end

      should("credit the moderator as the updater") do
        @post.hide!(@mod)

        assert_equal(@mod.id, @post.updater_id)
      end
    end

    context("that is deleted") do
      setup do
        @post = create(:forum_post, topic_id: @topic.id)
      end

      should("create a mod action") do
        assert_difference(-> { ModAction.count }, 1) do
          @post.destroy_with(@mod)
        end
      end
    end

    context("during validation") do
      subject { build(:forum_post) }
      should_not(allow_value(" ").for(:body))
    end

    context("when modified") do
      setup do
        @forum_post = create(:forum_post, topic_id: @topic.id, creator: @user)
        original_body = @forum_post.body
        @forum_post.class_eval do
          after_save do
            if @body_history.nil?
              @body_history = [original_body]
            end
            @body_history.push(body)
          end

          define_method(:body_history) do
            @body_history
          end
        end
      end

      instance_exec do
        define_method(:verify_history) do |history, forum_post, edit_type, user = forum_post.creator_id|
          throw("history is nil (#{forum_post.id}:#{edit_type}:#{user}:#{forum_post.creator_id})") if history.nil?

          assert_equal(forum_post.body_history[history.version - 1], history.body, "history body did not match")
          assert_equal(edit_type, history.edit_type, "history edit_type did not match")
          assert_equal(user, history.updater_id, "history updater_id did not match")
        end
      end

      should("create edit histories when body is changed") do
        assert_difference("EditHistory.count", 3) do
          @forum_post.update_with(@user, body: "test")
          @forum_post.update_with(@mod, body: "test2")

          original, edit, edit2 = EditHistory.where(versionable_id: @forum_post.id).order(version: :asc)
          verify_history(original, @forum_post, "original", @user.id)
          verify_history(edit, @forum_post, "edit", @user.id)
          verify_history(edit2, @forum_post, "edit", @mod.id)
        end
      end

      should("create edit histories when hidden is changed") do
        assert_difference("EditHistory.count", 3) do
          @forum_post.hide!(@user)
          @forum_post.unhide!(@mod)

          original, hide, unhide = EditHistory.where(versionable_id: @forum_post.id).order(version: :asc)
          verify_history(original, @forum_post, "original")
          verify_history(hide, @forum_post, "hide")
          verify_history(unhide, @forum_post, "unhide", @mod.id)
        end
      end

      should("create edit histories when warning is changed") do
        assert_difference("EditHistory.count", 7) do
          @forum_post.user_warned!("warning", @mod)
          @forum_post.remove_user_warning!(@mod)
          @forum_post.user_warned!("record", @mod)
          @forum_post.remove_user_warning!(@mod)
          @forum_post.user_warned!("ban", @mod)
          @forum_post.remove_user_warning!(@mod)

          original, warn, unmark1, record, unmark2, ban, unmark3 = EditHistory.where(versionable_id: @forum_post.id).order(version: :asc)
          verify_history(original, @forum_post, "original")
          verify_history(warn, @forum_post, "mark_warning", @mod.id)
          verify_history(unmark1, @forum_post, "unmark", @mod.id)
          verify_history(record, @forum_post, "mark_record", @mod.id)
          verify_history(unmark2, @forum_post, "unmark", @mod.id)
          verify_history(ban, @forum_post, "mark_ban", @mod.id)
          verify_history(unmark3, @forum_post, "unmark", @mod.id)
        end
      end
    end
  end
end

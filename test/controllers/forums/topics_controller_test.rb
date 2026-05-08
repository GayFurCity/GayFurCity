# frozen_string_literal: true

require("test_helper")

module Forums
  class TopicsControllerTest < ActionDispatch::IntegrationTest
    context("The forum topics controller") do
      setup do
        @user = create(:user)
        @other_user = create(:user)
        @mod = create(:moderator_user)
        @admin = create(:admin_user)

        @forum_topic = create(:forum_topic, title: "my forum topic", original_post_attributes: { body: "xxx" }, creator: @user)
      end

      context("show action") do
        should("render") do
          get(forum_topic_path(@forum_topic))

          assert_response(:success)
        end

        should("record a category visit for html requests") do
          get_auth(forum_topic_path(@forum_topic), @user)

          assert(@forum_topic.read_by?(@user))
          assert_predicate(@user.forum_category_visits, :any?)
        end

        should("not record a category visit for non-html requests") do
          get_auth(forum_topic_path(@forum_topic), @user, params: { format: :json })

          assert_not(@forum_topic.read_by?(@user))
          assert_empty(@user.forum_category_visits)
        end

        should("have the correct page number") do
          Config.any_instance.stubs(:records_per_page).returns(2)

          assert_equal(1, @forum_topic.last_page)
          @forum_posts = create_list(:forum_post, 3, topic: @forum_topic, creator: @user)

          assert_equal(2, @forum_topic.last_page)

          get_auth(forum_topic_path(@forum_topic), @user, params: { page: 2 })

          assert_select("#forum_post_#{@forum_posts.second.id}")
          assert_select("#forum_post_#{@forum_posts.third.id}")
          assert_equal([1, 2, 2], @forum_posts.map(&:forum_topic_page))
          assert_equal(2, @forum_topic.last_page)

          @forum_posts.first.hide!(@mod)
          get_auth(forum_topic_path(@forum_topic), @user, params: { page: 2 })

          assert_select("#forum_post_#{@forum_posts.second.id}")
          assert_select("#forum_post_#{@forum_posts.third.id}")
          assert_equal([1, 2, 2], @forum_posts.map(&:forum_topic_page))
          assert_equal(2, @forum_topic.last_page)
        end

        should("restrict access") do
          assert_access(User::Levels::ANONYMOUS) { |user| get_auth(forum_topic_path(@forum_topic), user) }
        end
      end

      context("index action") do
        setup do
          @topic1 = create(:forum_topic, title: "a", is_sticky: true, original_post_attributes: { body: "xxx" }, creator: @user)
          @topic2 = create(:forum_topic, title: "b", original_post_attributes: { body: "xxx" }, creator: @user)
        end

        should("list all forum topics") do
          get(forum_topics_path)

          assert_response(:success)
        end

        should("not list stickied topics first for JSON responses") do
          get(forum_topics_path, params: { format: :json })
          forum_topics = response.parsed_body

          assert_equal([@topic2.id, @topic1.id, @forum_topic.id], forum_topics.pluck("id"))
        end

        context("with search conditions") do
          should("list all matching forum topics") do
            get(forum_topics_path, params: { search: { title_matches: "forum" } })

            assert_response(:success)
            assert_select("a.forum-post-link", @forum_topic.title)
            assert_select("a.forum-post-link", { count: 0, text: @topic1.title })
            assert_select("a.forum-post-link", { count: 0, text: @topic2.title })
          end

          should("list nothing for when the search matches nothing") do
            get(forum_topics_path, params: { search: { title_matches: "bababa" } })

            assert_response(:success)
            assert_select("a.forum-post-link", { count: 0, text: @forum_topic.title })
            assert_select("a.forum-post-link", { count: 0, text: @topic1.title })
            assert_select("a.forum-post-link", { count: 0, text: @topic2.title })
          end
        end

        context("search parameters") do
          subject { forum_topics_path }
          setup do
            ForumPost.delete_all
            ForumTopic.delete_all
            @creator = create(:user)
            @updater = create(:user)
            @admin = create(:admin_user)
            @forum_topic = create(:forum_topic, title: "foo", creator: @creator, creator_ip_addr: "127.0.0.2", updater: @updater, updater_ip_addr: "127.0.0.3", is_sticky: true, is_locked: false, is_hidden: false)
            @forum_topic.reload
          end

          assert_search_param(:title_matches, "foo", -> { [@forum_topic] })
          assert_search_param(:title, "foo", -> { [@forum_topic] })
          assert_search_param(:category_id, -> { @forum_topic.category_id }, -> { [@forum_topic] })
          assert_search_param(:is_sticky, "true", -> { [@forum_topic] })
          assert_search_param(:is_locked, "false", -> { [@forum_topic] })
          assert_search_param(:is_hidden, "false", -> { [@forum_topic] })
          assert_search_param(:creator_id, -> { @creator.id }, -> { [@forum_topic] })
          assert_search_param(:creator_name, -> { @creator.name }, -> { [@forum_topic] })
          assert_search_param(:creator_ip_addr, "127.0.0.2", -> { [@forum_topic] }, -> { @admin })
          assert_search_param(:updater_id, -> { @updater.id }, -> { [@forum_topic] })
          assert_search_param(:updater_name, -> { @updater.name }, -> { [@forum_topic] })
          assert_search_param(:updater_ip_addr, "127.0.0.3", -> { [@forum_topic] }, -> { @admin })
          assert_shared_search_params(-> { [@forum_topic] })
        end
      end

      context("edit action") do
        should("render if the editor is the creator of the topic") do
          get_auth(edit_forum_topic_path(@forum_topic), @user)

          assert_response(:success)
        end

        should("render if the editor is an admin") do
          get_auth(edit_forum_topic_path(@forum_topic), @admin)

          assert_response(:success)
        end

        should("fail if the editor is not the creator of the topic and is not an admin") do
          get_auth(edit_forum_topic_path(@forum_topic), @other_user)

          assert_response(:forbidden)
        end
      end

      context("update action") do
        should("should allow enabling allow_voting") do
          assert_difference("EditHistory.count", 2) do
            put_auth(forum_topic_path(@forum_topic), @user, params: { format: :json, forum_topic: { original_post_attributes: { id: @forum_topic.original_post.id, allow_voting: true } } })

            assert_response(:success)
          end
          assert_equal("enabled_voting", EditHistory.last.edit_type)
          assert_predicate(@forum_topic.original_post.reload, :has_voting?)
        end

        should("not allow users to disable allow_voting") do
          @forum_topic.original_post.update_columns(allow_voting: true)
          assert_no_difference("EditHistory.count") do
            put_auth(forum_topic_path(@forum_topic), @user, params: { format: :json, forum_topic: { original_post_attributes: { id: @forum_topic.original_post.id, allow_voting: false } } })

            assert_response(:bad_request)
          end
          assert_predicate(@forum_topic.original_post.reload, :has_voting?)
          assert_equal("found unpermitted parameter: :allow_voting", @response.parsed_body["message"])
        end

        should("allow admins to disable allow_voting") do
          @forum_topic.original_post.update_columns(allow_voting: true)
          assert_difference("EditHistory.count", 2) do
            put_auth(forum_topic_path(@forum_topic), @admin, params: { format: :json, forum_topic: { original_post_attributes: { id: @forum_topic.original_post.id, allow_voting: false } } })

            assert_response(:success)
          end
          assert_equal("disabled_voting", EditHistory.last.edit_type)
          assert_not(@forum_topic.original_post.reload.has_voting?)
        end

        should("not allow admins to disable allow_voting on TCRs") do
          @ta = create(:tag_alias, forum_post: @forum_post, creator: @user)
          @forum_topic.original_post.update_with(@user, tag_change_request: @ta, allow_voting: true)
          assert_no_difference("EditHistory.count") do
            put_auth(forum_topic_path(@forum_topic), @admin, params: { format: :json, forum_topic: { original_post_attributes: { id: @forum_topic.original_post.id, allow_voting: false } } })

            assert_response(:bad_request)
          end
          assert_predicate(@forum_topic.original_post.reload, :has_voting?)
          assert_equal("found unpermitted parameter: :allow_voting", @response.parsed_body["message"])
        end
      end

      context("new action") do
        should("render") do
          get_auth(new_forum_topic_path, @user)

          assert_response(:success)
        end
      end

      context("create action") do
        should("create a new forum topic and post") do
          assert_difference({ "ForumPost.count" => 1, "ForumTopic.count" => 1, "ModAction.count" => 0 }) do
            post_auth(forum_topics_path, @user, params: { forum_topic: { title: "bababa", category_id: Config.instance.alias_and_implication_forum_category, original_post_attributes: { body: "xaxaxa" } } })
          end

          forum_topic = ForumTopic.last

          assert_redirected_to(forum_topic_path(forum_topic))
        end

        should("fail with expected error if invalid category_id is provided") do
          post_auth(forum_topics_path, @user, params: { forum_topic: { title: "bababa", category_id: 0, original_post_attributes: { body: "xaxaxa" } }, format: :json })

          assert_response(:forbidden)
        end

        should("cause the unread indicator to show") do
          @other_user.forum_category_visits.find_or_create_by!(forum_category_id: Config.instance.alias_and_implication_forum_category).update!(last_read_at: Time.now)
          get_auth(posts_path, @other_user)

          assert_select("#nav-forum.forum-updated", false)

          post_auth(forum_topics_path, @user, params: { forum_topic: { title: "bababa", category_id: Config.instance.alias_and_implication_forum_category, original_post_attributes: { body: "xaxaxa" } } })

          get_auth(posts_path, @other_user)

          assert_select("#nav-forum.forum-updated")
        end

        should("allow setting allow_voting=true") do
          assert_difference({ "ForumPost.count" => 1, "ForumTopic.count" => 1, "EditHistory.count" => 2 }) do
            post_auth(forum_topics_path, @user, params: { forum_topic: { title: "bababa", category_id: Config.instance.alias_and_implication_forum_category, original_post_attributes: { body: "xaxaxa", allow_voting: true } } })
            @forum_topic = ForumTopic.last

            assert_redirected_to(forum_topic_path(@forum_topic))
          end

          assert_equal("enabled_voting", EditHistory.last.edit_type)
          assert_predicate(@forum_topic.original_post, :allow_voting?)
          assert_redirected_to(forum_topic_path(@forum_topic))
        end
      end

      context("destroy action") do
        setup do
          @post = create(:forum_post, topic_id: @forum_topic.id, creator: @user)
        end

        should("destroy the topic and any associated posts") do
          delete_auth(forum_topic_path(@forum_topic), @admin)

          assert_redirected_to(forum_topics_path)
        end

        context("on a forum topic with an AIBUR") do
          should("work (alias)") do
            @ta = create(:tag_alias, forum_topic: @forum_topic, creator: @user)

            assert_equal(@forum_topic.id, @ta.reload.forum_topic_id)
            assert_difference({ "ForumTopic.count" => -1, "TagAlias.count" => 0 }) do
              delete_auth(forum_topic_path(@forum_topic), create(:admin_user))
            end
            assert_nil(@ta.reload.forum_topic_id)
          end

          should("work (implication)") do
            @ti = create(:tag_implication, forum_topic: @forum_topic, creator: @user)

            assert_equal(@forum_topic.id, @ti.reload.forum_topic_id)
            assert_difference({ "ForumTopic.count" => -1, "TagImplication.count" => 0 }) do
              delete_auth(forum_topic_path(@forum_topic), create(:admin_user))
            end
            assert_nil(@ti.reload.forum_topic_id)
          end

          should("work (bulk update request)") do
            @bur = create(:bulk_update_request, forum_topic: @forum_topic, creator: @user)

            assert_equal(@forum_topic.id, @bur.reload.forum_topic_id)
            assert_difference({ "ForumTopic.count" => -1, "BulkUpdateRequest.count" => 0 }) do
              delete_auth(forum_topic_path(@forum_topic), create(:admin_user))
            end
            assert_nil(@bur.reload.forum_topic_id)
          end
        end
      end

      context("hide action") do
        should("hide the topic") do
          put_auth(hide_forum_topic_path(@forum_topic), @mod)

          assert_redirected_to(forum_topic_path(@forum_topic))
          @forum_topic.reload

          assert_predicate(@forum_topic, :is_hidden?)
        end

        should("create edit history") do
          assert_difference("EditHistory.count", 2) do
            put_auth(hide_forum_topic_path(@forum_topic), @mod)
          end
          assert_equal("hide", EditHistory.last.edit_type)
        end

        should("restrict access") do
          assert_access(User::Levels::MODERATOR, success_response: :redirect) { |user| put_auth(hide_forum_topic_path(@forum_topic), user) }
        end
      end

      context("unhide action") do
        setup do
          @forum_topic.update_column(:is_hidden, true)
        end

        should("unhide the topic") do
          put_auth(unhide_forum_topic_path(@forum_topic), @mod)

          assert_redirected_to(forum_topic_path(@forum_topic))
          @forum_topic.reload

          assert_not(@forum_topic.is_hidden?)
        end

        should("restrict access") do
          assert_access(User::Levels::MODERATOR, success_response: :redirect) { |user| put_auth(unhide_forum_topic_path(@forum_topic), user) }
        end
      end

      context("lock action") do
        should("lock the topic") do
          put_auth(lock_forum_topic_path(@forum_topic), @mod, params: { format: :json })

          assert_response(:success)
          @forum_topic.reload

          assert_predicate(@forum_topic, :is_locked?)
        end

        should("restrict access") do
          assert_access(User::Levels::MODERATOR, success_response: :redirect) { |user| put_auth(lock_forum_topic_path(@forum_topic), user) }
        end
      end

      context("unlock action") do
        setup do
          @forum_topic.update_column(:is_locked, true)
        end

        should("unlock the topic") do
          put_auth(unlock_forum_topic_path(@forum_topic), @mod)

          assert_redirected_to(forum_topic_path(@forum_topic))
          @forum_topic.reload

          assert_not(@forum_topic.is_locked?)
        end

        should("restrict access") do
          assert_access(User::Levels::MODERATOR, success_response: :redirect) { |user| put_auth(unlock_forum_topic_path(@forum_topic), user) }
        end
      end

      context("sticky action") do
        should("sticky the topic") do
          put_auth(sticky_forum_topic_path(@forum_topic), @mod)

          assert_redirected_to(forum_topic_path(@forum_topic))
          @forum_topic.reload

          assert_predicate(@forum_topic, :is_sticky?)
        end

        should("restrict access") do
          assert_access(User::Levels::MODERATOR, success_response: :redirect) { |user| put_auth(sticky_forum_topic_path(@forum_topic), user) }
        end
      end

      context("unsticky action") do
        setup do
          @forum_topic.update_column(:is_sticky, true)
        end

        should("unsticky the topic") do
          put_auth(unsticky_forum_topic_path(@forum_topic), @mod)

          assert_redirected_to(forum_topic_path(@forum_topic))
          @forum_topic.reload

          assert_not(@forum_topic.is_sticky?)
        end

        should("restrict access") do
          assert_access(User::Levels::MODERATOR, success_response: :redirect) { |user| put_auth(unsticky_forum_topic_path(@forum_topic), user) }
        end
      end

      context("subscribe action") do
        setup do
          @status = create(:forum_topic_status, forum_topic: @forum_topic, user: @user, mute: true)
        end

        should("ensure mute=false") do
          assert_no_difference("ForumTopicStatus.count") do
            put_auth(subscribe_forum_topic_path(@forum_topic), @user)
          end
          @status.reload

          assert_not(@status.mute)
          assert(@status.subscription)
        end

        should("not create a new status entry if one already exists") do
          assert_no_difference("ForumTopicStatus.count") do
            put_auth(subscribe_forum_topic_path(@forum_topic), @user)
          end
        end
      end

      context("mute action") do
        setup do
          @status = create(:forum_topic_status, forum_topic: @forum_topic, user: @user, subscription: true)
        end

        should("ensure subscription=false") do
          assert_no_difference("ForumTopicStatus.count") do
            put_auth(mute_forum_topic_path(@forum_topic), @user, params: { _method: "PUT" })
          end
          @status.reload

          assert_not(@status.subscription)
          assert(@status.mute)
        end

        should("not create a new status entry if one already exists") do
          assert_no_difference("ForumTopicStatus.count") do
            put_auth(mute_forum_topic_path(@forum_topic), @user, params: { _method: "PUT" })
          end
        end
      end

      context("mark_as_read action") do
        should("work") do
          assert_difference("ForumCategoryVisit.count", 1) do
            put_auth(mark_as_read_forum_topic_path(@forum_topic), @user)

            assert_redirected_to(forum_topic_path(@forum_topic))
          end
          assert(@user.forum_category_visits.exists?(forum_category: @forum_topic.category))
        end

        should("restrict access") do
          assert_access(User::Levels::REJECTED, success_response: :redirect) { |user| put_auth(mark_as_read_forum_topic_path(@forum_topic), user) }
        end
      end
    end
  end
end

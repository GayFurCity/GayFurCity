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

        context("access control") do
          asserts do
            access.gte(User::Levels::ANONYMOUS).get { forum_topic_path(@forum_topic) }
            access.gte(User::Levels::ANONYMOUS).json.get { forum_topic_path(@forum_topic) }
          end
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

          asserts do
            search(:title_matches, "foo").records { [@forum_topic] }
            search(:title, "foo").records { [@forum_topic] }
            search(:category_id).value { @forum_topic.category_id }.records { [@forum_topic] }
            search(:is_sticky, "true").records { [@forum_topic] }
            search(:is_locked, "false").records { [@forum_topic] }
            search(:is_hidden, "false").records { [@forum_topic] }
            search(:creator_id).value { @creator.id }.records { [@forum_topic] }
            search(:creator_name).value { @creator.name }.records { [@forum_topic] }
            search(:creator_ip_addr, "127.0.0.2").records { [@forum_topic] }.user { @admin }
            search(:updater_id).value { @updater.id }.records { [@forum_topic] }
            search(:updater_name).value { @updater.name }.records { [@forum_topic] }
            search(:updater_ip_addr, "127.0.0.3").records { [@forum_topic] }.user { @admin }
            search.shared.records { [@forum_topic] }
          end
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

        context("access control") do
          context("for creator") do
            setup { @category = create(:forum_category, can_view: User::Levels::ANONYMOUS, can_create: User::Levels::MEMBER) }

            asserts do
              access do |builder|
                builder.gte(User::Levels::MEMBER).get do |user|
                  topic = create(:forum_topic, category: @category)
                  topic.update_columns(creator_id: user.id)
                  topic.original_post.update_columns(creator_id: user.id)
                  edit_forum_topic_path(topic)
                end
              end
            end
          end

          context("for non-creator") do
            asserts do
              access.gte(User::Levels::ADMIN).get { edit_forum_topic_path(@forum_topic) }
            end
          end
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

        context("access control") do
          context("for creator") do
            setup { @category = create(:forum_category, can_view: User::Levels::ANONYMOUS, can_create: User::Levels::MEMBER) }

            asserts do
              access do |builder|
                builder.gte(User::Levels::MEMBER).params({ forum_topic: { title: "xaxaxa" } }).success(:redirect).put do |user|
                  topic = create(:forum_topic, category: @category)
                  topic.update_columns(creator_id: user.id)
                  topic.original_post.update_columns(creator_id: user.id)
                  forum_topic_path(topic)
                end
              end
              access do |builder|
                builder.gte(User::Levels::MEMBER).json.params({ forum_topic: { title: "xaxaxa" } }).put do |user|
                  topic = create(:forum_topic, category: @category)
                  topic.update_columns(creator_id: user.id)
                  topic.original_post.update_columns(creator_id: user.id)
                  forum_topic_path(topic)
                end
              end
            end
          end

          context("for non-creator") do
            asserts do
              access.gte(User::Levels::ADMIN).put { forum_topic_path(@forum_topic) }.params({ forum_topic: { title: "xaxaxa" } }).success(:redirect)
              access.gte(User::Levels::ADMIN).json.put { forum_topic_path(@forum_topic) }.params({ forum_topic: { title: "xaxaxa" } })
            end
          end
        end
      end

      context("new action") do
        should("render") do
          get_auth(new_forum_topic_path, @user)

          assert_response(:success)
        end

        context("access control") do
          asserts do
            access.gte(User::Levels::MEMBER).get(new_forum_topic_path)
          end
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

        context("access control") do
          context("in unrestricted category") do
            setup { @category = create(:forum_category, can_view: User::Levels::ANONYMOUS, can_create: User::Levels::MEMBER) }

            asserts do
              access.gte(User::Levels::MEMBER).post(forum_topics_path).params { { forum_topic: { title: "bababa", category_id: @category.id, original_post_attributes: { body: "xaxaxa" } } } }.success(:redirect)
              access.gte(User::Levels::MEMBER).json.post(forum_topics_path).params { { forum_topic: { title: "bababa", category_id: @category.id, original_post_attributes: { body: "xaxaxa" } } } }
            end
          end

          context("in restricted category") do
            setup { @category = create(:forum_category, can_view: User::Levels::ANONYMOUS, can_create: User::Levels::ADMIN) }

            asserts do
              access.gte(User::Levels::ADMIN).post(forum_topics_path).params { { forum_topic: { title: "bababa", category_id: @category.id, original_post_attributes: { body: "xaxaxa" } } } }.success(:redirect)
              access.gte(User::Levels::ADMIN).json.post(forum_topics_path).params { { forum_topic: { title: "bababa", category_id: @category.id, original_post_attributes: { body: "xaxaxa" } } } }
            end
          end
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

        context("access control") do
          asserts do
            access.gte(User::Levels::ADMIN).delete { forum_topic_path(@forum_topic) }.success(:redirect)
            access.gte(User::Levels::ADMIN).json.delete { forum_topic_path(@forum_topic) }.success(:no_content)
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

        context("access control") do
          context("for creator") do
            setup { @category = create(:forum_category, can_view: User::Levels::ANONYMOUS, can_create: User::Levels::MEMBER) }

            asserts do
              access do |builder|
                builder.gte(User::Levels::MEMBER).success(:redirect).put do |user|
                  topic = create(:forum_topic, category: @category)
                  topic.update_columns(creator_id: user.id)
                  topic.original_post.update_columns(creator_id: user.id)
                  hide_forum_topic_path(topic)
                end
              end
              access do |builder|
                builder.gte(User::Levels::MEMBER).json.success(:no_content).put do |user|
                  topic = create(:forum_topic, category: @category)
                  topic.update_columns(creator_id: user.id)
                  topic.original_post.update_columns(creator_id: user.id)
                  hide_forum_topic_path(topic)
                end
              end
            end
          end

          context("for non-creator") do
            asserts do
              access.gte(User::Levels::MODERATOR).put { hide_forum_topic_path(@forum_topic) }.success(:redirect)
              access.gte(User::Levels::MODERATOR).json.put { hide_forum_topic_path(@forum_topic) }.success(:no_content)
            end
          end
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

        context("access control") do
          asserts do
            access.gte(User::Levels::MODERATOR).put { unhide_forum_topic_path(@forum_topic) }.success(:redirect)
            access.gte(User::Levels::MODERATOR).json.put { unhide_forum_topic_path(@forum_topic) }.success(:no_content)
          end
        end
      end

      context("lock action") do
        should("lock the topic") do
          put_auth(lock_forum_topic_path(@forum_topic), @mod, params: { format: :json })

          assert_response(:success)
          @forum_topic.reload

          assert_predicate(@forum_topic, :is_locked?)
        end

        context("access control") do
          asserts do
            access.gte(User::Levels::MODERATOR).put { lock_forum_topic_path(@forum_topic) }.success(:redirect)
            access.gte(User::Levels::MODERATOR).json.put { lock_forum_topic_path(@forum_topic) }.success(:no_content)
          end
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

        context("access control") do
          asserts do
            access.gte(User::Levels::MODERATOR).put { unlock_forum_topic_path(@forum_topic) }.success(:redirect)
            access.gte(User::Levels::MODERATOR).json.put { unlock_forum_topic_path(@forum_topic) }.success(:no_content)
          end
        end
      end

      context("sticky action") do
        should("sticky the topic") do
          put_auth(sticky_forum_topic_path(@forum_topic), @mod)

          assert_redirected_to(forum_topic_path(@forum_topic))
          @forum_topic.reload

          assert_predicate(@forum_topic, :is_sticky?)
        end

        context("access control") do
          asserts do
            access.gte(User::Levels::MODERATOR).put { sticky_forum_topic_path(@forum_topic) }.success(:redirect)
            access.gte(User::Levels::MODERATOR).json.put { sticky_forum_topic_path(@forum_topic) }.success(:no_content)
          end
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

        context("access control") do
          asserts do
            access.gte(User::Levels::MODERATOR).put { unsticky_forum_topic_path(@forum_topic) }.success(:redirect)
            access.gte(User::Levels::MODERATOR).json.put { unsticky_forum_topic_path(@forum_topic) }.success(:no_content)
          end
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

        context("access control") do
          asserts do
            access.gte(User::Levels::REJECTED).put { subscribe_forum_topic_path(@forum_topic) }.success(:redirect)
            access.gte(User::Levels::REJECTED).json.put { subscribe_forum_topic_path(@forum_topic) }.success(:no_content)
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

        context("access control") do
          asserts do
            access.gte(User::Levels::REJECTED).put { mute_forum_topic_path(@forum_topic) }.success(:redirect)
            access.gte(User::Levels::REJECTED).json.put { mute_forum_topic_path(@forum_topic) }.success(:no_content)
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

        context("access control") do
          asserts do
            access.gte(User::Levels::REJECTED).put { mark_as_read_forum_topic_path(@forum_topic) }.success(:redirect)
            access.gte(User::Levels::REJECTED).json.put { mark_as_read_forum_topic_path(@forum_topic) }.success(:no_content)
          end
        end
      end
    end
  end
end

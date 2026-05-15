# frozen_string_literal: true

require("test_helper")

module Forums
  class PostsControllerTest < ActionDispatch::IntegrationTest
    context("The forum posts controller") do
      setup do
        @user = create(:user)
        @other_user = create(:user)
        @mod = create(:moderator_user)
        @admin = create(:admin_user)
        @forum_topic = create(:forum_topic, title: "my forum topic", original_post_attributes: { body: "alias xxx -> yyy" }, creator: @user)
        @forum_post = @forum_topic.original_post
      end

      context("with votes") do
        setup do
          @tag_alias = create(:tag_alias, forum_post: @forum_post, status: "pending", creator: @user)
          @forum_post.update_with(@user, tag_change_request: @tag_alias, allow_voting: true)
          @vote = create(:forum_post_vote, forum_post: @forum_post, score: 1, user: @user)
          @forum_post.reload
        end

        should("not render the vote links for the requesting user") do
          get_auth(forum_topic_path(@forum_topic), @user)

          assert_response(:success)
          assert_select("a[title='Vote up']", false)
        end

        should("render the vote links") do
          get_auth(forum_topic_path(@forum_topic), @mod)

          assert_response(:success)
          assert_select("a[title='Vote up']")
        end

        should("render existing votes") do
          get_auth(forum_topic_path(@forum_topic), @mod)

          assert_response(:success)
          assert_select("li.vote-score-up")
        end

        context("after the alias is rejected") do
          setup do
            @tag_alias.reject!(@mod)
            get_auth(forum_topic_path(@forum_topic), @mod)
          end

          should("hide the vote links") do
            assert_select("a[title='Vote up']", false)
          end

          should("still render existing votes") do
            assert_select("li.vote-score-up")
          end
        end
      end

      context("index action") do
        should("list all forum posts") do
          get(forum_posts_path)

          assert_response(:success)
        end

        context("with posts in a hidden category") do
          setup do
            @category2 = create(:forum_category, can_view: @mod.level)
            @forum_topic = create(:forum_topic, category: @category2, title: "test", original_post_attributes: { body: "test" }, creator: @mod)
            @forum_post2 = @forum_topic.original_post
          end

          should("only list visible posts") do
            get(forum_posts_path)

            assert_response(:success)
            assert_select("#forum-post-#{@forum_post.id}", true)
            assert_select("#forum-post-#{@forum_post2.id}", false)

            get(forum_posts_path(format: :json))

            assert_response(:success)
            assert_equal([@forum_post.id], @response.parsed_body.pluck("id"))
          end
        end

        context("with search conditions") do
          should("list all matching forum posts") do
            get(forum_posts_path, params: { search: { body_matches: "xxx" } })

            assert_response(:success)
            assert_select("#forum-post-#{@forum_post.id}")
          end

          should("list nothing for when the search matches nothing") do
            get(forum_posts_path, params: { search: { body_matches: "bababa" } })

            assert_response(:success)
            assert_select("#forum-post-#{@forum_post.id}", false)
          end

          should("list by creator id") do
            get(forum_posts_path, params: { search: { creator_id: @user.id } })

            assert_response(:success)
            assert_select("#forum-post-#{@forum_post.id}")
          end
        end

        context("access control") do
          asserts do
            access.gte(User::Levels::ANONYMOUS).get(forum_posts_path)
            access.gte(User::Levels::ANONYMOUS).json.get(forum_posts_path)
          end
        end

        context("search parameters") do
          subject { forum_posts_path }
          setup do
            ForumPost.delete_all
            @creator = create(:user)
            @updater = create(:user)
            @admin = create(:admin_user)
            @forum_topic = create(:forum_topic, original_post_attributes: { body: "foo [[bar]]", is_hidden: false, updater: @updater, updater_ip_addr: "127.0.0.3" }, title: "baz", creator: @creator, creator_ip_addr: "127.0.0.2")
            @forum_post = @forum_topic.original_post
          end

          asserts do
            search(:topic_id).value { @forum_topic.id }.records { [@forum_post] }
            search(:body_matches, "foo").records { [@forum_post] }
            search(:is_hidden, "false").records { [@forum_post] }
            search(:topic_title_matches, "baz").records { [@forum_post] }
            search(:topic_category_id).value { @forum_topic.category_id }.records { [@forum_post] }
            search(:creator_id).value { @creator.id }.records { [@forum_post] }
            search(:creator_name).value { @creator.name }.records { [@forum_post] }
            search(:ip_addr, "127.0.0.2").records { [@forum_post] }.user { @admin }
            search(:updater_id).value { @updater.id }.records { [@forum_post] }
            search(:updater_name).value { @updater.name }.records { [@forum_post] }
            search(:updater_ip_addr, "127.0.0.3").records { [@forum_post] }.user { @admin }
            search(:linked_to, "bar").records { [@forum_post] }
            search(:not_linked_to, "baz").records { [@forum_post] }
            search.shared.records { [@forum_post] }
          end
        end
      end

      context("edit action") do
        should("render if the editor is the creator of the topic") do
          get_auth(edit_forum_post_path(@forum_post), @user)

          assert_response(:success)
        end

        should("render if the editor is an admin") do
          get_auth(edit_forum_post_path(@forum_post), create(:admin_user))

          assert_response(:success)
        end

        should("fail if the editor is not the creator of the topic and is not an admin") do
          get_auth(edit_forum_post_path(@forum_post), @other_user)

          assert_response(:forbidden)
        end

        context("access control") do
          context("for creator") do
            setup { @category = create(:forum_category, can_view: User::Levels::ANONYMOUS, can_create: User::Levels::MEMBER) }

            asserts do
              access do |builder|
                builder.gte(User::Levels::MEMBER).get do |user|
                  post = create(:forum_topic, category: @category).original_post
                  post.update_columns(creator_id: user.id)
                  edit_forum_post_path(post)
                end
              end
            end
          end

          context("for non-creator") do
            asserts do
              access.gte(User::Levels::ADMIN).get { edit_forum_post_path(@forum_post) }
            end
          end
        end
      end

      context("update action") do
        should("should allow enabling allow_voting") do
          assert_difference("EditHistory.count", 2) do
            put_auth(forum_post_path(@forum_post), @user, params: { format: :json, forum_post: { allow_voting: true } })

            assert_response(:success)
          end
          assert_equal("enabled_voting", EditHistory.last.edit_type)
          assert_predicate(@forum_post.reload, :has_voting?)
        end

        should("not allow users to disable allow_voting") do
          @forum_post.update_columns(allow_voting: true)
          assert_no_difference("EditHistory.count") do
            put_auth(forum_post_path(@forum_post), @user, params: { format: :json, forum_post: { allow_voting: false } })

            assert_response(:bad_request)
          end
          assert_predicate(@forum_post.reload, :has_voting?)
          assert_equal("found unpermitted parameter: :allow_voting", @response.parsed_body["message"])
        end

        should("allow admins to disable allow_voting") do
          @forum_post.update_columns(allow_voting: true)
          assert_difference("EditHistory.count", 2) do
            put_auth(forum_post_path(@forum_post), @admin, params: { format: :json, forum_post: { allow_voting: false } })

            assert_response(:success)
          end
          assert_equal("disabled_voting", EditHistory.last.edit_type)
          assert_not(@forum_post.reload.has_voting?)
        end

        should("not allow admins to disable allow_voting on TCRs") do
          @ta = create(:tag_alias, forum_post: @forum_post)
          @forum_post.update_with(@user, tag_change_request: @ta, allow_voting: true)
          assert_no_difference("EditHistory.count") do
            put_auth(forum_post_path(@forum_post), @admin, params: { format: :json, forum_post: { allow_voting: false } })

            assert_response(:bad_request)
          end
          assert_predicate(@forum_post.reload, :has_voting?)
          assert_equal("found unpermitted parameter: :allow_voting", @response.parsed_body["message"])
        end

        context("access control") do
          context("for creator") do
            setup { @category = create(:forum_category, can_view: User::Levels::ANONYMOUS, can_create: User::Levels::MEMBER) }

            asserts do
              access do |builder|
                builder.gte(User::Levels::MEMBER).params({ forum_post: { body: "xaxaxa" } }).success(:redirect).put do |user|
                  post = create(:forum_topic, category: @category).original_post
                  post.update_columns(creator_id: user.id)
                  forum_post_path(post)
                end
              end
              access do |builder|
                builder.gte(User::Levels::MEMBER).json.params({ forum_post: { body: "xaxaxa" } }).put do |user|
                  post = create(:forum_topic, category: @category).original_post
                  post.update_columns(creator_id: user.id)
                  forum_post_path(post)
                end
              end
            end
          end

          context("for non-creator") do
            asserts do
              access.gte(User::Levels::ADMIN).put { forum_post_path(@forum_post) }.params({ forum_post: { body: "xaxaxa" } }).success(:redirect)
              access.gte(User::Levels::ADMIN).json.put { forum_post_path(@forum_post) }.params({ forum_post: { body: "xaxaxa" } })
            end
          end
        end
      end

      context("new action") do
        should("render") do
          get_auth(new_forum_post_path, @user, params: { forum_post: { topic_id: @forum_topic.id } })

          assert_response(:success)
        end

        context("access control") do
          asserts do
            access.gte(User::Levels::REJECTED).get(new_forum_post_path)
          end
        end
      end

      context("create action") do
        should("create a new forum post") do
          assert_difference("ForumPost.count", 1) do
            post_auth(forum_posts_path, @user, params: { forum_post: { body: "xaxaxa", topic_id: @forum_topic.id } })

            assert_redirected_to(forum_topic_path(ForumPost.last.topic, page: ForumPost.last.forum_topic_page, anchor: "forum_post_#{ForumPost.last.id}"))
          end
        end

        should("work with allow_voting=true") do
          assert_difference({ "ForumPost.count" => 1, "EditHistory.count" => 2 }) do
            post_auth(forum_posts_path, @user, params: { forum_post: { body: "xaxaxa", topic_id: @forum_topic.id, allow_voting: true } })

            assert_redirected_to(forum_topic_path(ForumPost.last.topic, page: ForumPost.last.forum_topic_page, anchor: "forum_post_#{ForumPost.last.id}"))
          end
          assert_equal("enabled_voting", EditHistory.last.edit_type)
          assert_predicate(ForumPost.last, :has_voting?)
        end

        should("not create a new forum post if topic is stale") do
          create(:forum_post, topic: @forum_topic, creator: @mod) # if the topic doesn't have any posts it will never be stale
          Config.any_instance.stubs(:enable_stale_forum_topics).returns(true)
          Config.any_instance.stubs(:forum_topic_stale_window).returns(60)

          travel_to(1.year.from_now) do
            assert_no_difference("ForumPost.count") do
              post_auth(forum_posts_path, @user, params: { forum_post: { body: "xaxaxa", topic_id: @forum_topic.id }, format: :json })

              assert_response(:unprocessable_entity)
              assert_includes(@response.parsed_body.dig("errors", "topic"), "is stale. New posts cannot be created")
            end
          end
        end

        should("work even if the topic is stale if it has no posts") do
          Config.any_instance.stubs(:enable_stale_forum_topics).returns(true)
          Config.any_instance.stubs(:forum_topic_stale_window).returns(60)

          travel_to(1.year.from_now) do
            assert_difference("ForumPost.count", 1) do
              post_auth(forum_posts_path, @user, params: { forum_post: { body: "xaxaxa", topic_id: @forum_topic.id } })

              assert_redirected_to(forum_topic_path(ForumPost.last.topic, page: ForumPost.last.forum_topic_page, anchor: "forum_post_#{ForumPost.last.id}"))
            end
          end
        end

        should("still create a new forum post if topic is stale for moderators") do
          create(:forum_post, topic: @forum_topic, creator: @mod) # if the topic doesn't have any posts it will never be stale
          Config.any_instance.stubs(:enable_stale_forum_topics).returns(true)
          Config.any_instance.stubs(:forum_topic_stale_window).returns(60)

          travel_to(1.year.from_now) do
            assert_difference("ForumPost.count", 1) do
              post_auth(forum_posts_path, @mod, params: { forum_post: { body: "xaxaxa", topic_id: @forum_topic.id }, format: :json })

              assert_response(:success)
            end
          end
        end

        context("access control") do
          context("in unrestricted category") do
            asserts do
              access.gte(User::Levels::MEMBER).post(forum_posts_path).params { { forum_post: { body: "xaxaxa", topic_id: @forum_topic.id } } }.success(:redirect)
              access.gte(User::Levels::MEMBER).json.post(forum_posts_path).params { { forum_post: { body: "xaxaxa", topic_id: @forum_topic.id } } }
            end
          end

          context("in restricted category") do
            setup { @forum_topic.category.update!(can_create: User::Levels::ADMIN) }

            asserts do
              access.gte(User::Levels::ADMIN).post(forum_posts_path).params { { forum_post: { body: "xaxaxa", topic_id: @forum_topic.id } } }.success(:redirect)
              access.gte(User::Levels::ADMIN).json.post(forum_posts_path).params { { forum_post: { body: "xaxaxa", topic_id: @forum_topic.id } } }
            end
          end
        end
      end

      context("destroy action") do
        should("destroy the posts") do
          delete_auth(forum_post_path(@forum_post), create(:admin_user))
          assert_raises(ActiveRecord::RecordNotFound) { @forum_post.reload }
          assert_redirected_to(forum_posts_path)
        end

        context("on a forum post with edit history") do
          setup do
            @forum_post.update_with!(@user, body: "hi hello")
          end

          should("also delete the edit history") do
            assert_difference({ "ForumPost.count" => -1, "EditHistory.count" => -2 }) do
              delete_auth(forum_post_path(@forum_post), create(:admin_user))
            end
          end
        end

        context("on a forum post with an AIBUR") do
          should("work (alias)") do
            @ta = create(:tag_alias, forum_topic: @forum_post.topic, forum_post: @forum_post)

            assert_equal(@forum_post.id, @ta.reload.forum_post_id)
            assert_difference({ "ForumPost.count" => -1, "TagAlias.count" => 0 }) do
              delete_auth(forum_post_path(@forum_post), create(:admin_user))
            end
            assert_nil(@ta.reload.forum_post_id)
          end

          should("work (implication)") do
            @ti = create(:tag_implication, forum_topic: @forum_post.topic, forum_post: @forum_post)

            assert_equal(@forum_post.id, @ti.reload.forum_post_id)
            assert_difference({ "ForumPost.count" => -1, "TagImplication.count" => 0 }) do
              delete_auth(forum_post_path(@forum_post), create(:admin_user))
            end
            assert_nil(@ti.reload.forum_post_id)
          end

          should("work (bulk update request)") do
            @bur = create(:bulk_update_request, forum_topic: @forum_post.topic, forum_post: @forum_post)
            @forum_post = @bur.forum_post

            assert_equal(@forum_post.id, @bur.reload.forum_post_id)
            assert_difference({ "ForumPost.count" => -1, "BulkUpdateRequest.count" => 0 }) do
              delete_auth(forum_post_path(@forum_post), create(:admin_user))
            end
            assert_nil(@bur.reload.forum_post_id)
          end
        end

        context("access control") do
          asserts do
            access.gte(User::Levels::ADMIN).delete { forum_post_path(@forum_post) }.success(:redirect)
            access.gte(User::Levels::ADMIN).json.delete { forum_post_path(@forum_post) }.success(:no_content)
          end
        end
      end

      context("hide action") do
        should("restore the post") do
          put_auth(hide_forum_post_path(@forum_post), @mod)

          assert_redirected_to(forum_post_path(@forum_post))
          @forum_post.reload

          assert_predicate(@forum_post, :is_hidden?)
        end

        context("access control") do
          context("for creator") do
            setup { @category = create(:forum_category, can_view: User::Levels::ANONYMOUS, can_create: User::Levels::MEMBER) }

            asserts do
              access do |builder|
                builder.gte(User::Levels::MEMBER).success(:redirect).put do |user|
                  post = create(:forum_topic, category: @category).original_post
                  post.update_columns(creator_id: user.id)
                  hide_forum_post_path(post)
                end
              end
              access do |builder|
                builder.gte(User::Levels::MEMBER).json.success(:no_content).put do |user|
                  post = create(:forum_topic, category: @category).original_post
                  post.update_columns(creator_id: user.id)
                  hide_forum_post_path(post)
                end
              end
            end
          end

          context("for non-creator") do
            asserts do
              access.gte(User::Levels::MODERATOR).put { hide_forum_post_path(@forum_post) }.success(:redirect)
              access.gte(User::Levels::MODERATOR).json.put { hide_forum_post_path(@forum_post) }.success(:no_content)
            end
          end
        end
      end

      context("unhide action") do
        setup do
          @forum_post.hide!(@mod)
        end

        should("restore the post") do
          put_auth(unhide_forum_post_path(@forum_post), @mod)

          assert_redirected_to(forum_post_path(@forum_post))
          @forum_post.reload

          assert_not(@forum_post.is_hidden?)
        end

        context("access control") do
          asserts do
            access.gte(User::Levels::MODERATOR).put { unhide_forum_post_path(@forum_post) }.success(:redirect)
            access.gte(User::Levels::MODERATOR).json.put { unhide_forum_post_path(@forum_post) }.success(:no_content)
          end
        end
      end

      context("spam") do
        setup do
          SpamDetector.stubs(:enabled?).returns(true)
          stub_request(:post, %r{https://.*\.rest\.akismet\.com/(\d\.?)+/comment-check}).to_return(status: 200, body: "true")
          stub_request(:post, %r{https://.*\.rest\.akismet\.com/(\d\.?)+/submit-spam}).to_return(status: 200, body: nil)
          stub_request(:post, %r{https://.*\.rest\.akismet\.com/(\d\.?)+/submit-ham}).to_return(status: 200, body: nil)
        end

        should("mark spam forum posts as spam") do
          SpamDetector.any_instance.stubs(:spam?).returns(true)
          assert_difference("User.system.tickets.count", 1) do
            assert_difference("ForumPost.count", 1) do
              post_auth(forum_posts_path, @user, params: { forum_post: { body: "abc", topic_id: @forum_topic.id } })
              @ticket = User.system.tickets.last
              @forum_post = ForumPost.last

              assert_redirected_to(forum_topic_path(@forum_topic, page: @forum_topic.last_page, anchor: "forum_post_#{@forum_post.id}"))
            end
          end
          assert_equal(@forum_post, @ticket.model)
          assert_equal("Spam.", @ticket.reason)
          assert_predicate(@forum_post, :is_spam?)
        end

        should("not mark moderator forum posts as spam") do
          # no need to stub anything, it should return false due to Trusted+ bypassing spam checks
          assert_difference({ "User.system.tickets.count" => 0, "ForumPost.count" => 1 }) do
            post_auth(forum_posts_path, @mod, params: { forum_post: { body: "abc", topic_id: @forum_topic.id } })
            @ticket = User.system.tickets.last
            @forum_post = ForumPost.last

            assert_redirected_to(forum_topic_path(@forum_topic, page: @forum_topic.last_page, anchor: "forum_post_#{@forum_post.id}"))
          end
          @forum_post = ForumPost.last

          assert_not(@forum_post.is_spam?)
        end

        should("auto ban spammers") do
          SpamDetector.any_instance.stubs(:spam?).returns(true)
          create_list(:ticket, SpamDetector::AUTOBAN_THRESHOLD - 1, model: @forum_post, reason: "Spam.", creator: User.system)
          assert_difference(%w[Ban.count User.system.tickets.count ForumPost.count], 1) do
            post_auth(forum_posts_path, @user, params: { forum_post: { body: "abc", topic_id: @forum_topic.id } })
            @ticket = User.system.tickets.last
            @forum_post = ForumPost.last

            assert_redirected_to(forum_topic_path(@forum_topic, page: @forum_topic.last_page, anchor: "forum_post_#{@forum_post.id}"))
          end
          assert_equal(@forum_post, @ticket.model)
          assert_equal("Spam.", @ticket.reason)
          assert_predicate(@forum_post, :is_spam?)
          assert_predicate(@user.reload, :is_banned?)
        end

        context("mark spam action") do
          should("work and report false negative") do
            SpamDetector.any_instance.expects(:spam!).times(1)

            assert_not(@forum_post.reload.is_spam?)
            put_auth(mark_spam_forum_post_path(@forum_post), @mod)

            assert_response(:success)
            assert_predicate(@forum_post.reload, :is_spam?)
          end

          should("work and not report false negative if ticket exists") do
            SpamDetector.any_instance.expects(:spam!).never
            User.system.tickets.create!(model: @forum_post, reason: "Spam.", creator_ip_addr: "127.0.0.1")

            assert_not(@forum_post.reload.is_spam?)
            put_auth(mark_spam_forum_post_path(@forum_post), @mod)

            assert_response(:success)
            assert_predicate(@forum_post.reload, :is_spam?)
          end

          context("access control") do
            setup { SpamDetector.any_instance.stubs(:spam!).returns(true) }

            asserts do
              access.gte(User::Levels::MODERATOR).json.put { mark_spam_forum_post_path(@forum_post) }
            end
          end
        end

        context("mark not spam action") do
          should("work and not report false positive") do
            SpamDetector.any_instance.expects(:ham!).never
            @forum_post.update_column(:is_spam, true)

            assert_predicate(@forum_post.reload, :is_spam?)
            put_auth(mark_not_spam_forum_post_path(@forum_post), @mod)

            assert_response(:success)
            assert_not(@forum_post.reload.is_spam?)
          end

          should("work and report false positive if ticket exists") do
            SpamDetector.any_instance.expects(:ham!).times(1)
            User.system.tickets.create!(model: @forum_post, reason: "Spam.", creator_ip_addr: "127.0.0.1")
            @forum_post.update_column(:is_spam, true)

            assert_predicate(@forum_post.reload, :is_spam?)
            put_auth(mark_not_spam_forum_post_path(@forum_post), @mod)

            assert_response(:success)
            assert_not(@forum_post.reload.is_spam?)
          end

          context("access control") do
            asserts do
              access.gte(User::Levels::MODERATOR).json.put { mark_not_spam_forum_post_path(@forum_post) }
            end
          end
        end
      end

      context("warning action") do
        should("mark warning") do
          put_auth(warning_forum_post_path(@forum_post), @mod, params: { record_type: "warning" })

          assert_response(:success)
          assert_equal("warning", @forum_post.reload.warning_type)
          assert_equal(@mod.id, @forum_post.reload.warning_user_id)
        end

        should("mark record") do
          put_auth(warning_forum_post_path(@forum_post), @mod, params: { record_type: "record" })

          assert_response(:success)
          assert_equal("record", @forum_post.reload.warning_type)
          assert_equal(@mod.id, @forum_post.reload.warning_user_id)
        end

        should("mark ban") do
          put_auth(warning_forum_post_path(@forum_post), @mod, params: { record_type: "ban" })

          assert_response(:success)
          assert_equal("ban", @forum_post.reload.warning_type)
          assert_equal(@mod.id, @forum_post.reload.warning_user_id)
        end

        should("unmark") do
          @forum_post.user_warned!("warning", @mod)
          put_auth(warning_forum_post_path(@forum_post), @mod, params: { record_type: "unmark" })

          assert_response(:success)
          assert_nil(@forum_post.reload.warning_type)
          assert_nil(@forum_post.reload.warning_user_id)
        end

        context("access control") do
          asserts do
            access.gte(User::Levels::MODERATOR).json.put { warning_forum_post_path(@forum_post) }.params { { record_type: "warning" } }
          end
        end
      end
    end
  end
end

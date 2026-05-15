# frozen_string_literal: true

require("test_helper")

class CommentsControllerTest < ActionDispatch::IntegrationTest
  context("The comments controller") do
    setup do
      @mod = create(:moderator_user)
      @user = create(:member_user)

      @post = create(:post)
      @comment = create(:comment, post: @post, creator: @user)
      @mod_comment = create(:comment, post: @post, creator: @mod)
    end

    context("index action") do
      should("render for post") do
        get(comments_path(post_id: @post.id, group_by: "post"))

        assert_response(:success)
      end

      should("render by post") do
        get(comments_path(group_by: "post"))

        assert_response(:success)
      end

      should("render by comment") do
        get(comments_path(group_by: "comment"))

        assert_response(:success)
      end

      should("render for the poster_id search parameter") do
        get(comments_path(group_by: "comment", search: { poster_id: 123 }))

        assert_response(:success)
      end

      context("access control") do
        asserts do
          access.gte(User::Levels::ANONYMOUS).get(comments_path)
          access.gte(User::Levels::ANONYMOUS).json.get(comments_path)
        end
      end

      context("access control (group_by=comment)") do
        asserts do
          access.gte(User::Levels::ANONYMOUS).json.get(comments_path(group_by: "comment"))
        end
      end

      context("access control (group_by=post)") do
        asserts do
          access.gte(User::Levels::ANONYMOUS).json.get(comments_path(group_by: "post"))
        end
      end

      context("search parameters") do
        subject { comments_path }
        setup do
          Comment.delete_all
          @user = create(:user)
          @creator = create(:user)
          @updater = create(:user)
          @uploader = create(:user)
          @admin = create(:admin_user)
          @mod = create(:moderator_user)
          @note_updater = create(:user)
          @post = create(:post, tag_string: "foo", uploader: @uploader)
          create(:note, post: @post, creator: @note_updater)
          @comment = create(:comment, creator: @creator, creator_ip_addr: "127.0.0.2", updater: @updater, updater_ip_addr: "127.0.0.3", post: @post, body: "bar", is_hidden: false, is_sticky: true, is_spam: false)
        end

        asserts do
          search(:body_matches, "bar").records { [@comment] }
          search(:post_id).value { @post.id }.records { [@comment] }
          search(:ip_addr, "127.0.0.2").records { [@comment] }.user { @admin }
          search(:updater_ip_addr, "127.0.0.3").records { [@comment] }.user { @admin }
          search(:is_hidden, "false").records { [@comment] }.user { @mod }
          search(:is_sticky, "true").records { [@comment] }
          search(:is_spam, "false").records { [@comment] }.user { @mod }
          search(:post_tags_match, "foo").records { [@comment] }
          search(:post_note_updater_id).value { @note_updater.id }.records { [@comment] }
          search(:post_note_updater_name).value { @note_updater.name }.records { [@comment] }
          search(:creator_id).value { @creator.id }.records { [@comment] }
          search(:creator_name).value { @creator.name }.records { [@comment] }
          search(:updater_id).value { @updater.id }.records { [@comment] }
          search(:updater_name).value { @updater.name }.records { [@comment] }
          search(:poster_id).value { @uploader.id }.records { [@comment] }
          search(:poster_name).value { @uploader.name }.records { [@comment] }
          search.shared.records { [@comment] }
        end
      end
    end

    context("search action") do
      should("render") do
        get(search_comments_path)

        assert_response(:success)
      end

      context("access control") do
        asserts do
          access.gte(User::Levels::ANONYMOUS).get(search_comments_path)
        end
      end
    end

    context("show action") do
      should("render") do
        get(comment_path(@comment))

        assert_response(:success)
      end

      should("escape dtext html in comment bodies") do
        @comment.update_column(:body, %(<script>alert("xss")</script><img src=x onerror=alert("xss")>))

        get(comment_path(@comment))

        assert_response(:success)
        assert_includes(@response.body, '&lt;script&gt;alert("xss")&lt;/script&gt;')
        assert_includes(@response.body, '&lt;img src=x onerror=alert("xss")&gt;')
        assert_not_includes(@response.body, "<script>alert(\"xss\")</script>")
        assert_not_includes(@response.body, %{<img src=x onerror=alert("xss")>})
      end

      context("access control") do
        asserts do
          access.gte(User::Levels::ANONYMOUS).get { comment_path(@comment) }
          access.gte(User::Levels::ANONYMOUS).json.get { comment_path(@comment) }
        end
      end
    end

    context("edit action") do
      should("render") do
        get_auth(edit_comment_path(@comment), @user)

        assert_response(:success)
      end

      context("access control") do
        asserts do
          access.gte(User::Levels::MEMBER).get { |user| edit_comment_path(create(:comment, creator: user, post: @post)) }
        end
      end

      context("access control (not creator)") do
        asserts do
          access.gte(User::Levels::ADMIN).get { edit_comment_path(@comment) }
        end
      end
    end

    context("update action") do
      context("when updating another user's comment") do
        should("succeed if updater is a moderator") do
          put_auth(comment_path(@comment.id), @user, params: { comment: { body: "abc" } })

          assert_equal("abc", @comment.reload.body)
          assert_redirected_to(post_path(@comment.post))
        end

        should("fail if updater is not a moderator") do
          put_auth(comment_path(@mod_comment.id), @user, params: { comment: { body: "abc" } })

          assert_not_equal("abc", @mod_comment.reload.body)
          assert_response(:forbidden)
        end
      end

      context("when stickying a comment") do
        should("succeed if updater is a moderator") do
          @comment = create(:comment, creator: @mod)
          put_auth(comment_path(@comment.id), @mod, params: { comment: { is_sticky: true } })

          assert(@comment.reload.is_sticky)
          assert_redirected_to(@comment.post)
        end

        should("fail if updater is not a moderator") do
          put_auth(comment_path(@comment.id), @user, params: { comment: { is_sticky: true } })

          assert_not(@comment.reload.is_sticky)
        end
      end

      should("update the body") do
        put_auth(comment_path(@comment.id), @user, params: { comment: { body: "abc" } })

        assert_equal("abc", @comment.reload.body)
        assert_redirected_to(post_path(@comment.post))
      end

      should("not allow changing is_hidden") do
        put_auth(comment_path(@comment.id), @user, params: { comment: { body: "herp derp", is_hidden: true } })

        assert_not(@comment.is_hidden)
      end

      should("not allow changing do_not_bump_post or post_id") do
        @another_post = create(:post)
        put_auth(comment_path(@comment.id), @comment.creator, params: { do_not_bump_post: true, post_id: @another_post.id })

        assert_not(@comment.reload.do_not_bump_post)
        assert_equal(@post.id, @comment.post_id)
      end

      context("access control") do
        asserts do
          access.gte(User::Levels::MEMBER).put { |user| comment_path(create(:comment, creator: user)) }.params { { comment: { body: "abc" } } }.success(:redirect)
          access.gte(User::Levels::MEMBER).json.put { |user| comment_path(create(:comment, creator: user)) }.params { { comment: { body: "abc" } } }
        end
      end

      context("access control (not creator)") do
        asserts do
          access.gte(User::Levels::ADMIN).put { comment_path(@comment) }.params { { comment: { body: "abc" } } }.success(:redirect)
          access.gte(User::Levels::ADMIN).json.put { comment_path(@comment) }.params { { comment: { body: "abc" } } }
        end
      end
    end

    context("new action") do
      should("render") do
        get_auth(new_comment_path, @user)

        assert_response(:success)
      end

      context("access control") do
        asserts do
          access.gte(User::Levels::MEMBER).get(new_comment_path)
        end
      end
    end

    context("create action") do
      should("create a comment") do
        assert_difference("Comment.count", 1) do
          post_auth(comments_path, @user, params: { comment: { body: "abc", post_id: @post.id } })
        end
        comment = Comment.last

        assert_redirected_to(post_path(comment.post))
      end

      should("not allow commenting on nonexistent posts") do
        assert_difference("Comment.count", 0) do
          post_auth(comments_path, @user, params: { comment: { body: "abc", post_id: -1 } })
        end
        assert_redirected_to(comments_path)
      end

      context("access control") do
        asserts do
          access.gte(User::Levels::MEMBER).post(comments_path).params { { comment: { body: "abc", post_id: @post.id } } }.success(:redirect)
          access.gte(User::Levels::MEMBER).json.post(comments_path).params { { comment: { body: "abc", post_id: @post.id } } }
        end
      end
    end

    context("hide action") do
      should("mark comment as hidden") do
        put_auth(hide_comment_path(@comment), @user)

        assert_redirected_to(@comment)
        assert_predicate(@comment.reload, :is_hidden?)
      end

      context("access control") do
        asserts do
          access.gte(User::Levels::MEMBER).put { |user| hide_comment_path(create(:comment, creator: user)) }.success(:redirect)
          access.gte(User::Levels::MEMBER).json.put { |user| hide_comment_path(create(:comment, creator: user)) }
        end
      end

      context("access control (not creator)") do
        asserts do
          access.gte(User::Levels::MODERATOR).put { hide_comment_path(@comment) }.success(:redirect)
          access.gte(User::Levels::MODERATOR).json.put { hide_comment_path(@comment) }
        end
      end
    end

    context("unhide action") do
      setup do
        @comment.hide!(@user)
      end

      should("mark comment as unhidden if mod") do
        put_auth(unhide_comment_path(@comment.id), @mod)

        assert_redirected_to(@comment)
        assert_not(@comment.reload.is_hidden?)
      end

      should("not mark comment as unhidden if not mod") do
        put_auth(unhide_comment_path(@comment.id), @user)

        assert_response(:forbidden)
        assert(@comment.reload.is_hidden)
      end

      context("access control") do
        asserts do
          access.gte(User::Levels::MODERATOR).put { unhide_comment_path(@comment) }.success(:redirect)
          access.gte(User::Levels::MODERATOR).json.put { unhide_comment_path(@comment) }
        end
      end
    end

    context("destroy action") do
      should("work") do
        delete_auth(comment_path(@comment), create(:admin_user))
        assert_raises(ActiveRecord::RecordNotFound) { @comment.reload }
      end

      context("on a comment with edit history") do
        setup do
          @comment.update_with!(@user, body: "hi hello")
        end

        should("also delete the edit history") do
          assert_difference({ "Comment.count" => -1, "EditHistory.count" => -2 }) do
            delete_auth(comment_path(@comment), create(:admin_user))
          end
        end
      end

      context("access control") do
        asserts do
          access.gte(User::Levels::ADMIN).delete { comment_path(@comment) }.success(:redirect)
          access.gte(User::Levels::ADMIN).json.delete { comment_path(@comment) }.success(:no_content)
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

      should("mark spam comments as spam") do
        SpamDetector.any_instance.stubs(:spam?).returns(true)
        assert_difference(%w[User.system.tickets.count Comment.count], 1) do
          post_auth(comments_path, @user, params: { comment: { body: "abc", post_id: @post.id } })

          assert_redirected_to(post_path(@post))
        end
        @ticket = User.system.tickets.last
        @comment = Comment.last

        assert_equal(@comment, @ticket.model)
        assert_equal("Spam.", @ticket.reason)
        assert_predicate(@comment, :is_spam?)
      end

      should("not mark moderator comments as spam") do
        # no need to stub anything, it should return false due to Trusted+ bypassing spam checks
        assert_difference({ "User.system.tickets.count" => 0, "Comment.count" => 1 }) do
          post_auth(comments_path, @mod, params: { comment: { body: "abc", post_id: @post.id } })

          assert_redirected_to(post_path(@post))
        end
        @comment = Comment.last

        assert_not(@comment.is_spam?)
      end

      should("auto ban spammers") do
        SpamDetector.any_instance.stubs(:spam?).returns(true)

        stub_const(SpamDetector, :AUTOBAN_THRESHOLD, 1) do
          assert_difference(%w[Ban.count User.system.tickets.count Comment.count], 1) do
            post_auth(comments_path, @user, params: { comment: { body: "abc", post_id: @post.id } })

            assert_redirected_to(post_path(@post))
          end
        end
        @ticket = User.system.tickets.last
        @comment = Comment.last

        assert_equal(@comment, @ticket.model)
        assert_equal("Spam.", @ticket.reason)
        assert_equal("Automatically Banned", @ticket.response)
        assert_equal("approved", @ticket.status)
        assert_predicate(@comment, :is_spam?)
        assert_predicate(@user.reload, :is_banned?)
      end

      context("mark spam action") do
        should("work and report false negative") do
          SpamDetector.any_instance.expects(:spam!).times(1)

          assert_not(@comment.reload.is_spam?)
          put_auth(mark_spam_comment_path(@comment), @mod)

          assert_response(:success)
          assert_predicate(@comment.reload, :is_spam?)
        end

        should("work and not report false negative if ticket exists") do
          SpamDetector.any_instance.expects(:spam!).never
          User.system.tickets.create!(model: @comment, reason: "Spam.", creator_ip_addr: "127.0.0.1")

          assert_not(@comment.reload.is_spam?)
          put_auth(mark_spam_comment_path(@comment), @mod)

          assert_response(:success)
          assert_predicate(@comment.reload, :is_spam?)
        end

        context("access control") do
          setup { SpamDetector.any_instance.stubs(:spam!).returns(true) }

          asserts do
            access.gte(User::Levels::MODERATOR).json.put { mark_spam_comment_path(@comment) }
          end
        end
      end

      context("mark not spam action") do
        should("work and not report false positive") do
          SpamDetector.any_instance.expects(:ham!).never
          @comment.update_column(:is_spam, true)

          assert_predicate(@comment.reload, :is_spam?)
          put_auth(mark_not_spam_comment_path(@comment), @mod)

          assert_response(:success)
          assert_not(@comment.reload.is_spam?)
        end

        should("work and report false positive if ticket exists") do
          SpamDetector.any_instance.expects(:ham!).times(1)
          User.system.tickets.create!(model: @comment, reason: "Spam.", creator_ip_addr: "127.0.0.1")
          @comment.update_column(:is_spam, true)

          assert_predicate(@comment.reload, :is_spam?)
          put_auth(mark_not_spam_comment_path(@comment), @mod)

          assert_response(:success)
          assert_not(@comment.reload.is_spam?)
        end

        context("access control") do
          asserts do
            access.gte(User::Levels::MODERATOR).json.put { mark_not_spam_comment_path(@comment) }
          end
        end
      end
    end

    context("warning action") do
      should("mark warning") do
        put_auth(warning_comment_path(@comment), @mod, params: { record_type: "warning" })

        assert_response(:success)
        assert_equal("warning", @comment.reload.warning_type)
        assert_equal(@mod.id, @comment.reload.warning_user_id)
      end

      should("mark record") do
        put_auth(warning_comment_path(@comment), @mod, params: { record_type: "record" })

        assert_response(:success)
        assert_equal("record", @comment.reload.warning_type)
        assert_equal(@mod.id, @comment.reload.warning_user_id)
      end

      should("mark ban") do
        put_auth(warning_comment_path(@comment), @mod, params: { record_type: "ban" })

        assert_response(:success)
        assert_equal("ban", @comment.reload.warning_type)
        assert_equal(@mod.id, @comment.reload.warning_user_id)
      end

      should("unmark") do
        @comment.user_warned!("warning", @mod)
        put_auth(warning_comment_path(@comment), @mod, params: { record_type: "unmark" })

        assert_response(:success)
        assert_nil(@comment.reload.warning_type)
        assert_nil(@comment.reload.warning_user_id)
      end

      context("access control") do
        asserts do
          access.gte(User::Levels::MODERATOR).json.put { warning_comment_path(@comment) }.params { { record_type: "warning" } }
        end
      end
    end
  end
end

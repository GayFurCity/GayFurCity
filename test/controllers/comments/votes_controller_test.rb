# frozen_string_literal: true

require("test_helper")

module Comments
  class VotesControllerTest < ActionDispatch::IntegrationTest
    context("The comment votes controller") do
      setup do
        @user = create(:user)
        @post = create(:post, uploader: @user)
        @comment = create(:comment, post: @post)

        @user2 = create(:user)
        @admin = create(:admin_user)
      end

      context("index action") do
        should("render") do
          get_auth(url_for(controller: "comments/votes", action: "index", only_path: true), @admin)

          assert_response(:success)
        end

        context("members") do
          should("render") do
            get_auth(url_for(controller: "comments/votes", action: "index", only_path: true), @user2)

            assert_response(:success)
          end

          should("only list own votes") do
            create(:comment_vote, comment: @comment, user: @user2, score: -1)
            create(:comment_vote, comment: @comment, user: @admin, score: 1)

            get_auth(url_for(controller: "comments/votes", action: "index", format: "json", only_path: true), @user2)

            assert_response(:success)
            assert_equal(1, response.parsed_body.length)
            assert_equal(@user2.id, response.parsed_body[0]["user_id"])
          end
        end

        context("access control") do
          asserts do
            access.gte(User::Levels::MEMBER).get(url_for(controller: "comments/votes", action: "index", only_path: true))
            access.gte(User::Levels::MEMBER).json.get(url_for(controller: "comments/votes", action: "index", only_path: true))
          end
        end

        context("search parameters") do
          subject { url_for(controller: "comments/votes", action: "index", only_path: true) }
          setup do
            CommentVote.delete_all
            @creator = create(:user)
            @voter = create(:user, created_at: 2.weeks.ago)
            @voter2 = create(:user, created_at: 2.weeks.ago)
            @admin = create(:admin_user)
            @comment = create(:comment, creator: @creator)
            @vote = create(:comment_vote, comment: @comment, score: 1, user: @voter, user_ip_addr: "127.0.0.2", is_locked: false)
            @vote2 = create(:comment_vote, comment: @comment, score: -1, user: @voter2, user_ip_addr: "127.0.0.2", is_locked: false)
          end

          asserts do
            search(:comment_id).value { @comment.id }.records { [@vote] }.user { @voter }
            search(:ip_addr, "127.0.0.2").records { [@vote2, @vote] }.user { @admin }
            search(:score, "1").records { [@vote] }.user { @voter }
            search(:timeframe, "1").records { [@vote] }.user { @voter }
            search(:duplicates_only, "true").records { [@vote2, @vote] }.user { @admin }
            search(:comment_creator_id).value { @comment.creator_id }.records { [@vote] }.user { @voter }
            search(:comment_creator_name).value { @comment.creator_name }.records { [@vote] }.user { @voter }
            search(:user_id).value { @voter.id }.records { [@vote] }.user { @voter }
            search(:user_name).value { @voter.name }.records { [@vote] }.user { @voter }
            search(:is_locked, "false").records{ [@vote] }.user { @voter }
            search.shared.records { [@vote] }.user { @voter }
          end
        end
      end

      context("create action") do
        should("create a vote") do
          assert_difference("CommentVote.count", 1) do
            post_auth(comment_votes_path(@comment), @user, params: { score: -1, format: :json })

            assert_response(:success)
          end
        end

        should("unvote when the vote already exists") do
          create(:comment_vote, comment: @comment, user: @user, score: -1)
          assert_difference("CommentVote.count", -1) do
            post_auth(comment_votes_path(@comment), @user, params: { score: -1, format: :json })

            assert_response(:success)
          end
        end

        should("prevent voting on comment locked posts") do
          @post.update(is_comment_locked: true, updater: @admin)
          assert_no_difference("CommentVote.count") do
            post_auth(comment_votes_path(@comment), @user, params: { score: -1, format: :json })

            assert_response(:unprocessable_entity)
          end
        end

        should("prevent unvoting on comment locked posts") do
          @post.update(is_comment_locked: true, updater: @admin)
          create(:comment_vote, comment: @comment, user: @user, score: -1)
          assert_no_difference("CommentVote.count") do
            post_auth(comment_votes_path(@comment), @user, params: { score: -1, format: :json })

            assert_response(:unprocessable_entity)
          end
        end

        should("prevent voting on comment disabled posts") do
          @post.update(is_comment_disabled: true, updater: @admin)
          assert_no_difference("CommentVote.count") do
            post_auth(comment_votes_path(@comment), @user, params: { score: -1, format: :json })

            assert_response(:unprocessable_entity)
          end
        end

        should("prevent unvoting on comment disabled posts") do
          @post.update(is_comment_disabled: true, updater: @admin)
          create(:comment_vote, comment: @comment, user: @user, score: -1)
          assert_no_difference("CommentVote.count") do
            post_auth(comment_votes_path(@comment), @user, params: { score: -1, format: :json })

            assert_response(:unprocessable_entity)
          end
        end

        context("access control") do
          asserts do
            access.gte(User::Levels::MEMBER).json.post { comment_votes_path(@comment) }.params({ score: 1 })
          end
        end
      end

      context("lock action") do
        setup do
          @vote = create(:comment_vote, comment: @comment, user: @user2, score: -1)
        end

        should("lock votes") do
          post_auth(lock_comment_votes_path, @admin, params: { ids: @vote.id, format: :json })

          assert_response(:success)

          assert_predicate(@vote.reload, :is_locked?)
        end

        should("create staff audit log entry") do
          assert_difference("StaffAuditLog.count", 1) do
            post_auth(lock_comment_votes_path, @admin, params: { ids: @vote.id, format: :json })

            assert_response(:success)

            assert_predicate(@vote.reload, :is_locked?)
          end

          log = StaffAuditLog.last

          assert_equal("comment_vote_lock", log.action)
          assert_equal(@comment.id, log.comment_id)
          assert_equal(-1, log.vote)
          assert_equal(@user2.id, log.voter_id)
        end

        context("access control") do
          asserts do
            access.gte(User::Levels::MODERATOR).json.post(lock_comment_votes_path).params { { ids: @vote.id } }
          end
        end
      end

      context("delete action") do
        setup do
          @vote = create(:comment_vote, comment: @comment, user: @user2, score: -1)
        end

        should("delete votes") do
          post_auth(delete_comment_votes_path, @admin, params: { ids: @vote.id, format: :json })

          assert_response(:success)

          assert_raises(ActiveRecord::RecordNotFound) do
            @vote.reload
          end
        end

        should("create a staff audit log entry") do
          assert_difference("StaffAuditLog.count", 1) do
            post_auth(delete_comment_votes_path, @admin, params: { ids: @vote.id, format: :json })

            assert_response(:success)

            assert_raises(ActiveRecord::RecordNotFound) do
              @vote.reload
            end
          end

          log = StaffAuditLog.last

          assert_equal("comment_vote_delete", log.action)
          assert_equal(@comment.id, log.comment_id)
          assert_equal(-1, log.vote)
          assert_equal(@user2.id, log.voter_id)
        end

        context("access control") do
          asserts do
            access.gte(User::Levels::ADMIN).json.post(delete_comment_votes_path).params { { ids: @vote.id } }
          end
        end
      end
    end
  end
end

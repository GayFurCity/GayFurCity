# frozen_string_literal: true

require("test_helper")

module Forums
  module Posts
    class VotesControllerTest < ActionDispatch::IntegrationTest
      context("The forum post votes controller") do
        setup do
          @user = create(:user)
          @topic = create(:forum_topic, original_post_attributes: { body: "test" }, creator: @user)
          @forum_post = @topic.original_post
          @ta = create(:tag_alias, forum_post: @forum_post, antecedent_name: "aaa", consequent_name: "bbb", status: "pending", creator: @user)
          @forum_post.update_with(@user, tag_change_request: @ta, allow_voting: true)
          @topic2 = create(:forum_topic, original_post_attributes: { body: "test2" }, creator: @user)
          @forum_post2 = @topic2.original_post
          @ti = create(:tag_implication, forum_post: @forum_post2, antecedent_name: "ccc", consequent_name: "ddd", status: "pending", creator: @user)
          @forum_post2.update_with(@user, tag_change_request: @ti, allow_voting: true)
          @forum_post3 = create(:forum_post, topic: @topic, allow_voting: false, creator: @user)

          @user2 = create(:user)
          @admin = create(:admin_user)
        end

        context("index action") do
          should("render") do
            get_auth(url_for(controller: "forums/posts/votes", action: "index", only_path: true), @admin)

            assert_response(:success)
          end

          context("members") do
            should("render") do
              get_auth(url_for(controller: "forums/posts/votes", action: "index", only_path: true), @user2)

              assert_response(:success)
            end

            should("only list own votes") do
              create(:forum_post_vote, forum_post: @forum_post, user: @user2, score: -1)
              create(:forum_post_vote, forum_post: @forum_post, user: @admin, score: 1)

              get_auth(url_for(controller: "forums/posts/votes", action: "index", format: "json", only_path: true), @user2)

              assert_response(:success)
              assert_equal(1, response.parsed_body.length)
              assert_equal(@user2.id, response.parsed_body[0]["user_id"])
            end
          end

          should("restrict access") do
            assert_access(User::Levels::MEMBER, anonymous_response: :forbidden) { |user| get_auth(url_for(controller: "forums/posts/votes", action: "index", format: "json", only_path: true), user) }
          end

          context("search parameters") do
            subject { url_for(controller: "forums/posts/votes", action: "index", only_path: true) }
            setup do
              ForumPostVote.delete_all
              @creator = create(:user)
              @voter = create(:user, created_at: 2.weeks.ago)
              @voter2 = create(:user, created_at: 2.weeks.ago)
              @admin = create(:admin_user)
              @forum_post = create(:forum_post, creator: @creator)
              @vote = create(:forum_post_vote, forum_post: @forum_post, score: 1, user: @voter, user_ip_addr: "127.0.0.2")
              @vote2 = create(:forum_post_vote, forum_post: @forum_post, score: -1, user: @voter2, user_ip_addr: "127.0.0.2")
            end

            assert_search_param(:forum_post_id, -> { @forum_post.id }, -> { [@vote] }, -> { @voter })
            assert_search_param(:ip_addr, "127.0.0.2", -> { [@vote2, @vote] }, -> { @admin })
            assert_search_param(:score, "1", -> { [@vote] }, -> { @voter })
            assert_search_param(:timeframe, "1", -> { [@vote] }, -> { @voter })
            assert_search_param(:duplicates_only, "true", -> { [@vote2, @vote] }, -> { @admin })
            assert_search_param(:forum_post_creator_id, -> { @forum_post.creator_id }, -> { [@vote] }, -> { @voter })
            assert_search_param(:forum_post_creator_name, -> { @forum_post.creator_name }, -> { [@vote] }, -> { @voter })
            assert_search_param(:user_id, -> { @voter.id }, -> { [@vote] }, -> { @voter })
            assert_search_param(:user_name, -> { @voter.name }, -> { [@vote] }, -> { @voter })
            assert_shared_search_params(-> { [@vote] }, -> { @voter })
          end
        end

        context("create action") do
          should("create a vote") do
            post_auth(forum_post_votes_path(@forum_post), @user2, params: { score: 1, format: :json })

            assert_response(:success)

            assert_equal(1, @forum_post.votes.find_by(user: @user2)&.score)
          end

          should("not allow voting if user is forbidden") do
            @user2.update(no_aibur_voting: true, updater: @admin)
            post_auth(forum_post_votes_path(@forum_post), @user2, params: { score: 1, format: :json })

            assert_response(:forbidden)
            assert_equal("Access Denied: You are not allowed to vote on tag change requests.", @response.parsed_body["reason"])

            assert_nil(@forum_post.votes.find_by(user: @user2))
          end

          should("not allow voting if allow_voting=false") do
            post_auth(forum_post_votes_path(@forum_post3), @user2, params: { score: 1, format: :json })

            assert_response(:bad_request)
            assert_equal("Forum post does not allow votes.", @response.parsed_body["message"])

            assert_nil(@forum_post3.votes.find_by(user: @user2))
          end

          should("not allow voting on non-pending requests") do
            @ta.update_columns(status: "active")
            post_auth(forum_post_votes_path(@forum_post), @user2, params: { score: 1, format: :json })

            assert_response(:forbidden)
            assert_equal("Access Denied: You cannot vote on completed tag change requests.", @response.parsed_body["reason"])

            @ti.update_columns(status: "deleted")
            post_auth(forum_post_votes_path(@forum_post2), @user2, params: { score: -1, format: :json })

            assert_response(:forbidden)
            assert_equal("Access Denied: You cannot vote on completed tag change requests.", @response.parsed_body["reason"])

            assert_nil(@forum_post2.votes.find_by(user: @user2))
          end

          should("update the forum post's scores") do
            pct = ->(val) { ActiveSupport::NumberHelper.number_to_percentage(val, precision: 2, strip_insignificant_zeros: true) }

            assert_equal(0, @forum_post.total_score)
            assert_equal("0%", pct.call(@forum_post.percentage_score))
            create(:forum_post_vote, forum_post: @forum_post, score: 1)
            create(:forum_post_vote, forum_post: @forum_post, score: 1)

            @forum_post.reload

            assert_equal(2, @forum_post.total_score)
            assert_equal("100%", pct.call(@forum_post.percentage_score))
            post_auth(forum_post_votes_path(@forum_post), @user2, params: { score: -1, format: :json })

            assert_response(:success)

            @forum_post.reload

            assert_equal(1, @forum_post.total_score)
            assert_equal("66.67%", pct.call(@forum_post.percentage_score))
          end

          should("restrict access") do
            assert_access(User::Levels::MEMBER, anonymous_response: :forbidden) { |user| post_auth(forum_post_votes_path(@forum_post), user, params: { score: 1, format: :json }) }
          end
        end

        context("delete action") do
          setup do
            @vote = create(:forum_post_vote, forum_post: @forum_post, user: @user2, score: -1)
          end

          should("delete votes") do
            post_auth(delete_forum_post_votes_path, @admin, params: { ids: @vote.id, format: :json })

            assert_response(:success)

            assert_raises(ActiveRecord::RecordNotFound) do
              @vote.reload
            end
          end

          should("create a staff audit log entry") do
            assert_difference("StaffAuditLog.count", 1) do
              post_auth(delete_forum_post_votes_path, @admin, params: { ids: @vote.id, format: :json })

              assert_response(:success)

              assert_raises(ActiveRecord::RecordNotFound) do
                @vote.reload
              end
            end

            log = StaffAuditLog.last

            assert_equal("forum_post_vote_delete", log.action)
            assert_equal(@forum_post.id, log.forum_post_id)
            assert_equal(-1, log.vote)
            assert_equal(@user2.id, log.voter_id)
          end

          should("restrict access") do
            @votes = []
            User::Levels.constants.length.times do
              @votes << create(:forum_post_vote, forum_post: @forum_post, user: create(:user), score: 1)
            end
            assert_access(User::Levels::ADMIN) { |user| post_auth(delete_forum_post_votes_path, user, params: { ids: @votes.shift.id }) }
          end
        end
      end
    end
  end
end

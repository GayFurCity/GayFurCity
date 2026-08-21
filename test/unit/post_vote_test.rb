# frozen_string_literal: true

require("test_helper")

class PostVoteTest < ActiveSupport::TestCase
  setup do
    @user = create(:user, created_at: 1.month.ago)

    @post = create(:post)
  end

  context("Voting for a post") do
    should("interpret up as +1 score") do
      vote, _status = VoteManager::Posts.vote!(user: @user, ip_addr: "127.0.0.1", post: @post, score: 1)

      assert_equal(1, vote.score)
    end

    should("interpret down as -1 score") do
      vote, _status = VoteManager::Posts.vote!(user: @user, ip_addr: "127.0.0.1", post: @post, score: -1)

      assert_equal(-1, vote.score)
    end

    should("not accept any other scores") do
      error = assert_raises(UserVote::Error) { VoteManager::Posts.vote!(user: @user, ip_addr: "127.0.0.1", post: @post, score: "xxx") }
      assert_equal("Invalid vote", error.message)
    end

    should("increase the score of the post") do
      VoteManager::Posts.vote!(user: @user, ip_addr: "127.0.0.1", post: @post, score: 1)
      @post.reload

      assert_equal(1, @post.score)
      assert_equal(1, @post.up_score)
    end

    should("decrease the score of the post when removed") do
      VoteManager::Posts.vote!(user: @user, ip_addr: "127.0.0.1", post: @post, score: 1)
      @post.reload

      assert_equal(1, @post.score)
      assert_equal(1, @post.up_score)

      VoteManager::Posts.unvote!(user: @user, post: @post)
      @post.reload

      assert_equal(0, @post.score)
      assert_equal(0, @post.up_score)
    end
  end

  context("Searching user votes") do
    setup do
      @admin = create(:admin_user)
      @creator = create(:user)
      @other_creator = create(:user)
      @voter = create(:user)
    end

    should("find post votes by post creator") do
      post = create(:post, uploader: @creator)
      other_post = create(:post, uploader: @other_creator)
      vote = create(:post_vote, post: post, user: @voter)
      create(:post_vote, post: other_post)

      assert_equal([vote], PostVote.search({ post_creator_id: @creator.id }, @admin).to_a)
      assert_equal([vote], PostVote.search({ post_creator_name: @creator.name }, @admin).to_a)
    end

    should("find comment votes by comment creator") do
      comment = create(:comment, creator: @creator)
      other_comment = create(:comment, creator: @other_creator)
      vote = create(:comment_vote, comment: comment, user: @voter)
      create(:comment_vote, comment: other_comment)

      assert_equal([vote], CommentVote.search({ comment_creator_id: @creator.id }, @admin).to_a)
      assert_equal([vote], CommentVote.search({ comment_creator_name: @creator.name }, @admin).to_a)
    end

    should("find forum post votes by forum post creator") do
      forum_post = create(:forum_post, creator: @creator)
      other_forum_post = create(:forum_post, creator: @other_creator)
      vote = create(:forum_post_vote, forum_post: forum_post, user: @voter)
      create(:forum_post_vote, forum_post: other_forum_post)

      assert_equal([vote], ForumPostVote.search({ forum_post_creator_id: @creator.id }, @admin).to_a)
      assert_equal([vote], ForumPostVote.search({ forum_post_creator_name: @creator.name }, @admin).to_a)
    end
  end
end

# frozen_string_literal: true

require("test_helper")

class TagImplicationRequestTest < ActiveSupport::TestCase
  context("A tag implication request") do
    setup do
      @user = create(:user)
    end

    should("handle invalid attributes") do
      tir = TagImplicationRequest.create(antecedent_name: "", consequent_name: "", reason: "reason", user: @user)

      assert_predicate(tir, :invalid?)
    end

    should("create a tag implication") do
      assert_difference("TagImplication.count", 1) do
        TagImplicationRequest.create(antecedent_name: "aaa", consequent_name: "bbb", reason: "reason", user: @user)
      end
      assert_equal("pending", TagImplication.last.status)
    end

    should("create a forum topic") do
      assert_difference("ForumTopic.count", 1) do
        @tir = TagImplicationRequest.create(antecedent_name: "aaa", consequent_name: "bbb", reason: "reason", user: @user).tag_relationship
      end
      @topic = ForumTopic.last

      assert_equal(@tir.forum_topic_id, @topic.id)
      assert_equal(@tir.forum_post_id, @topic.posts.first.id)
      assert_equal(@tir.id, @tir.forum_post.tag_change_request_id)
      assert_equal("TagImplication", @tir.forum_post.tag_change_request_type)
    end

    should("create a post in an existing topic") do
      @topic = create(:forum_topic)
      assert_difference("ForumPost.count", 1) do
        @tir = TagImplicationRequest.create(antecedent_name: "aaa", consequent_name: "bbb", reason: "reason", user: @user, forum_topic: @topic).tag_relationship
      end
      assert_equal(@tir.forum_topic_id, @topic.id)
      assert_equal(@tir.forum_post_id, @topic.posts.second.id)
      assert_equal(@tir.id, @tir.forum_post.tag_change_request_id)
      assert_equal("TagImplication", @tir.forum_post.tag_change_request_type)
    end

    should("not create a topic when skip_forum is true") do
      assert_no_difference("ForumTopic.count") do
        TagImplicationRequest.create(antecedent_name: "aaa", consequent_name: "bbb", user: @user, skip_forum: true)
      end
    end
  end
end

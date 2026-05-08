# frozen_string_literal: true

require("test_helper")

class TagAliasRequestTest < ActiveSupport::TestCase
  context("A tag alias request") do
    setup do
      @user = create(:user)
    end

    should("handle invalid attributes") do
      tar = TagAliasRequest.create(antecedent_name: "", consequent_name: "", reason: "reason", user: @user)

      assert_predicate(tar, :invalid?)
    end

    should("create a tag alias") do
      assert_difference("TagAlias.count", 1) do
        TagAliasRequest.create(antecedent_name: "aaa", consequent_name: "bbb", reason: "reason", user: @user)
      end
      assert_equal("pending", TagAlias.last.status)
    end

    should("create a forum topic") do
      assert_difference("ForumTopic.count", 1) do
        @tar = TagAliasRequest.create(antecedent_name: "aaa", consequent_name: "bbb", reason: "reason", user: @user).tag_relationship
      end
      @topic = ForumTopic.last

      assert_equal(@tar.forum_topic_id, @topic.id)
      assert_equal(@tar.forum_post_id, @topic.posts.first.id)
      assert_equal(@tar.id, @tar.forum_post.tag_change_request_id)
      assert_equal("TagAlias", @tar.forum_post.tag_change_request_type)
    end

    should("create a post in an existing topic") do
      @topic = create(:forum_topic)
      assert_difference("ForumPost.count", 1) do
        @tar = TagAliasRequest.create(antecedent_name: "aaa", consequent_name: "bbb", reason: "reason", forum_topic: @topic, user: @user).tag_relationship
      end
      assert_equal(@tar.forum_topic_id, @topic.id)
      assert_equal(@tar.forum_post_id, @topic.posts.second.id)
      assert_equal(@tar.id, @tar.forum_post.tag_change_request_id)
      assert_equal("TagAlias", @tar.forum_post.tag_change_request_type)
    end

    should("not create a topic when skip_forum is true") do
      assert_no_difference("ForumTopic.count") do
        TagAliasRequest.create(antecedent_name: "aaa", consequent_name: "bbb", skip_forum: true, user: @user)
      end
    end

    should("fail validation if the reason is too short") do
      tar = TagAliasRequest.create(antecedent_name: "aaa", consequent_name: "bbb", reason: "", user: @user)

      assert_match(/Reason is too short/, tar.errors.full_messages.join)
    end

    should("not create a forum post if skip_forum is true") do
      assert_no_difference("ForumPost.count") do
        TagAliasRequest.create(antecedent_name: "aaa", consequent_name: "bbb", skip_forum: true, user: @user)
      end
    end
  end
end

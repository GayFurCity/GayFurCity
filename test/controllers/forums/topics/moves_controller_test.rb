# frozen_string_literal: true

require("test_helper")

module Forums
  module Topics
    class MovesControllerTest < ActionDispatch::IntegrationTest
      context("The forum topic moves controller") do
        setup do
          @mod = create(:moderator_user)
          @forum_topic = create(:forum_topic)
        end

        context("show action") do
          should("render") do
            get_auth(move_forum_topic_path(@forum_topic), @mod)
          end

          context("access control") do
            asserts do
              access.gte(User::Levels::MODERATOR).get { move_forum_topic_path(@forum_topic) }
            end
          end
        end

        context("create action") do
          setup do
            @category = @forum_topic.category
            @category2 = create(:forum_category)
          end

          should("move the topic") do
            post_auth(move_forum_topic_path(@forum_topic), @mod, params: { forum_topic: { category_id: @category2.id } })

            assert_redirected_to(forum_topic_path(@forum_topic))
            @forum_topic.reload

            assert_equal(@category2.id, @forum_topic.category.id)
          end

          should("not move the topic if the mover cannot create within the new category") do
            @category2.update_column(:can_create, @mod.level + 1)
            post_auth(move_forum_topic_path(@forum_topic), @mod, params: { forum_topic: { category_id: @category2.id }, format: :json })

            assert_response(:forbidden)
            assert_equal("You cannot move topics into categories you cannot create within.", @response.parsed_body["message"])
            @forum_topic.reload

            assert_equal(@category.id, @forum_topic.category.id)
          end

          should("not move the topic if the topic creator cannot create within the new category") do
            @category2.update_column(:can_create, @forum_topic.creator.level + 1)
            post_auth(move_forum_topic_path(@forum_topic), @mod, params: { forum_topic: { category_id: @category2.id }, format: :json })

            assert_response(:forbidden)
            assert_equal("You cannot move topics into categories the topic creator cannot create within.", @response.parsed_body["message"])
            @forum_topic.reload

            assert_equal(@category.id, @forum_topic.category.id)
          end

          context("access control") do
            asserts do
              access.gte(User::Levels::MODERATOR).post { move_forum_topic_path(@forum_topic) }.params { { forum_topic: { category_id: @category2.id } } }.success(:redirect)
              access.gte(User::Levels::MODERATOR).json.post { move_forum_topic_path(@forum_topic) }.params { { forum_topic: { category_id: @category2.id } } }
            end
          end
        end
      end
    end
  end
end

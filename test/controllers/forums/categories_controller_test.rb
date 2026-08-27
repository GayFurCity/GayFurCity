# frozen_string_literal: true

require("test_helper")

module Forums
  class CategoriesControllerTest < ActionDispatch::IntegrationTest
    context("The forum categories controller") do
      setup do
        @user = create(:user)
        @admin = create(:admin_user)
        @category = ForumCategory.find_by(id: AdminConfig.instance.alias_and_implication_forum_category) || create(:forum_category)
        @category2 = create(:forum_category, can_view: User::Levels::ADMIN, can_create: User::Levels::ADMIN)
      end

      context("show action") do
        should("render") do
          get(forum_category_path(@category))

          assert_redirected_to(forum_topics_path(search: { category_id: @category.id }))
        end

        context("access control") do
          context("for public category") do
            asserts do
              access.gte(User::Levels::ANONYMOUS).get { forum_category_path(@category) }.success(:redirect).anonymous(:redirect)
              access.gte(User::Levels::ANONYMOUS).json.get { forum_category_path(@category) }
            end
          end

          context("for restricted category") do
            asserts do
              access.gte(User::Levels::ADMIN).get { forum_category_path(@category2) }.success(:redirect)
              access.gte(User::Levels::ADMIN).json.get { forum_category_path(@category2) }
            end
          end
        end
      end

      context("index action") do
        should("render") do
          get(forum_categories_path)

          assert_response(:success)
        end

        should("only list visible categories") do
          get(forum_categories_path(format: :json))

          assert_response(:success)
          assert_equal([@category.id], @response.parsed_body.pluck("id"))
        end

        context("access control") do
          asserts do
            access.gte(User::Levels::ANONYMOUS).get(forum_categories_path)
            access.gte(User::Levels::ANONYMOUS).json.get(forum_categories_path)
          end
        end
      end

      context("edit action") do
        should("work") do
          get_auth(edit_forum_category_path(@category), @admin)

          assert_response(:success)
        end

        context("access control") do
          asserts do
            access.gte(User::Levels::ADMIN).get { edit_forum_category_path(@category) }
          end
        end
      end

      context("update action") do
        should("work") do
          put_auth(forum_category_path(@category), @admin, params: { forum_category: { name: "foobar" } })

          assert_redirected_to(forum_categories_path)
          assert_equal("foobar", @category.reload.name)
        end

        context("access control") do
          asserts do
            access.gte(User::Levels::ADMIN).put { forum_category_path(@category) }.params { { name: SecureRandom.hex(6) } }.success(:redirect)
            access.gte(User::Levels::ADMIN).json.put { forum_category_path(@category) }.params { { name: SecureRandom.hex(6) } }
          end
        end
      end

      context("new action") do
        should("work") do
          get_auth(new_forum_category_path, @admin)

          assert_response(:success)
        end

        context("access control") do
          asserts do
            access.gte(User::Levels::ADMIN).get(new_forum_category_path)
          end
        end
      end

      context("create action") do
        should("work") do
          assert_difference("ForumCategory.count", 1) do
            post_auth(forum_categories_path, @admin, params: { forum_category: { name: "foobar" } })

            assert_redirected_to(forum_categories_path)
            assert_equal("foobar", ForumCategory.last.name)
          end
        end

        context("access control") do
          asserts do
            access.gte(User::Levels::ADMIN).post(forum_categories_path).params { { forum_category: { name: SecureRandom.hex(6) } } }.success(:redirect)
            access.gte(User::Levels::ADMIN).json.post(forum_categories_path).params { { forum_category: { name: SecureRandom.hex(6) } } }
          end
        end
      end

      context("destroy action") do
        context("with no topics") do
          should("work") do
            assert_difference("ForumCategory.count", -1) do
              delete_auth(forum_category_path(@category), @admin)

              assert_redirected_to(forum_categories_path)
            end
          end

          context("access control") do
            asserts do
              access.gte(User::Levels::ADMIN).delete { forum_category_path(@category) }.success(:redirect)
              access.gte(User::Levels::ADMIN).json.delete { forum_category_path(@category) }.success(:no_content)
            end
          end
        end

        context("with topics") do
          setup do
            @topic = create(:forum_topic, category: @category)
          end

          should("fail") do
            assert_no_difference(%w[ForumCategory.count ForumTopic.count]) do
              delete_auth(forum_category_path(@category), @admin, params: { format: :json })

              assert_response(:unprocessable_entity)
              assert_equal(["Forum category cannot be deleted because it has topics"], @response.parsed_body.dig("errors", "base"))
            end
          end
        end
      end

      context("move_all_topics action") do
        setup do
          @category3 = create(:forum_category)
          @category4 = create(:forum_category)
          @topic = create(:forum_topic, category: @category3)
        end

        should("work") do
          assert_equal(@category3.id, @topic.category_id)
          assert_difference({ "@category3.topics.count" => -1, "@category4.topics.count" => 1 }) do
            post_auth(move_all_topics_forum_category_path(@category3), @admin, params: { forum_category: { new_category_id: @category4.id } })

            assert_redirected_to(forum_categories_path)
            perform_enqueued_jobs(only: MoveForumCategoryTopicsJob)

            assert_equal(@category4.id, @topic.reload.category_id)
          end
        end

        should("fail if the category has too many topics") do
          stub_const(ForumCategory, :MAX_TOPIC_MOVE_COUNT, 0) do
            assert_no_difference(%w[@category3.topics.count @category4.topics.count]) do
              post_auth(move_all_topics_forum_category_path(@category3), @admin, params: { forum_category: { new_category_id: @category4.id } })

              assert_response(:bad_request)
            end
          end
        end

        context("access control") do
          asserts do
            access.gte(User::Levels::ADMIN).post { move_all_topics_forum_category_path(@category3) }.params { { forum_category: { new_category_id: @category4.id } } }.success(:redirect)
            access.gte(User::Levels::ADMIN).json.post { move_all_topics_forum_category_path(@category3) }.params { { forum_category: { new_category_id: @category4.id } } }.success(:no_content)
          end
        end
      end

      context("mark_as_read action") do
        should("work") do
          assert_difference("ForumCategoryVisit.count", 1) do
            put_auth(mark_as_read_forum_category_path(@category), @admin)

            assert_redirected_to(forum_category_path(@category))
          end
          assert(@admin.forum_category_visits.exists?(forum_category: @category))
        end

        context("access control") do
          asserts do
            access.gte(User::Levels::REJECTED).put { mark_as_read_forum_category_path(@category) }.success(:redirect)
            access.gte(User::Levels::REJECTED).json.put { mark_as_read_forum_category_path(@category) }.success(:no_content)
          end
        end
      end

      context("mark_all_as_read action") do
        should("work") do
          assert_difference("ForumCategoryVisit.count", ForumCategory.count) do
            put_auth(mark_all_as_read_forum_categories_path, @admin)

            assert_redirected_to(forums_path)
          end
          ForumCategory.find_each do |category|
            assert(@admin.forum_category_visits.exists?(forum_category: category))
          end
        end

        context("access control") do
          asserts do
            access.gte(User::Levels::REJECTED).put(mark_all_as_read_forum_categories_path).success(:redirect)
            access.gte(User::Levels::REJECTED).json.put(mark_all_as_read_forum_categories_path).success(:no_content)
          end
        end
      end
    end
  end
end

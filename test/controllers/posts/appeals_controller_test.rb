# frozen_string_literal: true

require("test_helper")

module Posts
  class AppealsControllerTest < ActionDispatch::IntegrationTest
    context("The post appeals controller") do
      setup do
        @admin = create(:admin_user)
        @appeal = create(:post_appeal)
        @post = create(:post, is_deleted: true)
      end

      context("index action") do
        should("render") do
          get(post_appeals_path)

          assert_response(:success)
        end

        context("access control") do
          asserts do
            access.gte(User::Levels::ANONYMOUS).get(post_appeals_path)
            access.gte(User::Levels::ANONYMOUS).json.get(post_appeals_path)
          end
        end

        context("search parameters") do
          subject { post_appeals_path }
          setup do
            PostAppeal.delete_all
            @creator = create(:user)
            @updater = create(:user)
            @admin = create(:admin_user)
            @post = create(:post, is_deleted: true, tag_string: "foo")
            @post_appeal = create(:post_appeal, post: @post, creator: @creator, creator_ip_addr: "127.0.0.2", updater: @updater, updater_ip_addr: "127.0.0.3", reason: "bar", status: "pending")
          end

          asserts do
            search(:post_id).value { @post.id }.records { [@post_appeal] }
            search(:reason_matches, "bar").records { [@post_appeal] }
            search(:status, "pending").records { [@post_appeal] }
            search(:creator_id).value { @creator.id }.records { [@post_appeal] }
            search(:creator_name).value { @creator.name }.records { [@post_appeal] }
            search(:ip_addr, "127.0.0.2").records { [@post_appeal] }.user { @admin }
            search(:updater_id).value { @updater.id }.records { [@post_appeal] }
            search(:updater_name).value { @updater.name }.records { [@post_appeal] }
            search(:updater_ip_addr, "127.0.0.3").records { [@post_appeal] }.user { @admin }
            search(:post_tags_match, "foo").records { [@post_appeal] }
            search.shared.records { [@post_appeal] }
          end
        end
      end

      context("new action") do
        should("render") do
          get_auth(new_post_appeal_path, @admin, params: { post_appeal: { post_id: @appeal.id } })

          assert_response(:success)
        end

        context("access control") do
          asserts do
            access.gte(User::Levels::MEMBER).get(new_post_appeal_path).params { { post_appeal: { post_id: @appeal.id } } }
          end
        end
      end

      context("create action") do
        should("work") do
          assert_difference("PostEvent.count", 1) do
            post_auth(post_appeals_path, @admin, params: { post_appeal: { post_id: @post.id } })

            assert_redirected_to(post_path(@post))
          end
          assert_predicate(@post.reload, :is_appealed?)
          assert_equal("appeal_created", PostEvent.last.action)
        end

        context("access control") do
          asserts do
            access.gte(User::Levels::MEMBER).post(post_appeals_path).params { { post_appeal: { post_id: create(:post, is_deleted: true).id } } }.success(:redirect)
            access.gte(User::Levels::MEMBER).json.post(post_appeals_path).params { { post_appeal: { post_id: create(:post, is_deleted: true).id } } }
          end
        end
      end

      context("destroy action") do
        should("work") do
          @appeal = create(:post_appeal, post: @post)
          assert_difference("PostEvent.count", 1) do
            delete_auth(post_appeal_path(@appeal), create(:janitor_user))

            assert_redirected_to(post_path(@post))
          end
          assert_predicate(@post.reload, :is_deleted?)
          assert_not(@post.reload.is_appealed?)
          assert_equal("appeal_rejected", PostEvent.last.action)
          assert_predicate(@appeal.creator.notifications.appeal_reject, :exists?)
        end

        context("access control") do
          asserts do
            access.levels([User::Levels::JANITOR, User::Levels::ADMIN, User::Levels::OWNER]).delete { post_appeal_path(@appeal) }.success(:redirect)
            access.levels([User::Levels::JANITOR, User::Levels::ADMIN, User::Levels::OWNER]).json.delete { post_appeal_path(@appeal) }.success(:no_content)
          end
        end
      end

      context("accepting") do
        should("work") do
          @appeal = create(:post_appeal, post: @post)
          assert_difference("PostEvent.count", 2) do
            put_auth(undelete_post_path(@post), @admin)

            assert_redirected_to(post_path(@post))
          end
          assert_predicate(@post.reload, :is_active?)
          assert_not(@post.reload.is_appealed?)
          assert_equal(%w[undeleted appeal_accepted], PostEvent.last(2).map(&:action))
          assert_predicate(@appeal.creator.notifications.appeal_accept, :exists?)
        end

        context("access control") do
          asserts do
            access.levels([User::Levels::JANITOR, User::Levels::ADMIN, User::Levels::OWNER]).put { undelete_post_path(@appeal.post) }.success(:redirect)
            access.levels([User::Levels::JANITOR, User::Levels::ADMIN, User::Levels::OWNER]).json.put { undelete_post_path(@appeal.post) }
          end
        end
      end
    end
  end
end

# frozen_string_literal: true

require("test_helper")

module Posts
  class ApprovalsControllerTest < ActionDispatch::IntegrationTest
    context("The post approvals controller") do
      setup do
        @approval = create(:post_approval)
      end

      context("index action") do
        should("render") do
          get(post_approvals_path)

          assert_response(:success)
        end

        context("access control") do
          asserts do
            access.gte(User::Levels::ANONYMOUS).get(post_approvals_path)
          end
        end

        context("search parameters") do
          subject { post_approvals_path }
          setup do
            PostApproval.delete_all
            @creator = create(:user)
            @admin = create(:admin_user)
            @post = create(:post, is_deleted: true, tag_string: "foo")
            @post_approval = create(:post_approval, post: @post, user: @creator, user_ip_addr: "127.0.0.2")
          end

          asserts do
            search(:post_id).value { @post.id }.records { [@post_approval] }
            search(:post_tags_match, "foo").records { [@post_approval] }
            search(:user_id).value { @creator.id }.records { [@post_approval] }
            search(:user_name).value { @creator.name }.records { [@post_approval] }
            search(:ip_addr, "127.0.0.2").records { [@post_approval] }.user { @admin }
            search.shared.records { [@post_approval] }
          end
        end
      end

      context("create action") do
        setup do
          @admin = create(:admin_user)
          @post = create(:post, is_pending: true)
        end

        should("work") do
          post_auth(post_approvals_path, @admin, params: { post_id: @post.id, format: :json })

          assert_response(:success)
          @post.reload

          assert_not(@post.reload.is_pending?)
          assert_predicate(@post.uploader.notifications.post_approve, :exists?)
        end

        context("access control") do
          asserts do
            access.levels([User::Levels::JANITOR, User::Levels::ADMIN, User::Levels::OWNER]).json.post(post_approvals_path).params { { post_id: @post.id } }
          end
        end
      end

      context("destroy action") do
        setup do
          @admin = create(:admin_user)
          @post = create(:post, is_pending: true)
          @post.approve!(@admin)
        end

        should("work") do
          delete_auth(post_approval_path(@post), @admin, params: { format: :json })

          assert_response(:success)
          assert_predicate(@post.reload, :is_pending?)
          assert_predicate(@post.uploader.notifications.post_unapprove, :exists?)
        end

        should("not work if user is not approver") do
          delete_auth(post_approval_path(@post), create(:admin_user), params: { format: :json })

          assert_response(:bad_request)
          assert_not(@post.reload.is_pending?)
        end

        context("access control") do
          asserts do
            access do |builder|
              builder.levels([User::Levels::JANITOR, User::Levels::ADMIN, User::Levels::OWNER]).json.delete do |user|
                post = create(:post, is_pending: true)
                post.approve!(user)
                post_approval_path(post)
              end
            end
          end
        end
      end
    end
  end
end

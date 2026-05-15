# frozen_string_literal: true

require("test_helper")

module Admin
  class DestroyedPostsControllerTest < ActionDispatch::IntegrationTest
    context("The destroyed posts controller") do
      setup do
        @admin = create(:admin_user)
        @owner = create(:owner_user)
        @upload = create(:jpg_upload, uploader: @admin)
        @post = @upload.post
        @post.expunge!(@admin)
        @destroyed_post = DestroyedPost.find_by!(post_id: @post.id)
      end

      context("index action") do
        should("render") do
          get_auth(admin_destroyed_posts_path, @admin)

          assert_response(:success)
        end

        context("access control") do
          asserts do
            access.gte(User::Levels::ADMIN).get(admin_destroyed_posts_path)
            access.gte(User::Levels::ADMIN).json.get(admin_destroyed_posts_path)
          end
        end
      end

      context("show action") do
        should("redirect") do
          get_auth(admin_destroyed_post_path(@post), @admin)

          assert_redirected_to(admin_destroyed_posts_path(search: { post_id: @post.id }))
        end

        context("access control") do
          asserts do
            access.gte(User::Levels::ADMIN).get { admin_destroyed_post_path(@post) }.success(:redirect)
            access.gte(User::Levels::ADMIN).json.get { admin_destroyed_post_path(@post) }
          end
        end
      end

      context("update action") do
        should("work") do
          assert_difference("StaffAuditLog.count", 1) do
            put_auth(admin_destroyed_post_path(@post), @owner, params: { destroyed_post: { notify: "false" } })

            assert_redirected_to(admin_destroyed_posts_path)
            assert_not(@destroyed_post.reload.notify)
            assert_equal("disable_post_notifications", StaffAuditLog.last.action)
          end

          assert_difference("StaffAuditLog.count", 1) do
            put_auth(admin_destroyed_post_path(@post), @owner, params: { destroyed_post: { notify: "true" } })

            assert_redirected_to(admin_destroyed_posts_path)
            assert(@destroyed_post.reload.notify)
            assert_equal("enable_post_notifications", StaffAuditLog.last.action)
          end
        end

        context("access control") do
          asserts do
            access.gte(User::Levels::OWNER).put { admin_destroyed_post_path(@post) }.params({ destroyed_post: { notify: "true" } }).success(:redirect)
            access.gte(User::Levels::OWNER).json.put { admin_destroyed_post_path(@post) }.params({ destroyed_post: { notify: "true" } })
          end
        end
      end
    end
  end
end

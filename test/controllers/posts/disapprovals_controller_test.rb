# frozen_string_literal: true

require("test_helper")

module Posts
  class DisapprovalsControllerTest < ActionDispatch::IntegrationTest
    context("The post disapprovals controller") do
      setup do
        @user = create(:user)
        @admin = create(:admin_user)
        @post = create(:post, is_pending: true)
      end

      context("create action") do
        should("render") do
          assert_difference("PostDisapproval.count", 1) do
            post_auth(post_disapprovals_path, @admin, params: { post_disapproval: { post_id: @post.id, reason: "borderline_quality" }, format: :json })

            assert_response(:success)
          end
        end

        context("access control") do
          asserts do
            access.levels([User::Levels::JANITOR, User::Levels::ADMIN, User::Levels::OWNER]).json.post(post_disapprovals_path).params { { post_disapproval: { post_id: @post.id, reason: "borderline_quality" } } }
          end
        end
      end

      context("index action") do
        should("render") do
          create(:post_disapproval, post: @post)
          get_auth(post_disapprovals_path, @admin)

          assert_response(:success)
        end

        context("access control") do
          asserts do
            access.levels([User::Levels::JANITOR, User::Levels::ADMIN, User::Levels::OWNER]).get(post_disapprovals_path)
          end
        end

        context("search parameters") do
          subject { post_disapprovals_path }
          setup do
            PostDisapproval.delete_all
            @creator = create(:user)
            @janitor = create(:janitor_user)
            @admin = create(:admin_user)
            @post = create(:post, is_deleted: true, tag_string: "foo")
            @post_disapproval = create(:post_disapproval, post: @post, user: @creator, user_ip_addr: "127.0.0.2", message: "foo", reason: "other")
          end

          asserts do
            search(:post_id).value { @post.id }.records { [@post_disapproval] }.user { @janitor }
            search(:message, "foo").records { [@post_disapproval] }.user { @janitor }
            search(:reason, "other").records { [@post_disapproval] }.user { @janitor }
            search(:post_tags_match, "foo").records { [@post_disapproval] }.user { @janitor }
            search(:has_message, "true").records { [@post_disapproval] }.user { @janitor }
            search(:creator_id).value { @creator.id }.records { [@post_disapproval] }.user { @janitor }
            search(:creator_name).value { @creator.name }.records { [@post_disapproval] }.user { @janitor }
            search(:ip_addr, "127.0.0.2").records { [@post_disapproval] }.user { @admin }
            search.shared.records { [@post_disapproval] }.user { @janitor }
          end
        end
      end
    end
  end
end

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

        should("restrict access") do
          assert_access([User::Levels::JANITOR, User::Levels::ADMIN, User::Levels::OWNER], anonymous_response: :forbidden) { |user| post_auth(post_disapprovals_path, user, params: { post_disapproval: { post_id: @post.id, reason: "borderline_quality" }, format: :json }) }
        end
      end

      context("index action") do
        should("render") do
          create(:post_disapproval, post: @post)
          get_auth(post_disapprovals_path, @admin)

          assert_response(:success)
        end

        should("restrict access") do
          assert_access([User::Levels::JANITOR, User::Levels::ADMIN, User::Levels::OWNER]) { |user| get_auth(post_disapprovals_path, user) }
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

          assert_search_param(:post_id, -> { @post.id }, -> { [@post_disapproval] }, -> { @janitor })
          assert_search_param(:message, "foo", -> { [@post_disapproval] }, -> { @janitor })
          assert_search_param(:reason, "other", -> { [@post_disapproval] }, -> { @janitor })
          assert_search_param(:post_tags_match, "foo", -> { [@post_disapproval] }, -> { @janitor })
          assert_search_param(:has_message, "true", -> { [@post_disapproval] }, -> { @janitor })
          assert_search_param(:creator_id, -> { @creator.id }, -> { [@post_disapproval] }, -> { @janitor })
          assert_search_param(:creator_name, -> { @creator.name }, -> { [@post_disapproval] }, -> { @janitor })
          assert_search_param(:ip_addr, "127.0.0.2", -> { [@post_disapproval] }, -> { @admin })
          assert_shared_search_params(-> { [@post_disapproval] }, -> { @janitor })
        end
      end
    end
  end
end

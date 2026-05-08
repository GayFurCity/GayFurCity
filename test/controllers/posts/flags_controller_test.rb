# frozen_string_literal: true

require("test_helper")

module Posts
  class FlagsControllerTest < ActionDispatch::IntegrationTest
    context("The post flags controller") do
      setup do
        @user = create(:user, created_at: 2.weeks.ago)
        @post = create(:post, uploader: @user)
        @post_flag = create(:post_flag, post: @post, creator: @user)
      end

      context("new action") do
        should("render") do
          get_auth(new_post_flag_path, @user, params: { post_flag: { post_id: @post.id } })

          assert_response(:success)
        end

        should("restrict access") do
          assert_access(User::Levels::MEMBER) { |user| get_auth(new_post_flag_path, user, params: { post_flag: { post_id: @post.id } }) }
        end
      end

      context("index action") do
        should("render") do
          get_auth(post_flags_path, @user)

          assert_response(:success)
        end

        context("with search parameters") do
          should("render") do
            get_auth(post_flags_path, @user, params: { search: { post_id: @post_flag.post_id } })

            assert_response(:success)
          end
        end

        should("restrict access") do
          assert_access(User::Levels::ANONYMOUS) { |user| get_auth(post_flags_path, user) }
        end

        context("search parameters") do
          subject { post_flags_path }
          setup do
            PostFlag.delete_all
            @creator = create(:user)
            @janitor = create(:janitor_user)
            @admin = create(:admin_user)
            @post = create(:post, tag_string: "foo")
            @post_flag = create(:post_flag, post: @post, creator: @creator, creator_ip_addr: "127.0.0.2", is_deletion: false, reason_name: "uploading_guidelines", note: "bar", is_resolved: true)
          end

          assert_search_param(:reason_matches, "uploading_guidelines", -> { [@post_flag] })
          assert_search_param(:note_matches, "bar", -> { [@post_flag] }, -> { @janitor })
          assert_search_param(:is_resolved, "true", -> { [@post_flag] })
          assert_search_param(:post_id, -> { @post.id }, -> { [@post_flag] })
          assert_search_param(:post_tags_match, "foo", -> { [@post_flag] })
          assert_search_param(:type, "flag", -> { [@post_flag] })
          assert_search_param(:creator_id, -> { @creator.id }, -> { [@post_flag] }, -> { @creator })
          assert_search_param(:creator_name, -> { @creator.name }, -> { [@post_flag] }, -> { @creator })
          assert_search_param(:ip_addr, "127.0.0.2", -> { [@post_flag] }, -> { @admin })
          assert_shared_search_params(-> { [@post_flag] })
        end
      end

      context("create action") do
        should("create a new flag") do
          post = create(:post)
          assert_difference("PostFlag.count", 1) do
            post_auth(post_flags_path, @user, params: { format: :json, post_flag: { post_id: post.id, reason_name: "dnp_artist" } })
          end
        end

        should("restrict access") do
          assert_access(User::Levels::MEMBER, success_response: :redirect) { |user| post_auth(post_flags_path, user, params: { post_flag: { post_id: create(:post).id, reason_name: "dnp_artist" } }) }
        end
      end
    end
  end
end

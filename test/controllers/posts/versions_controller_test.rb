# frozen_string_literal: true

require("test_helper")

module Posts
  class VersionsControllerTest < ActionDispatch::IntegrationTest
    setup do
      @user = create(:user)
    end

    context("The post versions controller") do
      context("index action") do
        setup do
          @post = create(:post, uploader: @user)
          travel_to(2.hours.from_now) do
            @post.update_with(@user, tag_string: "1 2", source: "https://xxx.com\nhttps://yyy.com", locked_tags: "4 5")
          end
          travel_to(4.hours.from_now) do
            @post.update_with(@user, tag_string: "2 3", rating: "e", source: "https://yyy.com\nhttps://zzz.com", locked_tags: "5 6")
          end
          @versions = @post.versions
          @post2 = create(:post, uploader: @user)
        end

        should("list all versions") do
          get_auth(post_versions_path, @user)

          assert_response(:success)
          assert_select("#post-version-#{@post2.versions[0].id}")
          assert_select("#post-version-#{@versions[0].id}")
          assert_select("#post-version-#{@versions[1].id}")
          assert_select("#post-version-#{@versions[2].id}")
        end

        should("list all versions that match the search criteria") do
          get_auth(post_versions_path, @user, params: { search: { post_id: @post.id } })

          assert_response(:success)
          assert_select("#post-version-#{@post2.versions[0].id}", false)
          assert_select("#post-version-#{@versions[0].id}")
          assert_select("#post-version-#{@versions[1].id}")
          assert_select("#post-version-#{@versions[2].id}")
        end

        context("access control") do
          asserts do
            access.gte(User::Levels::ANONYMOUS).get(post_versions_path)
            access.gte(User::Levels::ANONYMOUS).json.get(post_versions_path)
          end
        end
      end
    end
  end
end

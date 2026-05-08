# frozen_string_literal: true

require("test_helper")

class TagsControllerTest < ActionDispatch::IntegrationTest
  context("The tags controller") do
    setup do
      @user = create(:janitor_user)
      @tag = create(:tag, name: "touhou", category: TagCategory.copyright, post_count: 1)
    end

    context("edit action") do
      should("render") do
        get_auth(tag_path(@tag), @user, params: { id: @tag.id })

        assert_response(:success)
      end

      should("restrict access") do
        assert_access(User::Levels::MEMBER) { |user| get_auth(edit_tag_path(@tag), user) }
      end
    end

    context("index action") do
      should("render") do
        get(tags_path)

        assert_response(:success)
      end

      context("with search parameters") do
        should("render") do
          get(tags_path, params: { search: { name_matches: "touhou" } })

          assert_response(:success)
        end
      end

      context("with blank search parameters") do
        should("strip the blank parameters with a redirect") do
          get(tags_path, params: { search: { name: "touhou", category: "" } })

          assert_redirected_to(tags_path(search: { name: "touhou" }))
        end
      end

      should("restrict access") do
        assert_access(User::Levels::ANONYMOUS) { |user| get_auth(tags_path, user) }
      end

      context("search parameters") do
        subject { tags_path }
        setup do
          TagVersion.delete_all
          Tag.delete_all
          @creator = create(:user)
          @admin = create(:admin_user)
          @general_tag = create(:tag, name: "foo", category: TagCategory.general, post_count: 3, creator: @creator, creator_ip_addr: "127.0.0.2", is_locked: false)
          @artist_tag = create(:tag, name: "bar", category: TagCategory.artist, post_count: 5, creator: @creator, creator_ip_addr: "127.0.0.2", is_locked: true)
          @copyright_tag = create(:tag, name: "baz", category: TagCategory.copyright, post_count: 5, creator: @creator, creator_ip_addr: "127.0.0.2", is_locked: false)
          @wiki = create(:wiki_page, title: "foo")
          @artist = create(:artist, name: "bar")
        end

        assert_search_param(:is_locked, "true", -> { [@artist_tag] })
        assert_search_param(:category, TagCategory.general, -> { [@general_tag] })
        assert_search_param(:category, "#{TagCategory.general},#{TagCategory.artist}", -> { [@artist_tag, @general_tag] })
        assert_search_param(:name, "foo", -> { [@general_tag] })
        assert_search_param(:name_matches, "bar", -> { [@artist_tag] })
        assert_search_param(:fuzzy_name_matches, "ba", -> { [@copyright_tag, @artist_tag] })
        assert_search_param(:has_wiki, "true", -> { [@general_tag] })
        assert_search_param(:has_artist, "true", -> { [@artist_tag] })
        assert_search_param(:creator_id, -> { @creator.id }, -> { [@copyright_tag, @artist_tag, @general_tag] })
        assert_search_param(:creator_name, -> { @creator.name }, -> { [@copyright_tag, @artist_tag, @general_tag] })
        assert_search_param(:ip_addr, "127.0.0.2", -> { [@copyright_tag, @artist_tag, @general_tag] }, -> { @admin })
        assert_shared_search_params(-> { [@copyright_tag, @artist_tag, @general_tag] })
      end
    end

    context("show action") do
      should("render") do
        get(tag_path(@tag))

        assert_response(:success)
      end

      should("restrict access") do
        assert_access(User::Levels::ANONYMOUS) { |user| get_auth(tag_path(@tag), user) }
      end
    end

    context("update action") do
      setup do
        @mod = create(:moderator_user)
      end

      should("update the tag") do
        put_auth(tag_path(@tag), @user, params: { tag: { category: TagCategory.general } })

        assert_redirected_to(tag_path(@tag))
        assert_equal(TagCategory.general, @tag.reload.category)
      end

      should("lock the tag for an admin") do
        put_auth(tag_path(@tag), create(:admin_user), params: { tag: { is_locked: true } })

        assert_redirected_to(@tag)
        assert(@tag.reload.is_locked)
      end

      should("not lock the tag for a user") do
        put_auth(tag_path(@tag), @user, params: { tag: { is_locked: true } })

        assert_not(@tag.reload.is_locked)
      end

      context("for a tag with >1000 posts") do
        setup do
          @tag.update_columns(post_count: 1001)
        end

        should("not update the category for a trusted user") do
          put_auth(tag_path(@tag), create(:trusted_user), params: { tag: { category: TagCategory.general } })

          assert_not_equal(TagCategory.general, @tag.reload.category)
        end

        should("update the category for an admin user") do
          @admin = create(:admin_user)
          put_auth(tag_path(@tag), @admin, params: { tag: { category: TagCategory.general } })

          assert_redirected_to(@tag)
          assert_equal(TagCategory.general, @tag.reload.category)
        end
      end

      context("for a tag with >10000 posts") do
        setup do
          @tag.update_columns(post_count: 10_001)
        end

        should("not update the category for a janitor user") do
          put_auth(tag_path(@tag), @user, params: { tag: { category: TagCategory.general } })

          assert_not_equal(TagCategory.general, @tag.reload.category)
        end

        should("update the category for an admin user") do
          @admin = create(:admin_user)
          put_auth(tag_path(@tag), @admin, params: { tag: { category: TagCategory.general } })

          assert_redirected_to(@tag)
          assert_equal(TagCategory.general, @tag.reload.category)
        end
      end

      should("not change category when the tag is too large to be changed by a janitor") do
        @tag.update_with(@user, category: TagCategory.general, post_count: 10_001)
        put_auth(tag_path(@tag), @user, params: { tag: { category: TagCategory.artist } })

        assert_response(:forbidden)
        assert_equal(TagCategory.general, @tag.reload.category)
      end

      should("restrict access") do
        assert_access(User::Levels::MEMBER, success_response: :redirect) { |user| put_auth(tag_path(@tag), user, params: { tag: { category: TagCategory.general } }) }
      end
    end

    context("follow action") do
      should("work") do
        assert_equal(0, @tag.reload.follower_count)
        put_auth(follow_tag_path(@tag), @user)

        assert_redirected_to(tag_path(@tag))
        assert_equal(1, @tag.reload.follower_count)
        assert(@user.followed_tags.exists?(tag: @tag))
      end

      should("not allow following aliased tags") do
        @tag2 = create(:tag)
        @ta = create(:tag_alias, antecedent_name: @tag.name, consequent_name: @tag2.name)
        with_inline_jobs { @ta.approve!(@user) }
        put_auth(follow_tag_path(@tag), @user, params: { format: :json })

        assert_response(:bad_request)
        assert_equal(0, @tag.reload.follower_count)
        assert_not(@user.followed_tags.exists?(tag: @tag))
        assert_equal("You cannot follow aliased tags.", response.parsed_body["message"])
      end

      should("not allow following more than the user's limit") do
        Config.stubs(:get_user).with(:followed_tag_limit, @user).returns(0)
        put_auth(follow_tag_path(@tag), @user, params: { format: :json })

        assert_response(:unprocessable_entity)
        assert_equal(0, @tag.reload.follower_count)
        assert_not(@user.followed_tags.exists?(tag: @tag))
        assert_equal("cannot follow more than 0 tags", response.parsed_body.dig("errors", "user").first)
      end

      should("restrict access") do
        assert_access(User::Levels::MEMBER, success_response: :redirect) { |user| put_auth(follow_tag_path(@tag), user) }
      end
    end

    context("unfollow action") do
      should("work") do
        @tag.follow!(@user)

        assert_equal(1, @tag.reload.follower_count)
        put_auth(unfollow_tag_path(@tag), @user)

        assert_redirected_to(tag_path(@tag))
        assert_equal(0, @tag.reload.follower_count)
        assert_not(@user.followed_tags.exists?(tag: @tag))
      end

      should("restrict access") do
        assert_access(User::Levels::MEMBER, success_response: :redirect) do |user|
          @tag.follow!(@user)
          put_auth(unfollow_tag_path(@tag), user)
        end
      end
    end

    context("followers action") do
      should("render") do
        create(:tag_follower, tag: @tag, user: @user)
        get_auth(followers_tag_path(@tag), @user)

        assert_response(:success)
      end

      should("restrict access") do
        assert_access(User::Levels::MEMBER) { |user| get_auth(followers_tag_path(@tag), user) }
      end
    end

    context("followed action") do
      should("render") do
        create(:tag_follower, tag: @tag, user: @user)
        get_auth(followed_tags_path, @user)

        assert_response(:success)
      end

      should("render for other users") do
        @user2 = create(:user)
        create(:tag_follower, tag: @tag, user: @user2)
        get_auth(followed_tags_path, @user, params: { user_id: @user2.id })

        assert_response(:success)
      end

      should("not render for other users if privacy mode is enabled") do
        @user2 = create(:user, enable_privacy_mode: true)
        create(:tag_follower, tag: @tag, user: @user2)
        get_auth(followed_tags_path, @user, params: { user_id: @user2.id })

        assert_response(:forbidden)
      end

      should("restrict access") do
        assert_access(User::Levels::MEMBER) { |user| get_auth(followed_tags_path, user, params: { user_id: @user.id }) }
      end
    end

    context("meta_search action") do
      should("work") do
        get(meta_search_tags_path, params: { name: "long_hair" })

        assert_response(:success)
      end

      should("restrict access") do
        assert_access(User::Levels::ANONYMOUS) { |user| get_auth(meta_search_tags_path, user, params: { name: "long_hair" }) }
      end
    end
  end
end

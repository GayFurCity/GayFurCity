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

      context("access control") do
        asserts do
          access.gte(User::Levels::MEMBER).get { edit_tag_path(@tag) }
        end
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

      context("access control") do
        asserts do
          access.gte(User::Levels::ANONYMOUS).get(tags_path)
          access.gte(User::Levels::ANONYMOUS).json.get(tags_path)
        end
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

        asserts do
          search(:is_locked, "true").records { [@artist_tag] }
          search(:category, TagCategory.general).records { [@general_tag] }
          search(:category, "#{TagCategory.general},#{TagCategory.artist}").records { [@artist_tag, @general_tag] }
          search(:name, "foo").records { [@general_tag] }
          search(:name_matches, "bar").records { [@artist_tag] }
          search(:fuzzy_name_matches, "ba").records { [@copyright_tag, @artist_tag] }
          search(:has_wiki, "true").records { [@general_tag] }
          search(:has_artist, "true").records { [@artist_tag] }
          search(:creator_id).value { @creator.id }.records { [@copyright_tag, @artist_tag, @general_tag] }
          search(:creator_name).value { @creator.name }.records { [@copyright_tag, @artist_tag, @general_tag] }
          search(:ip_addr, "127.0.0.2").records { [@copyright_tag, @artist_tag, @general_tag] }.user { @admin }
          search.shared.records { [@copyright_tag, @artist_tag, @general_tag] }
        end
      end
    end

    context("show action") do
      should("render") do
        get(tag_path(@tag))

        assert_response(:success)
      end

      context("access control") do
        asserts do
          access.gte(User::Levels::ANONYMOUS).get { tag_path(@tag) }
          access.gte(User::Levels::ANONYMOUS).json.get { tag_path(@tag) }
        end
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

      context("access control") do
        asserts do
          access.gte(User::Levels::MEMBER).put { tag_path(@tag) }.params({ tag: { category: TagCategory.general } }).success(:redirect)
          access.gte(User::Levels::MEMBER).json.put { tag_path(@tag) }.params({ tag: { category: TagCategory.general } })
        end
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
        stub_config_get_user(:followed_tag_limit, 0)
        put_auth(follow_tag_path(@tag), @user, params: { format: :json })

        assert_response(:unprocessable_entity)
        assert_equal(0, @tag.reload.follower_count)
        assert_not(@user.followed_tags.exists?(tag: @tag))
        assert_equal("cannot follow more than 0 tags", response.parsed_body.dig("errors", "user").first)
      end

      context("access control") do
        asserts do
          access.gte(User::Levels::MEMBER).put { follow_tag_path(@tag) }.success(:redirect)
          access.gte(User::Levels::MEMBER).json.put { follow_tag_path(@tag) }
        end
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

      context("access control") do
        asserts do
          access do |builder|
            builder.gte(User::Levels::MEMBER).success(:redirect).put do |user|
              @tag.follow!(user)
              unfollow_tag_path(@tag)
            end
          end
          access do |builder|
            builder.gte(User::Levels::MEMBER).json.put do |user|
              @tag.follow!(user)
              unfollow_tag_path(@tag)
            end
          end
        end
      end
    end

    context("followers action") do
      should("render") do
        create(:tag_follower, tag: @tag, user: @user)
        get_auth(followers_tag_path(@tag), @user)

        assert_response(:success)
      end

      context("access control") do
        asserts do
          access.gte(User::Levels::MEMBER).get { followers_tag_path(@tag) }
          access.gte(User::Levels::MEMBER).json.get { followers_tag_path(@tag) }
        end
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

      context("access control") do
        asserts do
          access.gte(User::Levels::MEMBER).get(followed_tags_path).params { |user| { user_id: user.id } }
          access.gte(User::Levels::MEMBER).json.get(followed_tags_path).params { |user| { user_id: user.id } }
        end
      end
    end

    context("meta_search action") do
      should("work") do
        get(meta_search_tags_path, params: { name: "long_hair" })

        assert_response(:success)
      end

      context("access control") do
        asserts do
          access.gte(User::Levels::ANONYMOUS).get(meta_search_tags_path).params({ name: "long_hair" })
          access.gte(User::Levels::ANONYMOUS).json.get(meta_search_tags_path).params({ name: "long_hair" })
        end
      end
    end
  end
end

# frozen_string_literal: true

require("test_helper")

class PostSetsControllerTest < ActionDispatch::IntegrationTest
  context("The post sets controller") do
    setup do
      @user = create(:user, created_at: 1.month.ago)
      @admin = create(:admin_user)
      @post = create(:post)
      @set = create(:post_set, creator: @user)
      @set.update_with!(@user, is_public: true)
    end

    context("index action") do
      should("list all visible post sets") do
        get(post_sets_path)

        assert_response(:success)
      end

      should("list all visible post sets (with search)") do
        get(post_sets_path, params: { search: { name: @set.name } })

        assert_response(:success)
      end

      should("not include private sets belonging to other users") do
        private_set = create(:post_set, creator: create(:user))

        get(post_sets_path, as: :json)

        assert_response(:success)
        assert_not_includes(response.parsed_body.pluck("id"), private_set.id)
      end

      context("access control") do
        asserts do
          access.gte(User::Levels::ANONYMOUS).get(post_sets_path)
          access.gte(User::Levels::ANONYMOUS).json.get(post_sets_path)
        end
      end

      context("search parameters") do
        subject { post_sets_path }
        setup do
          PostSetMaintainer.delete_all
          PostSet.delete_all
          @creator = create(:user, created_at: 1.month.ago)
          @admin = create(:admin_user)
          @maintainer = create(:user)
          @searched_post = create(:post)
          @search_set = create(:post_set, creator: @creator, creator_ip_addr: "127.0.0.2", name: "search_set_foo", shortname: "search_set_bar", post_ids: [@searched_post.id])
          @search_set.update_with!(@creator, is_public: true)
          PostSetMaintainer.create!(post_set: @search_set, user: @maintainer, status: "approved")
        end

        asserts do
          search(:name, "search_set_foo").records { [@search_set] }
          search(:shortname, "search_set_bar").records { [@search_set] }
          search(:is_public, "true").records { [@search_set] }.user { @admin }
          search(:creator_id).value { @creator.id }.records { [@search_set] }
          search(:creator_name).value { @creator.name }.records { [@search_set] }
          search(:post_id).value { @searched_post.id }.records { [@search_set] }
          search(:maintainer_id).value { @maintainer.id }.records { [@search_set] }
          search.shared.records { [@search_set] }
        end
      end
    end

    context("show action") do
      should("render for a public set") do
        get(post_set_path(@set))

        assert_response(:success)
      end

      should("render for the owner of a private set") do
        private_set = create(:post_set, creator: @user)
        get_auth(post_set_path(private_set), @user)

        assert_response(:success)
      end

      should("not be visible to other users when private") do
        private_set = create(:post_set, creator: @user)
        get_auth(post_set_path(private_set), create(:user), params: { format: :json })

        assert_response(:forbidden)
      end

      context("access control") do
        asserts do
          access.gte(User::Levels::ANONYMOUS).get { post_set_path(@set) }
          access.gte(User::Levels::ANONYMOUS).json.get { post_set_path(@set) }
        end
      end
    end

    context("new action") do
      should("render") do
        get_auth(new_post_set_path, @user)

        assert_response(:success)
      end

      context("access control") do
        asserts do
          access.gte(User::Levels::REJECTED).get(new_post_set_path)
        end
      end
    end

    context("create action") do
      should("create a post set") do
        assert_difference("PostSet.count", 1) do
          post_auth(post_sets_path, @user, params: { post_set: { name: "xxx", shortname: "xxx" } })
        end
      end

      should("not allow duplicate shortnames") do
        post_auth(post_sets_path, @user, params: { post_set: { name: "yyy", shortname: @set.shortname }, format: :json })

        assert_response(:unprocessable_entity)
      end

      context("access control") do
        asserts do
          access.gte(User::Levels::REJECTED).post(post_sets_path).params do
            { post_set: { name: "set_#{SecureRandom.hex(6)}", shortname: "set_#{SecureRandom.hex(6)}" } }
          end.success(:redirect)
          access.gte(User::Levels::REJECTED).json.post(post_sets_path).params do
            { post_set: { name: "set_#{SecureRandom.hex(6)}", shortname: "set_#{SecureRandom.hex(6)}" } }
          end
        end
      end
    end

    context("edit action") do
      should("render for the owner") do
        get_auth(edit_post_set_path(@set), @user)

        assert_response(:success)
      end

      context("access control") do
        asserts do
          access.gte(User::Levels::REJECTED).get do |user|
            set = create(:post_set)
            set.update_columns(creator_id: user.id)
            edit_post_set_path(set)
          end
        end
      end

      context("access control (not owner)") do
        asserts do
          access.gte(User::Levels::ADMIN).get { edit_post_set_path(@set) }
        end
      end
    end

    context("update action") do
      should("update a post set") do
        put_auth(post_set_path(@set), @user, params: { post_set: { name: "xyz" } })

        assert_equal("xyz", @set.reload.name)
      end

      should("not allow updating unpermitted attributes") do
        put_auth(post_set_path(@set), @user, params: { post_set: { post_count: 42 } })

        assert_equal(0, @set.reload.post_count)
      end

      should("not allow other users to update it") do
        put_auth(post_set_path(@set), create(:user), params: { post_set: { name: "xyz" }, format: :json })

        assert_response(:forbidden)
        assert_not_equal("xyz", @set.reload.name)
      end

      context("access control") do
        asserts do
          access.gte(User::Levels::REJECTED).put do |user|
            set = create(:post_set)
            set.update_columns(creator_id: user.id)
            post_set_path(set)
          end.params({ post_set: { name: "foobar" } }).success(:redirect)
          access.gte(User::Levels::REJECTED).json.put do |user|
            set = create(:post_set)
            set.update_columns(creator_id: user.id)
            post_set_path(set)
          end.params({ post_set: { name: "foobar" } })
        end
      end

      context("access control (not owner)") do
        asserts do
          access.gte(User::Levels::ADMIN).put { post_set_path(@set) }.params({ post_set: { name: "foobar" } }).success(:redirect)
          access.gte(User::Levels::ADMIN).json.put { post_set_path(@set) }.params({ post_set: { name: "foobar" } })
        end
      end
    end

    context("destroy action") do
      should("allow the owner to destroy their set") do
        delete_auth(post_set_path(@set), @user)

        assert_raises(ActiveRecord::RecordNotFound) { @set.reload }
      end

      should("not allow other users to destroy it") do
        delete_auth(post_set_path(@set), create(:user), params: { format: :json })

        assert_response(:forbidden)
        assert(PostSet.exists?(@set.id))
      end

      context("access control") do
        asserts do
          access.gte(User::Levels::REJECTED).delete do |user|
            set = create(:post_set)
            set.update_columns(creator_id: user.id)
            post_set_path(set)
          end
          access.gte(User::Levels::REJECTED).json.delete do |user|
            set = create(:post_set)
            set.update_columns(creator_id: user.id)
            post_set_path(set)
          end.success(:no_content)
        end
      end

      context("access control (not owner)") do
        asserts do
          access.gte(User::Levels::ADMIN).delete { post_set_path(@set) }
          access.gte(User::Levels::ADMIN).json.delete { post_set_path(@set) }.success(:no_content)
        end
      end
    end

    context("maintainers action") do
      should("render") do
        get_auth(maintainers_post_set_path(@set), @user)

        assert_response(:success)
      end

      context("access control") do
        asserts do
          access.gte(User::Levels::REJECTED).get { maintainers_post_set_path(@set) }
        end
      end
    end

    context("post_list action") do
      should("render for the owner") do
        get_auth(post_list_post_set_path(@set), @user)

        assert_response(:success)
      end

      context("access control") do
        asserts do
          access.gte(User::Levels::REJECTED).get do |user|
            set = create(:post_set)
            set.update_columns(creator_id: user.id)
            post_list_post_set_path(set)
          end
        end
      end

      context("access control (not owner)") do
        asserts do
          access.gte(User::Levels::ADMIN).get { post_list_post_set_path(@set) }
        end
      end
    end

    context("update_posts action") do
      should("update the set's posts") do
        post_auth(update_posts_post_set_path(@set), @user, params: { post_ids_string: @post.id.to_s })

        assert_equal([@post.id], @set.reload.post_ids)
      end

      context("access control") do
        asserts do
          access.gte(User::Levels::REJECTED).post do |user|
            set = create(:post_set)
            set.update_columns(creator_id: user.id)
            update_posts_post_set_path(set)
          end.params({ post_ids_string: "" }).success(:redirect)
          access.gte(User::Levels::REJECTED).json.post do |user|
            set = create(:post_set)
            set.update_columns(creator_id: user.id)
            update_posts_post_set_path(set)
          end.params({ post_ids_string: "" })
        end
      end

      context("access control (not owner)") do
        asserts do
          access.gte(User::Levels::ADMIN).post { update_posts_post_set_path(@set) }.params({ post_ids_string: "" }).success(:redirect)
          access.gte(User::Levels::ADMIN).json.post { update_posts_post_set_path(@set) }.params({ post_ids_string: "" })
        end
      end
    end

    context("add_posts action") do
      should("add posts to the set") do
        post_auth(add_posts_post_set_path(@set), @user, params: { post_ids: [@post.id] })

        assert_equal([@post.id], @set.reload.post_ids)
      end

      should("not allow other users to add posts") do
        post_auth(add_posts_post_set_path(@set), create(:user), params: { post_ids: [@post.id], format: :json })

        assert_response(:forbidden)
        assert_equal([], @set.reload.post_ids)
      end

      context("access control") do
        asserts do
          access.gte(User::Levels::REJECTED).post do |user|
            set = create(:post_set)
            set.update_columns(creator_id: user.id)
            add_posts_post_set_path(set)
          end.params({ post_ids: [] }).success(:redirect)
          access.gte(User::Levels::REJECTED).json.post do |user|
            set = create(:post_set)
            set.update_columns(creator_id: user.id)
            add_posts_post_set_path(set)
          end.params({ post_ids: [] })
        end
      end

      context("access control (not owner)") do
        asserts do
          access.gte(User::Levels::ADMIN).post { add_posts_post_set_path(@set) }.params({ post_ids: [] }).success(:redirect)
          access.gte(User::Levels::ADMIN).json.post { add_posts_post_set_path(@set) }.params({ post_ids: [] })
        end
      end
    end

    context("remove_posts action") do
      setup { @set.add!(@post, @user) }

      should("remove posts from the set") do
        post_auth(remove_posts_post_set_path(@set), @user, params: { post_ids: [@post.id] })

        assert_equal([], @set.reload.post_ids)
      end

      context("access control") do
        asserts do
          access.gte(User::Levels::REJECTED).post do |user|
            set = create(:post_set)
            set.update_columns(creator_id: user.id)
            remove_posts_post_set_path(set)
          end.params({ post_ids: [] }).success(:redirect)
          access.gte(User::Levels::REJECTED).json.post do |user|
            set = create(:post_set)
            set.update_columns(creator_id: user.id)
            remove_posts_post_set_path(set)
          end.params({ post_ids: [] })
        end
      end

      context("access control (not owner)") do
        asserts do
          access.gte(User::Levels::ADMIN).post { remove_posts_post_set_path(@set) }.params({ post_ids: [] }).success(:redirect)
          access.gte(User::Levels::ADMIN).json.post { remove_posts_post_set_path(@set) }.params({ post_ids: [] })
        end
      end
    end

    context("for_select action") do
      should("group owned and maintained sets") do
        maintained = create(:post_set, creator: create(:user, created_at: 1.month.ago))
        maintained.update_with!(maintained.creator, is_public: true)
        PostSetMaintainer.create!(post_set: maintained, user: @user, status: "approved")

        get_auth(for_select_post_sets_path, @user)

        assert_response(:success)
        body = response.parsed_body

        assert_equal([[@set.name.tr("_", " "), @set.id]], body["Owned"])
        assert_equal([[maintained.name.tr("_", " "), maintained.id]], body["Maintained"])
      end

      context("access control") do
        asserts do
          access.gte(User::Levels::REJECTED).get(for_select_post_sets_path)
          access.gte(User::Levels::REJECTED).json.get(for_select_post_sets_path)
        end
      end
    end

    context("when post sets are disabled") do
      setup { Security::Lockdown.post_sets_disabled = true }
      teardown { Security::Lockdown.post_sets_disabled = false }

      should("prevent creating post sets") do
        post_auth(post_sets_path, @user, params: { post_set: { name: "xxx", shortname: "yyy" } })

        assert_response(:forbidden)
      end

      should("still allow viewing the index") do
        get(post_sets_path)

        assert_response(:success)
      end

      should("still allow viewing a set") do
        get(post_set_path(@set))

        assert_response(:success)
      end
    end
  end
end

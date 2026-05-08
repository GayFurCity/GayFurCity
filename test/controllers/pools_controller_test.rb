# frozen_string_literal: true

require("test_helper")

class PoolsControllerTest < ActionDispatch::IntegrationTest
  context("The pools controller") do
    setup do
      @user = create(:user)
      @mod = create(:moderator_user)
      @post = create(:post)
      @pool = create(:pool)
    end

    context("index action") do
      should("list all pools") do
        get(pools_path)

        assert_response(:success)
      end

      should("list all pools (with search)") do
        get(pools_path, params: { search: { name_matches: @pool.name } })

        assert_response(:success)
      end

      should("restrict access") do
        assert_access(User::Levels::ANONYMOUS) { |user| get_auth(pools_path, user) }
      end

      context("search parameters") do
        subject { pools_path }
        setup do
          PoolVersion.delete_all
          Pool.delete_all
          @creator = create(:user)
          @admin = create(:admin_user)
          @wiki = create(:wiki_page, title: "bar")
          @post = create(:post, tag_string: "artist:baz")
          @pool = create(:pool, creator: @creator, creator_ip_addr: "127.0.0.2", name: "foo", description: "[[bar]] qux", category: "series", is_ongoing: true, post_ids: [@post.id])
        end

        assert_search_param(:is_ongoing, "true", -> { [@pool] })
        assert_search_param(:category, "series", -> { [@pool] })
        assert_search_param(:name_matches, "foo", -> { [@pool] })
        assert_search_param(:description_matches, "qux", -> { [@pool] })
        assert_search_param(:any_artist_name_matches, "baz", -> { [@pool] })
        assert_search_param(:any_artist_name_like, "baz", -> { [@pool] })
        assert_search_param(:linked_to, "bar", -> { [@pool] })
        assert_search_param(:not_linked_to, "baz", -> { [@pool] })
        assert_search_param(:creator_id, -> { @creator.id }, -> { [@pool] })
        assert_search_param(:creator_name, -> { @creator.name }, -> { [@pool] })
        assert_search_param(:ip_addr, "127.0.0.2", -> { [@pool] }, -> { @admin })
        assert_shared_search_params(-> { [@pool] })
      end
    end

    context("show action") do
      should("render") do
        get(pool_path(@pool))

        assert_response(:success)
      end

      should("restrict access") do
        assert_access(User::Levels::ANONYMOUS) { |user| get_auth(pool_path(@pool), user) }
      end
    end

    context("gallery action") do
      should("render") do
        get(gallery_pools_path)

        assert_response(:success)
      end

      should("restrict access") do
        assert_access(User::Levels::ANONYMOUS) { |user| get_auth(gallery_pools_path, user) }
      end
    end

    context("new action") do
      should("render") do
        get_auth(new_pool_path, @user)

        assert_response(:success)
      end

      should("restrict access") do
        assert_access(User::Levels::MEMBER) { |user| get_auth(new_pool_path, user) }
      end
    end

    context("create action") do
      should("create a pool") do
        assert_difference("Pool.count", 1) do
          post_auth(pools_path, @user, params: { pool: { name: "xxx", description: "abc" } })
        end
      end

      context("min_edit_level") do
        setup do
          @post2 = create(:post, min_edit_level: User::Levels::TRUSTED)
        end

        should("prevent adding posts when the editors level is lower") do
          post_auth(pools_path, @user, params: { pool: { name: "xxx", description: "abc", post_ids: [@post.id, @post2.id] }, format: :json })

          assert_response(:unprocessable_entity)
        end

        should("allow adding posts when the editors level is higher") do
          post_auth(pools_path, @mod, params: { pool: { name: "xxx", description: "abc", post_ids: [@post.id, @post2.id] }, format: :json })

          assert_response(:success)
        end
      end

      should("restrict access") do
        assert_access(User::Levels::MEMBER, success_response: :redirect) { |user| post_auth(pools_path, user, params: { pool: { name: SecureRandom.hex(6) } }) }
      end
    end

    context("edit action") do
      should("render") do
        get_auth(edit_pool_path(@pool), @user)

        assert_response(:success)
      end

      should("restrict access") do
        assert_access(User::Levels::MEMBER) { |user| get_auth(edit_pool_path(@pool), user) }
      end
    end

    context("update action") do
      should("update a pool") do
        put_auth(pool_path(@pool), @user, params: { pool: { name: "xyz", post_ids: [@post.id] } })

        assert_equal("xyz", @pool.reload.name)
        assert_equal([@post.id], @pool.post_ids)
      end

      should("not allow updating unpermitted attributes") do
        put_auth(pool_path(@pool), @user, params: { pool: { post_count: -42 } })

        assert_equal(0, @pool.post_count)
      end

      context("min_edit_level") do
        setup do
          @post2 = create(:post, min_edit_level: User::Levels::TRUSTED)
          @post3 = create(:post)
          @pool.add!(@post3, @user)
          @post3.update_column(:min_edit_level, User::Levels::TRUSTED)
        end

        should("prevent adding posts when the editors level is lower") do
          put_auth(pool_path(@pool), @user, params: { pool: { name: "xyz", post_ids: [@post2.id] }, format: :json })

          assert_response(:unprocessable_entity)
        end

        should("allow adding posts when the editors level is higher") do
          put_auth(pool_path(@pool), @mod, params: { pool: { name: "xyz", post_ids: [@post2.id] }, format: :json })

          assert_response(:success)
        end

        should("prevent removing posts when the editors level is lower") do
          put_auth(pool_path(@pool), @user, params: { pool: { name: "xyz", post_ids: [@post.id] }, format: :json })

          assert_response(:unprocessable_entity)
        end

        should("allow removing posts when the editors level is higher") do
          put_auth(pool_path(@pool), @mod, params: { pool: { name: "xyz", post_ids: [@post.id] }, format: :json })

          assert_response(:success)
        end
      end

      should("restrict access") do
        assert_access(User::Levels::MEMBER) { |user| get_auth(new_pool_path, user) }
      end
    end

    context("destroy action") do
      should("destroy a pool") do
        delete_auth(pool_path(@pool), @mod)
        assert_raises(ActiveRecord::RecordNotFound) do
          @pool.reload
        end
      end

      should("restrict access") do
        assert_access(User::Levels::JANITOR, success_response: :redirect) { |user| delete_auth(pool_path(create(:pool)), user) }
      end
    end

    context("revert action") do
      setup do
        @post2 = create(:post)
        @pool = create(:pool, post_ids: [@post.id])
        @pool.update_with(@user, post_ids: [@post.id, @post2.id])
      end

      should("revert to a previous version") do
        @pool.reload
        version = @pool.versions.first

        assert_equal([@post.id], version.post_ids)
        put_auth(revert_pool_path(@pool), @mod, params: { version_id: version.id })
        @pool.reload

        assert_equal([@post.id], @pool.post_ids)
      end

      should("not allow reverting to a previous version of another pool") do
        @pool2 = create(:pool)
        put_auth(revert_pool_path(@pool), @user, params: { version_id: @pool2.versions.first.id })
        @pool.reload

        assert_not_equal(@pool.name, @pool2.name)
        assert_response(:missing)
      end

      should("restrict access") do
        User::Levels.constants.length.times { |i| @pool.update_with(@user, name: "pool_#{i}") }
        @versions = @pool.reload.versions.to_a
        assert_access(User::Levels::MEMBER, success_response: :redirect) { |user| put_auth(revert_pool_path(@pool), user, params: { version_id: @versions.pop.id }) }
      end
    end

    context("order action") do
      should("render") do
        get_auth(edit_pool_order_path(@pool), @user)

        assert_response(:success)
      end

      should("restrict access") do
        assert_access(User::Levels::MEMBER) { |user| get_auth(edit_pool_order_path(@pool), user) }
      end
    end
  end
end

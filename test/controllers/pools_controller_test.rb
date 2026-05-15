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

      context("access control") do
        asserts do
          access.gte(User::Levels::ANONYMOUS).get(pools_path)
          access.gte(User::Levels::ANONYMOUS).json.get(pools_path)
        end
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

        asserts do
          search(:is_ongoing, "true").records { [@pool] }
          search(:category, "series").records { [@pool] }
          search(:name_matches, "foo").records { [@pool] }
          search(:description_matches, "qux").records { [@pool] }
          search(:any_artist_name_matches, "baz").records { [@pool] }
          search(:any_artist_name_like, "baz").records { [@pool] }
          search(:linked_to, "bar").records { [@pool] }
          search(:not_linked_to, "baz").records { [@pool] }
          search(:creator_id).value { @creator.id }.records { [@pool] }
          search(:creator_name).value { @creator.name }.records { [@pool] }
          search(:ip_addr, "127.0.0.2").records { [@pool] }.user { @admin }
          search.shared.records { [@pool] }
        end
      end
    end

    context("show action") do
      should("render") do
        get(pool_path(@pool))

        assert_response(:success)
      end

      context("access control") do
        asserts do
          access.gte(User::Levels::ANONYMOUS).get { pool_path(@pool) }
          access.gte(User::Levels::ANONYMOUS).json.get { pool_path(@pool) }
        end
      end
    end

    context("gallery action") do
      should("render") do
        get(gallery_pools_path)

        assert_response(:success)
      end

      context("access control") do
        asserts do
          access.gte(User::Levels::ANONYMOUS).get(gallery_pools_path)
        end
      end
    end

    context("new action") do
      should("render") do
        get_auth(new_pool_path, @user)

        assert_response(:success)
      end

      context("access control") do
        asserts do
          access.gte(User::Levels::MEMBER).get(new_pool_path)
        end
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

      context("access control") do
        asserts do
          access.gte(User::Levels::MEMBER).post(pools_path).params { { pool: { name: SecureRandom.hex(6) } } }.success(:redirect)
          access.gte(User::Levels::MEMBER).json.post(pools_path).params { { pool: { name: SecureRandom.hex(6) } } }
        end
      end
    end

    context("edit action") do
      should("render") do
        get_auth(edit_pool_path(@pool), @user)

        assert_response(:success)
      end

      context("access control") do
        asserts do
          access.gte(User::Levels::MEMBER).get { edit_pool_path(@pool) }
        end
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

      context("access control") do
        asserts do
          access.gte(User::Levels::MEMBER).put { pool_path(@pool) }.params({ pool: { name: "foobar" } }).success(:redirect)
          access.gte(User::Levels::MEMBER).json.put { pool_path(@pool) }.params({ pool: { name: "foobar" } })
        end
      end
    end

    context("destroy action") do
      should("destroy a pool") do
        delete_auth(pool_path(@pool), @mod)
        assert_raises(ActiveRecord::RecordNotFound) do
          @pool.reload
        end
      end

      context("access control") do
        asserts do
          access.gte(User::Levels::JANITOR).delete { pool_path(@pool) }.success(:redirect)
          access.gte(User::Levels::JANITOR).json.delete { pool_path(@pool) }.success(:no_content)
        end
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

      context("access control") do
        setup { @pool.update(name: "pool_foobar") }

        asserts do
          access.gte(User::Levels::MEMBER).put { revert_pool_path(@pool) }.params { { version_id: @pool.versions.last.id } }.success(:redirect)
          access.gte(User::Levels::MEMBER).json.put { revert_pool_path(@pool) }.params { { version_id: @pool.versions.last.id } }
        end
      end
    end

    context("order action") do
      should("render") do
        get_auth(edit_pool_order_path(@pool), @user)

        assert_response(:success)
      end

      context("access control") do
        asserts do
          access.gte(User::Levels::MEMBER).get { edit_pool_order_path(@pool) }
        end
      end
    end
  end
end

# frozen_string_literal: true

require("test_helper")

class PoolTest < ActiveSupport::TestCase
  context("A pool") do
    setup do
      @user = create(:user, created_at: 1.month.ago)
    end

    context("A name") do
      setup do
        @pool = create(:pool, name: "xxx")
      end

      should("be mapped to a pool id") do
        assert_equal(@pool.id, Pool.name_to_id("xxx"))
      end
    end

    context("A multibyte character name") do
      setup do
        @mb_pool = create(:pool, name: "àáâãäå")
      end

      should("be mapped to a pool id") do
        assert_equal(@mb_pool.id, Pool.name_to_id("àáâãäå"))
      end
    end

    context("An id number") do
      setup do
        @pool = create(:pool)
      end

      should("be mapped to a pool id") do
        assert_equal(@pool.id, Pool.name_to_id(@pool.id.to_s))
      end
    end

    context("Creating a pool") do
      setup do
        @posts = create_list(:post, 5)
        @pool = create(:pool, post_ids: @posts.map(&:id))
      end

      should("initialize the post count") do
        assert_equal(@posts.size, @pool.post_count)
      end

      should("synchronize the posts with the pool") do
        assert_equal(@posts.map(&:id), @pool.post_ids)

        @posts.each(&:reload)

        assert_equal(["pool:#{@pool.id}"] * @posts.size, @posts.map(&:pool_string))
      end

      should("remove invalid post ids") do
        invalid = Post.maximum(:id) + 1
        @pool = create(:pool, post_ids: @posts.map(&:id) + [invalid])

        assert_equal(@posts.size, @pool.post_count)
        assert_equal(@posts.map(&:id), @pool.post_ids)
      end
    end

    context("Reverting a pool") do
      setup do
        @pool = create(:pool)
        @p1 = create(:post)
        @p2 = create(:post)
        @p3 = create(:post)
        @pool.add!(@p1, @user.resolvable("1.2.3.4"))
        @pool.reload

        @pool.add!(@p2, @user.resolvable("1.2.3.5"))
        @pool.reload

        @pool.add!(@p3, @user.resolvable("1.2.3.6"))
        @pool.reload

        @pool.remove!(@p1, @user.resolvable("1.2.3.7"))
        @pool.reload

        version = @pool.versions[1]
        @pool.revert_to!(version, @user.resolvable("1.2.3.8"))
        @pool.reload
      end

      should("have the correct versions") do
        assert_equal(6, @pool.versions.size)
        assert_equal([], @pool.versions.all[0].post_ids)
        assert_equal([@p1.id], @pool.versions.all[1].post_ids)
        assert_equal([@p1.id, @p2.id], @pool.versions.all[2].post_ids)
        assert_equal([@p1.id, @p2.id, @p3.id], @pool.versions.all[3].post_ids)
        assert_equal([@p2.id, @p3.id], @pool.versions.all[4].post_ids)
      end

      should("update its post_ids") do
        assert_equal([@p1.id], @pool.post_ids)
      end

      should("update any old posts that were removed") do
        @p2.reload

        assert_equal("", @p2.pool_string)
      end

      should("update any new posts that were added") do
        @p1.reload

        assert_equal("pool:#{@pool.id}", @p1.pool_string)
      end
    end

    context("Updating a pool") do
      setup do
        @pool = create(:pool, category: "series")
        @p1 = create(:post)
        @p2 = create(:post)
      end

      context("by adding a new post") do
        setup do
          @pool.add!(@p1, @user)
        end

        context("by #attributes=") do
          setup do
            @pool.attributes = { post_ids: [@p1.id, @p2.id] }
            @pool.updater = @user
            @pool.synchronize
            @pool.save
          end

          should("initialize the post count") do
            assert_equal(2, @pool.post_count)
          end
        end

        should("add the post to the pool") do
          assert_equal([@p1.id], @pool.post_ids)
        end

        should("add the pool to the post") do
          assert_equal("pool:#{@pool.id}", @p1.pool_string)
        end

        should("increment the post count") do
          assert_equal(1, @pool.post_count)
        end

        should("not allow adding invalid posts") do
          invalid = Post.maximum(:id) + 1
          @pool.post_ids << invalid
          @pool.updater = @user
          @pool.save

          assert_equal(1, @pool.post_count)
          assert_equal([@p1.id], @pool.post_ids)
        end

        context("to a pool that already has the post") do
          setup do
            @pool.add!(@p1, @user)
          end

          should("not double add the post to the pool") do
            assert_equal([@p1.id], @pool.post_ids)
          end

          should("not double add the pool to the post") do
            assert_equal("pool:#{@pool.id}", @p1.pool_string)
          end

          should("not double increment the post count") do
            assert_equal(1, @pool.post_count)
          end
        end
      end

      context("by removing a post") do
        setup do
          @pool.add!(@p1, @user)
        end

        context("that is in the pool") do
          setup do
            @pool.remove!(@p1, @user)
          end

          should("remove the post from the pool") do
            assert_equal([], @pool.post_ids)
          end

          should("remove the pool from the post") do
            assert_equal("", @p1.pool_string)
          end

          should("update the post count") do
            assert_equal(0, @pool.post_count)
          end
        end

        context("that is not in the pool") do
          setup do
            @pool.remove!(@p2, @user)
          end

          should("not affect the pool") do
            assert_equal([@p1.id], @pool.post_ids)
          end

          should("not affect the post") do
            assert_equal("pool:#{@pool.id}", @p1.pool_string)
          end

          should("not affect the post count") do
            assert_equal(1, @pool.post_count)
          end
        end
      end

      context("by changing the category") do
        setup do
          Config.any_instance.stubs(:pool_category_change_cutoff).returns(1)
          @pool.add!(@p1, @user)
          @pool.add!(@p2, @user)
        end

        should("not allow members to change the category of large pools") do
          @pool.update_with(@user, category: "collection")

          assert_equal(["You cannot change the category of pools with more than 1 posts"], @pool.errors[:base])
          assert_equal("series", @pool.reload.category)
        end

        should("allow janitors to changer the category of large pools") do
          @janitor = create(:janitor_user)
          @pool.update_with(@janitor, category: "collection")

          assert_predicate(@pool.errors, :none?)
          assert_equal("collection", @pool.reload.category)
        end
      end

      should("create new versions for each distinct user") do
        assert_equal(1, @pool.versions.size)
        user2 = create(:user, created_at: 1.month.ago)

        @pool.post_ids = [@p1.id]
        @pool.updater = user2.resolvable("127.0.0.2")
        @pool.save

        @pool.reload

        assert_equal(2, @pool.versions.size)
        assert_equal(user2.id, @pool.versions.last.updater_id)
        assert_equal("127.0.0.2", @pool.versions.last.updater_ip_addr.to_s)

        @pool.post_ids = [@p1.id, @p2.id]
        @pool.updater = user2.resolvable("127.0.0.3")
        @pool.save

        @pool.reload

        assert_equal(3, @pool.versions.size)
        assert_equal(user2.id, @pool.versions.last.updater_id)
        assert_equal("127.0.0.3", @pool.versions.last.updater_ip_addr.to_s)
      end

      should("should create a version if the name changes") do
        assert_difference("@pool.versions.size", 1) do
          @pool.update(name: "blah")

          assert_equal("blah", @pool.versions.last.name)
        end
        assert_equal(2, @pool.versions.size)
      end

      should("know what its post ids were previously") do
        @pool.post_ids = [@p1.id]

        assert_equal([], @pool.post_ids_was)
      end

      should("normalize its name") do
        @pool.update_with(@user, name: "  A  B  ")

        assert_equal("A_B", @pool.name)

        @pool.update_with(@user, name: "__A__B__")

        assert_equal("A_B", @pool.name)
      end

      should("normalize its post ids") do
        @pool.update_with(@user, post_ids: [@p1.id, @p2.id, @p1.id])

        assert_equal([@p1.id, @p2.id], @pool.post_ids)
      end

      context("when validating names") do
        setup do
          Pool.any_instance.stubs(:creator).returns(@user)
        end

        ["foo,bar", "foo*bar", "123", "--", "___", "   ", "any", "none", "series", "collection"].each do |bad_name|
          should_not(allow_value(bad_name).for(:name))
        end

        ["_-_", " - "].each do |good_name|
          should(allow_value(good_name).for(:name))
        end
      end
    end

    context("An existing pool") do
      setup do
        @pool = create(:pool)
        @p1 = create(:post)
        @p2 = create(:post)
        @p3 = create(:post)
        @pool.add!(@p1, @user)
        @pool.add!(@p2, @user)
        @pool.add!(@p3, @user)
      end

      context("that is synchronized") do
        setup do
          @pool.reload
          @pool.post_ids = [@p2.id]
          @pool.updater = @user
          @pool.synchronize!
        end

        should("update the pool") do
          @pool.reload

          assert_equal(1, @pool.post_count)
          assert_equal([@p2.id], @pool.post_ids)
        end

        should("update the posts") do
          @p1.reload
          @p2.reload
          @p3.reload

          assert_equal("", @p1.pool_string)
          assert_equal("pool:#{@pool.id}", @p2.pool_string)
          assert_equal("", @p3.pool_string)
        end
      end

      should("find the neighbors for the first post") do
        assert_nil(@pool.previous_post_id(@p1.id))
        assert_equal(@p2.id, @pool.next_post_id(@p1.id))
      end

      should("find the neighbors for the middle post") do
        assert_equal(@p1.id, @pool.previous_post_id(@p2.id))
        assert_equal(@p3.id, @pool.next_post_id(@p2.id))
      end

      should("find the neighbors for the last post") do
        assert_equal(@p2.id, @pool.previous_post_id(@p3.id))
        assert_nil(@pool.next_post_id(@p3.id))
      end
    end

    context("Pool artists") do
      setup do
        @post = create(:post, tag_string: "artist:foo")
        @pool = create(:pool)
        @pool.add!(@post, @user)
      end

      should("be correct") do
        assert_same_elements(%w[foo], @pool.artist_names)
      end

      should("update when an artist is added/removed") do
        with_inline_jobs { @post.update_with(@user, tag_string_diff: "artist:bar") }

        assert_same_elements(%w[foo bar], @pool.reload.artist_names)

        with_inline_jobs { @post.update_with(@user, tag_string_diff: "-foo") }

        assert_same_elements(%w[bar], @pool.reload.artist_names)
      end

      should("update when a post is added/removed (via add!/remove!)") do
        @post2 = create(:post, tag_string: "artist:baz")
        @pool.add!(@post2, @user)

        assert_same_elements(%w[foo baz], @pool.artist_names)

        @pool.remove!(@post, @user)

        assert_same_elements(%w[baz], @pool.artist_names)
      end

      should("update when a post is added/removed (via post_ids=)") do
        @post2 = create(:post, tag_string: "artist:baz")
        @pool.update_with(@user, post_ids: [@post.id, @post2.id])

        assert_same_elements(%w[foo baz], @pool.artist_names)

        @pool.update_with(@user, post_ids: [@post2.id])

        assert_same_elements(%w[baz], @pool.artist_names)
      end
    end
  end
end

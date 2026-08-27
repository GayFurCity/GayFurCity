# frozen_string_literal: true

require("test_helper")

class PostSetTest < ActiveSupport::TestCase
  context("A post set") do
    setup do
      @user = create(:user, created_at: 1.month.ago)
    end

    context("A shortname") do
      setup { @set = create(:post_set, creator: @user, shortname: "custom_short") }

      should("be mapped to a post set id") do
        assert_equal(@set.id, PostSet.name_to_id("custom_short"))
      end
    end

    context("An id number") do
      setup { @set = create(:post_set, creator: @user) }

      should("be mapped to a post set id") do
        assert_equal(@set.id, PostSet.name_to_id(@set.id.to_s))
      end
    end

    context("Creating a post set") do
      setup do
        @posts = create_list(:post, 3)
        @set = create(:post_set, creator: @user, post_ids: @posts.map(&:id))
      end

      should("initialize the post count") do
        assert_equal(3, @set.post_count)
      end

      should("default to private") do
        assert_not(create(:post_set, creator: @user).is_public)
      end

      should("synchronize the posts with the set") do
        assert_equal(@posts.map(&:id), @set.post_ids)

        @posts.each(&:reload)

        assert_equal(["set:#{@set.id}"] * 3, @posts.map(&:pool_string))
      end
    end

    context("Validations") do
      setup { @set = build(:post_set, creator: @user) }

      should("require a name at least three characters long") do
        @set.name = "ab"

        assert_not(@set.valid?)
        assert_includes(@set.errors[:name].join, "between three")
      end

      should("normalize the shortname to lowercase") do
        @set.shortname = "Foo_Bar"
        @set.save

        assert_equal("foo_bar", @set.shortname)
      end

      should("require the shortname to contain a letter or underscore") do
        @set.shortname = "12345"

        assert_not(@set.valid?)
      end

      should("not allow duplicate names") do
        create(:post_set, creator: @user, name: "duplicate_name")
        @set.name = "duplicate_name"

        assert_not(@set.valid?)
        assert_includes(@set.errors[:name].join, "already taken")
      end

      should("limit the number of posts") do
        stub_admin_config(:set_post_limit, 2)
        @set.post_ids = create_list(:post, 3).map(&:id)

        assert_not(@set.valid?)
        assert_includes(@set.errors[:base].join, "up to 2 posts")
      end

      should("limit the number of sets a user can create") do
        stub_admin_config(:post_set_limit, 1, user: @user)
        create(:post_set, creator: @user)

        assert_not(@set.valid?)
        assert_includes(@set.errors[:base].join, "only create 1 sets")
      end
    end

    context("Making a set public") do
      setup { @set = create(:post_set, creator: @user) }

      should("be allowed for accounts older than three days") do
        @set.update_with(@user, is_public: true)

        assert(@set.reload.is_public)
      end

      should("be blocked for accounts younger than three days") do
        newbie = create(:user, created_at: Time.now)
        @set = create(:post_set, creator: newbie)
        @set.update_with(newbie, is_public: true)

        assert_not(@set.reload.is_public)
        assert_includes(@set.errors[:base].join, "three days old")
      end

      should("be allowed for janitors regardless of account age") do
        janitor = create(:janitor_user, created_at: Time.now)
        @set = create(:post_set, creator: janitor)
        @set.update_with(janitor, is_public: true)

        assert(@set.reload.is_public)
      end
    end

    context("Access control") do
      setup do
        @owner = create(:user, created_at: 1.month.ago)
        @other = create(:user, created_at: 1.month.ago)
        @admin = create(:admin_user)
        @mod = create(:moderator_user)
      end

      context("A private set") do
        setup { @set = create(:post_set, creator: @owner) }

        should("be visible to the owner") { assert(@set.can_view?(@owner)) }
        should("be visible to moderators") { assert(@set.can_view?(@mod)) }
        should("not be visible to other users") { assert_not(@set.can_view?(@other)) }
        should("not be visible to anonymous users") { assert_not(@set.can_view?(User.anonymous)) }

        should("have its settings editable by the owner") { assert(@set.can_edit_settings?(@owner)) }
        should("have its settings editable by admins") { assert(@set.can_edit_settings?(@admin)) }
        should("not have its settings editable by other users") { assert_not(@set.can_edit_settings?(@other)) }

        should("have its posts editable by the owner") { assert(@set.can_edit_posts?(@owner)) }
        should("not have its posts editable by other users") { assert_not(@set.can_edit_posts?(@other)) }
      end

      context("A public set") do
        setup do
          @set = create(:post_set, creator: @owner)
          @set.update_with!(@owner, is_public: true)
        end

        should("be visible to everyone") do
          assert(@set.can_view?(@other))
          assert(@set.can_view?(User.anonymous))
        end

        should("not have its posts editable by non-maintainers") { assert_not(@set.can_edit_posts?(@other)) }

        context("with an approved maintainer") do
          setup { PostSetMaintainer.create!(post_set: @set, user: @other, status: "approved") }

          should("report the user as a maintainer") { assert(@set.is_maintainer?(@other)) }
          should("have its posts editable by the maintainer") { assert(@set.can_edit_posts?(@other)) }
          should("not have its settings editable by the maintainer") { assert_not(@set.can_edit_settings?(@other)) }
        end

        context("with a pending maintainer invite") do
          setup { PostSetMaintainer.create!(post_set: @set, user: @other, status: "pending") }

          should("report the user as invited") { assert(@set.is_invited?(@other)) }
          should("not report the user as a maintainer") { assert_not(@set.is_maintainer?(@other)) }
          should("not have its posts editable by the invited user") { assert_not(@set.can_edit_posts?(@other)) }
        end

        context("with a blocked maintainer") do
          setup { PostSetMaintainer.create!(post_set: @set, user: @other, status: "blocked") }

          should("report the user as blocked") { assert(@set.is_blocked?(@other)) }
        end
      end
    end

    context("Managing posts") do
      setup do
        @set = create(:post_set, creator: @user)
        @p1 = create(:post)
        @p2 = create(:post)
        @p3 = create(:post)
      end

      context("adding a post via #add!") do
        setup { @set.add!(@p1, @user) }

        should("add the post to the set") { assert_equal([@p1.id], @set.post_ids) }
        should("add the set to the post") { assert_equal("set:#{@set.id}", @p1.pool_string) }
        should("increment the post count") { assert_equal(1, @set.post_count) }

        should("not double add the post on repeated calls") do
          @set.add!(@p1, @user)

          assert_equal([@p1.id], @set.post_ids)
        end
      end

      context("removing a post via #remove!") do
        setup do
          @set.add!(@p1, @user)
          @set.remove!(@p1, @user)
        end

        should("remove the post from the set") { assert_equal([], @set.post_ids) }
        should("remove the set from the post") { assert_equal("", @p1.pool_string) }
        should("update the post count") { assert_equal(0, @set.post_count) }
      end

      context("adding posts via #add") do
        setup do
          @set.add([@p1.id, @p2.id])
          @set.updater = @user
          @set.save
        end

        should("add the posts") { assert_equal([@p1.id, @p2.id], @set.post_ids) }

        should("synchronize the posts") do
          assert_equal("set:#{@set.id}", @p1.reload.pool_string)
          assert_equal("set:#{@set.id}", @p2.reload.pool_string)
        end

        should("ignore ids that don't correspond to real posts") do
          invalid = Post.maximum(:id) + 1
          @set.add([invalid])

          assert_not_includes(@set.post_ids, invalid)
        end
      end

      context("removing posts via #remove") do
        setup do
          @set = create(:post_set, creator: @user, post_ids: [@p1.id, @p2.id])
          @set.remove([@p1.id])
          @set.updater = @user
          @set.save
        end

        should("remove the post") { assert_equal([@p2.id], @set.post_ids) }
        should("synchronize the post") { assert_equal("", @p1.reload.pool_string) }
      end

      context("post navigation") do
        setup do
          @set.add!(@p1, @user)
          @set.add!(@p2, @user)
          @set.add!(@p3, @user)
        end

        should("identify the first and last posts") do
          assert(@set.first_post?(@p1.id))
          assert(@set.last_post?(@p3.id))
          assert_not(@set.first_post?(@p2.id))
          assert_not(@set.last_post?(@p2.id))
        end

        should("find the neighbors for the first post") do
          assert_nil(@set.previous_post_id(@p1.id))
          assert_equal(@p2.id, @set.next_post_id(@p1.id))
        end

        should("find the neighbors for the middle post") do
          assert_equal(@p1.id, @set.previous_post_id(@p2.id))
          assert_equal(@p3.id, @set.next_post_id(@p2.id))
        end

        should("find the neighbors for the last post") do
          assert_equal(@p2.id, @set.previous_post_id(@p3.id))
          assert_nil(@set.next_post_id(@p3.id))
        end

        should("track the page number of a post") do
          assert_equal(1, @set.page_number(@p1.id))
          assert_equal(2, @set.page_number(@p2.id))
          assert_equal(3, @set.page_number(@p3.id))
        end
      end
    end

    context("Search") do
      setup do
        @set = create(:post_set, creator: @user, name: "findable_set")
        @set.update_with!(@user, is_public: true)
      end

      should("be findable by owner") do
        assert_equal([@set], PostSet.owned_by(@user).to_a)
      end

      should("only be visible to the public when public") do
        private_set = create(:post_set, creator: @user)

        assert_includes(PostSet.visible(nil), @set)
        assert_not_includes(PostSet.visible(nil), private_set)
        assert_includes(PostSet.visible(@user), private_set)
      end

      should("be findable by post id") do
        post = create(:post)
        @set.add!(post, @user)

        assert_equal([@set], PostSet.where_has_post(post.id).to_a)
      end

      should("be findable by maintainer") do
        maintainer = create(:user)
        PostSetMaintainer.create!(post_set: @set, user: maintainer, status: "approved")

        assert_equal([@set], PostSet.where_has_maintainer(maintainer.id).to_a)
      end

      should("list sets a user actively maintains") do
        maintainer = create(:user)
        PostSetMaintainer.create!(post_set: @set, user: maintainer, status: "approved")

        assert_equal([@set], PostSet.active_maintainer(maintainer).to_a)
      end
    end
  end
end

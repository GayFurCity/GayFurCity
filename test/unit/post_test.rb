# frozen_string_literal: true

require("test_helper")

class PostTest < ActiveSupport::TestCase
  def assert_tag_match(posts, query, user = User.anonymous)
    assert_equal(posts.map(&:id), Post.tag_match(query, user).pluck(:id), "Query: #{query}")
  end

  def save_with_groups(post, groups, ungrouped)
    post.character_groups_attributes = groups
    post.ungrouped_tag_string = ungrouped
    post.updater = @janitor
    post.save!
    post
  end

  setup do
    @user = create(:user, created_at: 2.weeks.ago)
    @janitor = create(:janitor_user)
    reset_post_index
  end

  context("Deletion:") do
    context("Expunging a post") do
      # That belonged in a museum!
      setup do
        @upload = create(:jpg_upload, uploader: @user)
        @post = @upload.post
        FavoriteManager.add!(user: @post.uploader, post: @post)
      end

      should("delete the files") do
        assert_nothing_raised { @post.preview_file }
        assert_nothing_raised { @post.file }

        @post.expunge!(@user)

        assert_raise(Errno::ENOENT) { @post.preview_file }
        assert_raise(Errno::ENOENT) { @post.file }
      end

      should("remove all favorites") do
        @post.expunge!(@user)

        assert_equal(0, Favorite.for_user(@post.uploader_id).where(post_id: @post.id).count)
      end

      should("decrement the uploader's upload count") do
        assert_difference("@post.uploader.reload.post_upload_count", -1) do
          @post.expunge!(@user)
        end
      end

      should("decrement the user's note update count") do
        create(:note, post: @post, creator: @user)
        assert_difference(["@post.uploader.reload.note_update_count"], -1) do
          @post.expunge!(@user)
        end
      end

      should("decrement the user's post update count") do
        assert_difference(["@post.uploader.reload.post_update_count"], -1) do
          @post.expunge!(@user)
        end
      end

      should("decrement the user's favorite count") do
        assert_difference(["@post.uploader.reload.favorite_count"], -1) do
          @post.expunge!(@user)
        end
      end

      should("remove the post from iqdb") do
        request_stub = stub_request(:delete, "#{IqdbProxy.endpoint}/images/#{@post.id}")
        with_inline_jobs { @post.expunge!(@user) }

        assert_requested(request_stub)
      end

      context("that is status locked") do
        setup do
          @post.update(is_status_locked: true)
        end

        should("not destroy the record") do
          @post.expunge!(@user)

          assert_equal(1, Post.where("id = ?", @post.id).count)
        end
      end

      context("that belongs to a pool") do
        setup do
          @pool = create(:pool)
          @pool.add!(@post, @user)

          @post.expunge!(@user)
          @pool.reload
        end

        should("remove the post from all pools") do
          assert_equal([], @pool.post_ids)
        end

        should("destroy the record") do
          assert_equal([], @post.errors.full_messages)
          assert_equal(0, Post.where("id = ?", @post.id).count)
        end
      end
    end

    context("Deleting a post") do
      context("that is status locked") do
        setup do
          @post = create(:post, is_status_locked: true)
        end

        should("fail") do
          @post.delete!(@user, "test")

          assert_equal(["Is status locked ; cannot delete post"], @post.errors.full_messages)
          assert_equal(1, Post.where("id = ?", @post.id).count)
        end
      end

      context("that is pending") do
        setup do
          @post = create(:post, is_pending: true)
        end

        should("succeed") do
          @post.delete!(@user, "test")

          assert_predicate(@post, :is_deleted?)
          assert_equal(1, @post.flags.size)
          assert_match(/test/, @post.flags.last.reason)
        end
      end

      context("that is still in cooldown after being flagged") do
        should("succeed") do
          flag = create(:post_flag)

          assert_equal([], flag.errors.full_messages)
          flag.post.delete!(@user, "test deletion")

          assert(flag.post.is_deleted)
          assert_equal(2, flag.post.flags.size)
        end
      end

      should("toggle the is_deleted flag") do
        post = create(:post)

        assert_not(post.is_deleted?)
        post.delete!(@user, "test")

        assert_predicate(post, :is_deleted?)
      end

      should("move the files") do
        post = create(:post)
        path = post.media_asset.file_path(protected: false)
        new_path = post.media_asset.file_path(protected: true)
        preview = post.media_asset.find_variant!(:preview)
        preview_path = preview.file_path(protected: false)
        new_preview_path = preview.file_path(protected: true)

        assert_equal(post.file_path, path)
        assert_equal(post.preview_file_path, preview_path)
        post.delete!(@user, "test")

        assert_equal(post.file_path, new_path)
        assert_equal(post.preview_file_path, new_preview_path)
        post.undelete!(@user)

        assert_equal(post.file_path, path)
        assert_equal(post.preview_file_path, preview_path)
      end

      should("generated the expected paths") do
        post = create(:post)
        h = { prefix: GayFurCity.config.post_path_prefix, protected_prefix: GayFurCity.config.protected_path_prefix }
        path = GayFurCity.config.storage_manager.instance.file_path(post.md5, post.file_ext, :original, protected: false, **h)
        preview_path = GayFurCity.config.storage_manager.instance.file_path(post.md5, "webp", :preview, protected: false, **h)
        new_path = GayFurCity.config.storage_manager.instance.file_path(post.md5, post.file_ext, :original, protected: true, **h)
        new_preview_path = GayFurCity.config.storage_manager.instance.file_path(post.md5, "webp", :preview, protected: true, **h)

        assert_equal(post.file_path, path)
        assert_equal(post.preview_file_path, preview_path)
        post.delete!(@user, "test")

        assert_equal(post.file_path, new_path)
        assert_equal(post.preview_file_path, new_preview_path)
        post.undelete!(@user)

        assert_equal(post.file_path, path)
        assert_equal(post.preview_file_path, preview_path)
      end
    end
  end

  context("Parent:") do
    setup do
      @parent = create(:post, tag_string: "a b c d", source: "a\nb\nc")
      @post = create(:post, parent_id: @parent.id, tag_string: "c d e f", source: "b\nc\nd")
    end
    should("Copy tags to parent") do
      @post.updater = @user
      @post.copy_tags_to_parent
      @post.parent.save

      assert_equal("a b c d e f invalid_source", @parent.reload.tag_string)
    end
    should("Copy sources to parent") do
      @post.updater = @user
      @post.copy_sources_to_parent
      @post.parent.save

      assert_equal("a\nb\nc\nd", @parent.reload.source)
    end
  end

  context("Parenting:") do
    context("Assigning a parent to a post") do
      should("update the has_children flag on the parent") do
        p1 = create(:post)

        assert_not(p1.has_children?, "Parent should not have any children")
        create(:post, parent_id: p1.id)
        p1.reload

        assert_predicate(p1, :has_children?, "Parent not updated after child was added")
      end

      should("update the has_children flag on the old parent") do
        p1 = create(:post)
        p2 = create(:post)
        c1 = create(:post, parent_id: p1.id)
        c1.parent_id = p2.id
        c1.save
        p1.reload
        p2.reload

        assert_not(p1.has_children?, "Old parent should not have a child")
        assert_predicate(p2, :has_children?, "New parent should have a child")
      end
    end

    context("Expunging a post with") do
      context("a parent") do
        should("reset the has_children flag of the parent") do
          p1 = create(:post)
          c1 = create(:post, parent_id: p1.id)
          c1.expunge!(@user)
          p1.reload

          assert_not(p1.has_children?)
        end

        should("update the parent's has_children flag") do
          p1 = create(:post)
          c1 = create(:post, parent_id: p1.id)
          c1.expunge!(@user)
          p1.reload

          assert_not(p1.has_children?, "Parent should not have children")
        end
      end

      context("one child") do
        should("remove the parent of that child") do
          p1 = create(:post)
          c1 = create(:post, parent_id: p1.id)
          p1.expunge!(@user)
          c1.reload

          assert_nil(c1.parent)
        end
      end

      context("two or more children") do
        setup do
          # ensure initial post versions won't be merged.
          travel_to(1.day.ago) do
            @p1 = create(:post)
            @c1 = create(:post, parent_id: @p1.id)
            @c2 = create(:post, parent_id: @p1.id)
            @c3 = create(:post, parent_id: @p1.id)
          end
        end

        should("reparent all children to the first child") do
          @p1.expunge!(@user)
          @c1.reload
          @c2.reload
          @c3.reload

          assert_nil(@c1.parent_id)
          assert_equal(@c1.id, @c2.parent_id)
          assert_equal(@c1.id, @c3.parent_id)
        end

        should("save a post version record for each child") do
          assert_difference(["@c1.versions.count", "@c2.versions.count", "@c3.versions.count"]) do
            @p1.expunge!(@user)
            @c1.reload
            @c2.reload
            @c3.reload
          end
        end

        should("set the has_children flag on the new parent") do
          @p1.expunge!(@user)

          assert_predicate(@c1.reload, :has_children?)
        end
      end
    end

    context("Deleting a post with") do
      context("a parent") do
        should("not reassign favorites and votes to the parent by default") do
          p1 = create(:post)
          c1 = create(:post, parent_id: p1.id)
          user = create(:trusted_user)
          FavoriteManager.add!(user: user, post: c1)
          VoteManager::Posts.vote!(user: user, ip_addr: "127.0.0.1", post: c1, score: 1)
          c1.delete!(@user, "test")
          p1.reload

          assert(Favorite.exists?(post_id: c1.id, user_id: user.id), "Child should still have favorites")
          assert(PostVote.exists?(post_id: c1.id, user_id: user.id), "Child should still have votes")
          assert_not(Favorite.exists?(post_id: p1.id, user_id: user.id), "Parent should not have favorites")
          assert_not(PostVote.exists?(post_id: p1.id, user_id: user.id), "Parent should not have votes")
        end

        should("reassign favorites and votes to the parent if specified") do
          p1 = create(:post)
          c1 = create(:post, parent_id: p1.id)
          user = create(:trusted_user)
          FavoriteManager.add!(user: user, post: c1)
          VoteManager::Posts.vote!(user: user, ip_addr: "127.0.0.1", post: c1, score: 1)
          with_inline_jobs { c1.delete!(@user, "test", move_favorites: true) }
          p1.reload

          assert_not(Favorite.exists?(post_id: c1.id, user_id: user.id), "Child should not still have favorites")
          assert_not(PostVote.exists?(post_id: c1.id, user_id: user.id), "Child should not still have votes")
          assert(Favorite.exists?(post_id: p1.id, user_id: user.id), "Parent should have favorites")
          assert(PostVote.exists?(post_id: p1.id, user_id: user.id), "Parent should have votes")
        end

        should("not update the parent's has_children flag") do
          p1 = create(:post)
          c1 = create(:post, parent_id: p1.id)
          c1.delete!(@user, "test")
          p1.reload

          assert_predicate(p1, :has_children?, "Parent should have children")
        end

        should("clear the has_active_children flag when the 'move favorites' option is set") do
          user = create(:trusted_user)
          p1 = create(:post)
          c1 = create(:post, parent_id: p1.id)
          FavoriteManager.add!(user: user, post: c1)

          assert_predicate(p1.reload, :has_active_children?)
          c1.delete!(@user, "test", move_favorites: true)

          assert_not(p1.reload.has_active_children?)
        end
      end

      context("one child") do
        should("not remove the has_children flag") do
          p1 = create(:post)
          create(:post, parent_id: p1.id)
          p1.delete!(@user, "test")
          p1.reload

          assert_predicate(p1, :has_children?)
        end

        should("not remove the parent of that child") do
          p1 = create(:post)
          c1 = create(:post, parent_id: p1.id)
          p1.delete!(@user, "test")
          c1.reload

          assert_not_nil(c1.parent)
        end
      end

      context("two or more children") do
        should("not reparent all children to the first child") do
          p1 = create(:post)
          c1 = create(:post, parent_id: p1.id)
          c2 = create(:post, parent_id: p1.id)
          c3 = create(:post, parent_id: p1.id)
          p1.delete!(@user, "test")
          c1.reload
          c2.reload
          c3.reload

          assert_equal(p1.id, c1.parent_id)
          assert_equal(p1.id, c2.parent_id)
          assert_equal(p1.id, c3.parent_id)
        end
      end
    end

    context("Undeleting a post with a parent") do
      should("update with a new approver") do
        new_user = create(:moderator_user)
        p1 = create(:post)
        c1 = create(:post, parent_id: p1.id)
        c1.delete!(@user, "test")
        c1.undelete!(new_user)
        p1.reload

        assert_equal(new_user.id, c1.approver_id)
      end

      should("preserve the parent's has_children flag") do
        p1 = create(:post)
        c1 = create(:post, parent_id: p1.id)
        c1.delete!(@user, "test")
        c1.undelete!(@user)
        p1.reload

        assert_not_nil(c1.parent_id)
        assert_predicate(p1, :has_children?, "Parent should have children")
      end
    end
  end

  context("Moderation:") do
    context("A deleted post") do
      setup do
        @post = create(:post, is_deleted: true)
      end

      context("that is status locked") do
        setup do
          @post.update_with(@user, is_status_locked: true)
        end

        should("not allow undeletion") do
          @post.undelete!(@user)

          assert_equal(["Is status locked ; cannot undelete post"], @post.errors.full_messages)
          assert_predicate(@post, :is_deleted?)
        end
      end

      context("when undeleted") do
        should("be undeleted") do
          @post.undelete!(@user)

          assert_not(@post.reload.is_deleted?)
        end
      end
    end

    context("An approved post") do
      should("be flagged") do
        post = create(:post)
        assert_difference(-> { PostFlag.count }, 1) do
          create(:post_flag, post: post)
        end
        assert_predicate(post, :is_flagged?, "Post should be flagged.")
        assert_equal(1, post.flags.count)
      end

      should("not be flagged if no reason is given") do
        post = create(:post)
        assert_no_difference(-> { PostFlag.count }) do
          post.flags.create(reason_name: "", creator: @user)
        end
      end
    end

    context("An unapproved post") do
      should("preserve the approver's identity when approved") do
        post = create(:post, is_pending: true)
        post.approve!(@user)

        assert_equal(post.approver_id, @user.id)
      end

      context("that was previously approved by person X") do
        setup do
          @mod = create(:moderator_user, name: "xxx")
          @mod2 = create(:moderator_user, name: "yyy")
          @post = create(:post)
          @post.approve!(@mod)
          @post.unapprove!(@user)
        end

        should("allow person Y to approve the post") do
          @post.approve!(@mod2)

          assert_predicate(@post, :valid?)
        end
      end

      context("that has been reapproved") do
        setup do
          @post = create(:post)
          create(:post_flag, post: @post)
          @post.reload
        end

        should("no longer be pending") do
          @post.approve!(@user)

          assert_empty(@post.errors, @post.errors.full_messages.join(", "))
          @post.reload

          assert_predicate(@post, :is_flagged?)
          assert_not(@post.is_pending?)
        end
      end
    end

    context("An in-progress post") do
      setup do
        @post = create(:post, is_in_progress: true, uploader: @user, tag_string: create(:artist_tag).name)
      end

      should("let the uploader finish it into the pending queue") do
        @post.finish_in_progress!(@user)

        assert_not(@post.is_in_progress?)
        assert_predicate(@post, :is_pending?)
        assert_equal("in_progress_finished", PostEvent.last.action)
      end

      should("let a janitor force it into the pending queue") do
        janitor = create(:janitor_user)
        @post.finish_in_progress!(janitor)

        assert_not(@post.is_in_progress?)
        assert_predicate(@post, :is_pending?)
        assert_equal("in_progress_forced", PostEvent.last.action)
      end

      should("reset the approver, since instant-replacement approval isn't a real moderation approval") do
        @post.update_column(:approver_id, create(:janitor_user).id)
        @post.finish_in_progress!(@user)

        assert_nil(@post.reload.approver_id)
      end

      should("not let an unrelated member finish it") do
        other = create(:user)

        assert_not(@post.finishable_in_progress?(other))
      end
    end

    context("A status locked post") do
      setup do
        @post = create(:post, is_status_locked: true, is_pending: true)
      end

      should("not allow new flags") do
        flag = build(:post_flag, post: @post, creator: @user)
        flag.validate

        assert_equal(["Post is locked and cannot be flagged"], flag.errors.full_messages)
      end

      should("not allow approval") do
        assert_no_difference(-> { PostApproval.count }) do
          @post.approve!(@user)
        end
      end
    end
  end

  context("Tagging:") do
    context("A post") do
      setup do
        @post = create(:post)
      end

      context("as a new user") do
        setup do
          @user = create(:user)
          @post.update(tag_string: "aaa bbb ccc ddd tagme")
        end

        should("allow you to remove request tags") do
          @post.update_with(@user, tag_string: "aaa bbb ccc ddd")
          @post.reload

          assert_equal("aaa bbb ccc ddd", @post.tag_string)
        end
      end

      context("with an artist tag that is then changed to copyright") do
        setup do
          with_inline_jobs do
            @post.update_with(@janitor, tag_string: "art:abc")
            @post.update_with(@janitor, tag_string: "copy:abc")
          end
          @post.reload
        end

        should("update the category of the tag") do
          assert_equal(TagCategory.copyright, Tag.find_by(name: "abc").category)
        end

        should("update the category cache of the tag") do
          assert_equal(TagCategory.copyright, Cache.fetch("tc:abc"))
        end

        should("update the tag counts of the posts") do
          assert_equal(0, @post.tag_count_artist)
          assert_equal(1, @post.tag_count_copyright)
          assert_equal(0, @post.tag_count_general)
        end
      end

      context("using a tag prefix on an aliased tag") do
        setup do
          create(:tag_alias, antecedent_name: "abc", consequent_name: "xyz")
          @post = Post.find(@post.id)
          @post.update_with(@janitor, tag_string: "art:abc")
          @post.reload
        end

        should("convert the tag to its normalized version") do
          assert_equal("xyz", @post.tag_string)
        end
      end

      context("with locked tags") do
        context("without aliases or implications") do
          setup do
            @post = create(:post, locked_tags: "abc -what bcd -def", tag_string: "test_tag def")
          end

          should("contain correct tags") do
            assert_equal("abc bcd test_tag", @post.tag_string)
          end
        end

        context("with aliases") do
          setup do
            create(:tag_alias, antecedent_name: "abc", consequent_name: "xyz")
            create(:tag_alias, antecedent_name: "def", consequent_name: "what")
            @post = create(:post, locked_tags: "abc bcd -def", tag_string: "test_tag def what")
          end

          should("contain correct tags") do
            assert_equal("bcd test_tag xyz", @post.tag_string)
          end
        end

        context("with implications") do
          should("contain correct tags") do
            create(:tag_implication, antecedent_name: "specific_tag", consequent_name: "base_tag")
            create(:tag_implication, antecedent_name: "female/female", consequent_name: "female")
            create(:tag_implication, antecedent_name: "male/male", consequent_name: "male")
            create(:tag_implication, antecedent_name: "trio", consequent_name: "group")
            locked_tags = "-base_tag -female/female male/male test_tag"
            tag_string = "specific_tag female/female group def"
            @post = create(:post, locked_tags: locked_tags, tag_string: tag_string)

            assert_equal("def group male male/male test_tag", @post.tag_string)
          end

          should("update the cache when implications change") do
            @post = create(:post, locked_tags: "-group", tag_string: "trio specific_tag")

            assert_equal("specific_tag trio", @post.tag_string)

            ti = create(:tag_implication, antecedent_name: "trio", consequent_name: "group", status: "pending")
            ti.approve!(@user)
            create(:tag_implication, antecedent_name: "specific_tag", consequent_name: "base_tag", status: "pending")
            @post.tag_string += " "
            @post.updater = @user
            @post.save

            assert_equal("specific_tag", @post.tag_string)

            ti.reject!(@user)
            @post.tag_string += " trio"
            @post.updater = @user
            @post.save

            assert_equal("specific_tag trio", @post.tag_string)
          end
        end

        context("with dnp tags") do
          should("prevent manually adding them") do
            @post = create(:post, locked_tags: "", tag_string: "a b c")
            @post.tag_string += " conditional_dnp"
            @post.updater = @user
            @post.save

            assert_equal("a b c", @post.tag_string)
            assert_equal("", @post.locked_tags)
          end

          should("add dnp tags through an implication") do
            create(:tag_implication, antecedent_name: "artist", consequent_name: "avoid_posting")
            @post = create(:post, locked_tags: "", tag_string: "a b c")

            @post.tag_string += " artist"
            @post.updater = @user
            @post.save

            assert_equal("a artist avoid_posting b c", @post.tag_string)
            assert_equal("avoid_posting", @post.locked_tags)
          end

          should("prevent removing them") do
            create(:tag_implication, antecedent_name: "artist", consequent_name: "avoid_posting")
            @post = create(:post, tag_string: "a artist avoid_posting b c")

            @post.tag_string = "a b c"
            @post.warnings.clear
            @post.updater = @user
            @post.save

            assert_match(/Forcefully added 1 locked tag: avoid_posting/, @post.warnings.full_messages.join(" "))

            assert_equal("a avoid_posting b c", @post.tag_string)
          end

          should("not warn about dnp tags when dnp tags didn't change") do
            create(:tag_implication, antecedent_name: "artist", consequent_name: "avoid_posting")
            @post = create(:post, tag_string: "a artist avoid_posting b c")

            @post.tag_string += "d e f"
            @post.warnings.clear
            @post.updater = @user
            @post.save

            assert_no_match(/Forcefully added 1 locked tag: avoid_posting/, @post.warnings.full_messages.join(" "))
          end
        end

        context("in the invalid category") do
          setup do
            @post = create(:post, locked_tags: "invalid_tag -invalid_tag_2", tag_string: "invalid_tag invalid_tag_2 test_tag")
            @post.warnings.clear
            tag = Tag.where(name: %w[invalid_tag invalid_tag_2])
            tag.update_all(category: TagCategory.invalid)
            tag.each(&:update_category_cache)
          end

          should("remove them") do
            @post.tag_string += " "
            @post.updater = @user
            @post.save

            assert_match(/Forcefully removed 2 invalid locked tags: invalid_tag, -invalid_tag_2/, @post.warnings.full_messages.join(" "))
            assert_equal("invalid_tag test_tag", @post.tag_string)
            assert_empty(@post.locked_tags)
          end

          should("not allow adding") do
            @post.update_column(:locked_tags, "")

            @post.locked_tags = "invalid_tag -invalid_tag_2"
            @post.updater = @user
            @post.save

            assert_match(/Forcefully removed 2 invalid locked tags: invalid_tag, -invalid_tag_2/, @post.warnings.full_messages.join(" "))
            assert_equal("invalid_tag test_tag", @post.tag_string)
            assert_empty(@post.locked_tags)
          end
        end
      end

      context("tagged with a metatag") do
        context("for typing a tag") do
          setup do
            @post = create(:post, tag_string: "char:hoge")
            @tags = @post.tag_array
          end

          should("change the type") do
            assert(Tag.exists?(name: "hoge", category: 4), "expected 'hoge' tag to be created as a character")
          end
        end

        context("for a parent") do
          setup do
            @parent = create(:post)
          end

          should("update the parent relationships for both posts") do
            @post.update_with(@user, tag_string: "aaa parent:#{@parent.id}")
            @post.reload
            @parent.reload

            assert_equal(@parent.id, @post.parent_id)
            assert_predicate(@parent, :has_children?)
          end

          should("not allow self-parenting") do
            @post.update_with(@user, tag_string: "parent:#{@post.id}")

            assert_nil(@post.parent_id)
          end

          should("clear the parent with parent:none") do
            @post.update_with(@user, parent_id: @parent.id)

            assert_equal(@parent.id, @post.parent_id)

            @post.update_with(@user, tag_string: "parent:none")

            assert_nil(@post.parent_id)
          end

          should("clear the parent with -parent:1234") do
            @post.update_with(@user, parent_id: @parent.id)

            assert_equal(@parent.id, @post.parent_id)

            @post.update_with(@user, tag_string: "-parent:#{@parent.id}")

            assert_nil(@post.parent_id)
          end
        end

        context("for a pool") do
          context("on creation") do
            setup do
              @pool = create(:pool)
              @post = create(:post, tag_string: "aaa pool:#{@pool.id}")
            end

            should("add the post to the pool") do
              @post.reload
              @pool.reload

              assert_equal([@post.id], @pool.post_ids)
              assert_equal("pool:#{@pool.id}", @post.pool_string)
            end
          end

          context("negated") do
            setup do
              @pool = create(:pool)
              @post = create(:post, tag_string: "aaa")
              @pool.add(@post)
              @post.tag_string = "aaa -pool:#{@pool.id}"
              @post.save
            end

            should("remove the post from the pool") do
              @post.reload
              @pool.reload

              assert_equal([], @pool.post_ids)
              assert_equal("", @post.pool_string)
            end
          end

          context("id") do
            setup do
              @pool = create(:pool)
              @post.update(tag_string: "aaa pool:#{@pool.id}")
            end

            should("add the post to the pool") do
              @post.reload
              @pool.reload

              assert_equal([@post.id], @pool.post_ids)
              assert_equal("pool:#{@pool.id}", @post.pool_string)
            end
          end

          context("name") do
            context("that exists") do
              setup do
                @pool = create(:pool, name: "abc")
                @post.update_with(@user, tag_string: "aaa pool:abc")
              end

              should("add the post to the pool") do
                @post.reload
                @pool.reload

                assert_equal([@post.id], @pool.post_ids)
                assert_equal("pool:#{@pool.id}", @post.pool_string)
              end
            end

            context("that doesn't exist") do
              should("create a new pool and add the post to that pool") do
                @post.update_with(@user, tag_string: "aaa newpool:abc")
                @pool = Pool.find_by(name: "abc")
                @post.reload

                assert_not_nil(@pool)
                assert_equal([@post.id], @pool.post_ids)
                assert_equal("pool:#{@pool.id}", @post.pool_string)
              end
            end

            context("with special characters") do
              should("not strip '%' from the name") do
                @post.update(tag_string: "aaa newpool:ichigo_100%")

                assert(Pool.exists?(name: "ichigo_100%"))
              end
            end
          end
        end

        context("for a rating") do
          context("that is valid") do
            should("update the rating if the post is unlocked") do
              @post.update_with(@user, tag_string: "aaa rating:e")
              @post.reload

              assert_equal("e", @post.rating)
            end
          end

          context("that is invalid") do
            should("not update the rating") do
              @post.update_with(@user, tag_string: "aaa rating:z")
              @post.reload

              assert_equal("q", @post.rating)
            end
          end

          context("that is locked") do
            should("change the rating if locked in the same update") do
              @post.update_with(@user, tag_string: "rating:e", is_rating_locked: true)

              assert_predicate(@post, :valid?)
              assert_equal("e", @post.reload.rating)
            end

            should("not change the rating if locked previously") do
              @post.is_rating_locked = true
              @post.updater = @user
              @post.save

              @post.update_with(@user, tag_string: "rating:e")

              assert_predicate(@post, :invalid?)
              assert_not_equal("e", @post.reload.rating)
            end
          end
        end

        context("for a fav") do
          should("add/remove the current user to the post's favorite listing") do
            @post.update_with(@user, tag_string: "aaa")
            FavoriteManager.add!(user: @user, post: @post)

            assert_equal("fav:#{@user.id}", @post.fav_string)

            FavoriteManager.remove!(user: @user, post: @post)

            assert_equal("", @post.fav_string)
          end
        end

        context("for a child") do
          should("add and remove children") do
            @children = create_list(:post, 3, parent_id: nil)

            @post.update_with(@user, tag_string: "aaa child:#{@children.first.id}..#{@children.last.id}")

            assert_predicate(@post.reload, :has_children?)
            assert_equal(@post.id, @children[0].reload.parent_id)
            assert_equal(@post.id, @children[1].reload.parent_id)
            assert_equal(@post.id, @children[2].reload.parent_id)

            @post.update_with(@user, tag_string: "aaa -child:#{@children.first.id}")

            assert_predicate(@post.reload, :has_children?)
            assert_nil(@children[0].reload.parent_id)
            assert_equal(@post.id, @children[1].reload.parent_id)
            assert_equal(@post.id, @children[2].reload.parent_id)

            @post.update_with(@user, tag_string: "aaa child:none")

            assert_not(@post.reload.has_children?)
            assert_nil(@children[0].reload.parent_id)
            assert_nil(@children[1].reload.parent_id)
            assert_nil(@children[2].reload.parent_id)
          end
        end

        context("for a source") do
          should("set the source with source:foo_bar_baz") do
            @post.update_with(@user, tag_string: "source:foo_bar_baz")

            assert_equal("foo_bar_baz", @post.source)
          end

          should('set the source with source:"foo bar baz"') do
            @post.update_with(@user, tag_string: 'source:"foo bar baz"')

            assert_equal("foo bar baz", @post.source)
          end

          should('strip the source with source:"  foo bar baz  "') do
            @post.update_with(@user, tag_string: 'source:"  foo bar baz  "')

            assert_equal("foo bar baz", @post.source)
          end

          should("clear the source with source:none") do
            @post.update_with(@user, source: "foobar")
            @post.update_with(@user, tag_string: "source:none")

            assert_equal("", @post.source)
          end
        end

        context("of") do
          setup do
            @janitor = create(:janitor_user)
          end

          context("locked:notes") do
            context("by a member") do
              should("not lock the notes") do
                @post.update_with(@user, tag_string: "locked:notes")

                assert_not(@post.is_note_locked)
              end
            end

            context("by a janitor") do
              should("lock/unlock the notes") do
                @post.update_with(@janitor, tag_string: "locked:notes")

                assert(@post.is_note_locked)

                @post.update_with(@janitor, tag_string: "-locked:notes")

                assert_not(@post.is_note_locked)
              end
            end
          end

          context("locked:rating") do
            context("by a member") do
              should("not lock the rating") do
                @post.update_with(@user, tag_string: "locked:rating")

                assert_not(@post.is_rating_locked)
              end
            end

            context("by a janitor") do
              should("lock/unlock the rating") do
                @post.update_with(@janitor, tag_string: "locked:rating")

                assert(@post.is_rating_locked)

                @post.update_with(@janitor, tag_string: "-locked:rating")

                assert_not(@post.is_rating_locked)
              end
            end
          end

          context("locked:status") do
            context("by a member") do
              should("not lock the status") do
                @post.update_with(@user, tag_string: "locked:status")

                assert_not(@post.is_status_locked)
              end
            end

            context("by an admin") do
              should("lock/unlock the status") do
                @admin = create(:admin_user)
                @post.update_with(@admin, tag_string: "locked:status")

                assert(@post.is_status_locked)

                @post.update_with(@admin, tag_string: "-locked:status")

                assert_not(@post.is_status_locked)
              end
            end
          end
        end
      end

      context("tagged with a negated tag") do
        should("remove the tag if present") do
          @post.update_with(@user, tag_string: "aaa bbb ccc")
          @post.update_with(@user, tag_string: "aaa bbb ccc -bbb")
          @post.reload

          assert_equal("aaa ccc", @post.tag_string)
        end

        should("resolve aliases") do
          create(:tag_alias, antecedent_name: "tr", consequent_name: "translation_request")
          @post.update_with(@user, tag_string: "aaa translation_request -tr")

          assert_equal("aaa", @post.tag_string)
        end
      end

      context("tagged with animated_gif or animated_png") do
        should("remove the tag if not a gif or png") do
          @post.update_with(@user, tag_string: "tagme animated_gif")

          assert_equal("tagme", @post.tag_string)

          @post.update_with(@user, tag_string: "tagme animated_png")

          assert_equal("tagme", @post.tag_string)
        end
      end

      should("have an array representation of its tags") do
        post = create(:post)
        post.reload
        post.set_tag_string("aaa bbb")

        assert_equal(%w[aaa bbb], post.tag_array)
        assert_equal(%w[tag1 tag2], post.tag_array_was)
      end

      context("with large dimensions") do
        setup do
          @post.media_asset.image_width = 10_000
          @post.media_asset.image_height = 10
          @post.tag_string = ""
          @post.updater = @user
          @post.save
        end

        should("have the appropriate dimension tags added automatically") do
          assert(@post.has_tag?("absurd_res"))
          assert(@post.has_tag?("hi_res"))
        end
      end

      context("with a large file size") do
        setup do
          @post.media_asset.file_size = 26.megabytes
          @post.tag_string = ""
          @post.updater = @user
          @post.save
        end

        should("have the appropriate file size tags added automatically") do
          assert(@post.has_tag?("large_filesize"))
        end
      end

      context("with a huge file size") do
        setup do
          @post.media_asset.file_size = 76.megabytes
          @post.tag_string = ""
          @post.updater = @user
          @post.save
        end

        should("have the appropriate file size tags added automatically") do
          assert(@post.has_tag?("huge_filesize"))
        end
      end

      context("with an absurd file size") do
        setup do
          @post.media_asset.file_size = 126.megabytes
          @post.tag_string = ""
          @post.updater = @user
          @post.save
        end

        should("have the appropriate file size tags added automatically") do
          assert(@post.has_tag?("absurd_filesize"))
        end
      end

      context("with an insane file size") do
        setup do
          @post.media_asset.file_size = 176.megabytes
          @post.tag_string = ""
          @post.updater = @user
          @post.save
        end

        should("have the appropriate file size tags added automatically") do
          assert(@post.has_tag?("insane_filesize"))
        end
      end

      context("with a .webm file extension") do
        setup do
          create(:tag_implication, antecedent_name: "webm", consequent_name: "animated")
          @post.media_asset.file_ext = "webm"
          @post.media_asset.duration = 1.67
          @post.tag_string = ""
          @post.updater = @user
          @post.save
        end

        should("have the appropriate file type and duration tags added automatically") do
          assert(@post.has_tag?("webm"))
          assert(@post.has_tag?("short_playtime"))
        end

        should("apply implications after adding the file type tag") do
          assert(@post.has_tag?("animated"), "expected 'webm' to imply 'animated'")
        end
      end

      context("with an invalid source") do
        setup do
          @post.update_with(@user, source: "ABCD")
        end

        should("add the invalid_source tag") do
          assert_match(/invalid_source/, @post.reload.tag_string)
        end

        should("remove the invalid_source tag when the source is removed") do
          @post.update_with(@user, source: "")

          assert_no_match(/invalid_source/, @post.reload.tag_string)
        end
      end

      should("not allow adding invalid_source") do
        @post.update_with(@user, tag_string: "invalid_source")

        assert_no_match(/invalid_source/, @post.reload.tag_string)
      end

      context("that has been updated") do
        should("create a new version if it's the first version") do
          assert_difference("PostVersion.count", 1) do
            create(:post)
          end
        end

        should("create a new version if the post is updated") do
          post = create(:post)
          assert_difference("PostVersion.count", 1) do
            post.update_with(@user, tag_string: "zzz")
          end
        end

        context("as an automated edit") do
          should("error if attempting to merge into the first") do
            post = create(:post, uploader: @user)
            post.updater = @user
            assert_raises(PostVersion::MergeError, match: "Attempted to merge post ##{post.id} into its first version (#{post.versions.first.id})") do
              post.merge_post_version(post.versions.first)
            end
          end

          should("error if attempting to merge into a non-basic version") do
            post = create(:post, uploader: @user)
            post.update_with(@user, description: "test")
            post.updater = @user
            assert_raises(PostVersion::MergeError, match: "Attempted to merge post ##{post.id} into non-basic post version ##{post.versions.last.id}") do
              post.merge_post_version(post.versions.last)
            end
          end

          should("error if attempting to merge into a version made by another updater") do
            post = create(:post, uploader: @user)
            post.update_with(create(:user), tag_string: "zzz")
            post.updater = @user
            assert_raises(PostVersion::MergeError, match: "Attempted to merge post ##{post.id} into post version ##{post.versions.last.id} created by different updater (#{post.versions.last.updater_id}/#{@user.id})") do
              post.merge_post_version(post.versions.last)
            end
          end

          should("not attempt to merge into the first version") do
            post = create(:post)
            assert_difference("PostVersion.count", 1) do
              post.update_with(@user, automated_edit: true, tag_string: "zzz")
            end
          end

          should("merge versions for consecutive edits") do
            post = create(:post)
            assert_difference("PostVersion.count", 1) do
              post.update_with(@user, tag_string: "zzz")
              post.update_with(@user, automated_edit: true, tag_string: "yyy")
            end
          end

          should("not merge non-consecutive edits") do
            post = create(:post)
            assert_difference("PostVersion.count", 2) do
              post.update_with(@user, tag_string: "zzz")
              post.update_with(create(:user), automated_edit: true, tag_string: "yyy")
            end
          end

          should("not merge non-basic edits") do
            post = create(:post)
            assert_difference("PostVersion.count", 2) do
              post.update_with(@user, tag_string: "zzz")
              post.update_with(@user, automated_edit: true, tag_string: "yyy", description: "foo")
            end
          end

          should("delete the previous version if all changes are undone") do
            post = create(:post)
            post.update_with(@user, tag_string: "xxx yyy zzz")
            assert_no_difference("PostVersion.count") do
              post.update_with(@user, tag_string_diff: "-zzz")
              post.update_with(@user, automated_edit: true, tag_string_diff: "zzz")
            end
          end

          should("merge versions for consecutive edits (locked_tags)") do
            post = create(:post)
            assert_difference("PostVersion.count", 1) do
              post.update_with(@user, locked_tags: "zzz")
              post.update_with(@user, automated_edit: true, locked_tags: "yyy")
            end
          end

          should("not merge non-consecutive edits (locked_tags)") do
            post = create(:post)
            assert_difference("PostVersion.count", 2) do
              post.update_with(@user, locked_tags: "zzz")
              post.update_with(create(:user), automated_edit: true, locked_tags: "yyy")
            end
          end

          should("not merge non-basic edits (locked_tags)") do
            post = create(:post)
            assert_difference("PostVersion.count", 2) do
              post.update_with(@user, locked_tags: "zzz")
              post.update_with(@user, automated_edit: true, locked_tags: "yyy", description: "foo")
            end
          end

          should("delete the previous version if all changes are undone (locked_tags)") do
            post = create(:post)
            post.update_with(@user, tag_string: "yyy", locked_tags: "yyy")
            assert_no_difference("PostVersion.count") do
              post.update_with(@user, tag_string: "yyy zzz", locked_tags: "yyy zzz")
              post.update_with(@user, automated_edit: true, tag_string: "yyy", locked_tags: "yyy")
            end
          end
        end

        should("increment the updater's post_update_count") do
          post = create(:post, tag_string: "aaa bbb ccc")

          assert_difference("@user.reload.post_update_count", 1) do
            post.update_with(@user, tag_string: "zzz")
          end
        end

        should("reset its tag array cache") do
          post = create(:post, tag_string: "aaa bbb ccc")

          assert_equal(%w[aaa bbb ccc], post.tag_array)
          post.tag_string = "ddd eee fff"
          post.tag_string = "ddd eee fff"
          post.updater = @user
          post.save

          assert_equal("ddd eee fff", post.tag_string)
          assert_equal(%w[ddd eee fff], post.tag_array)
        end

        should("create the actual tag records") do
          assert_difference("Tag.count", 3) do
            create(:post, tag_string: "aaa bbb ccc")
          end
        end

        should("update the post counts of relevant tag records") do
          create(:post, tag_string: "aaa bbb ccc")
          create(:post, tag_string: "bbb ccc ddd")
          post3 = create(:post, tag_string: "ccc ddd eee")

          assert_equal(1, Tag.find_by(name: "aaa").post_count)
          assert_equal(2, Tag.find_by(name: "bbb").post_count)
          assert_equal(3, Tag.find_by(name: "ccc").post_count)
          post3.reload
          post3.updater = @user
          post3.tag_string = "xxx"
          post3.save

          assert_equal(1, Tag.find_by(name: "aaa").post_count)
          assert_equal(2, Tag.find_by(name: "bbb").post_count)
          assert_equal(2, Tag.find_by(name: "ccc").post_count)
          assert_equal(1, Tag.find_by(name: "ddd").post_count)
          assert_equal(0, Tag.find_by(name: "eee").post_count)
          assert_equal(1, Tag.find_by(name: "xxx").post_count)
        end

        should("update its tag counts") do
          artist_tag = create(:artist_tag)
          copyright_tag = create(:copyright_tag)
          general_tag = create(:tag)
          new_post = create(:post, tag_string: "#{artist_tag.name} #{copyright_tag.name} #{general_tag.name}")

          assert_equal(1, new_post.tag_count_artist)
          assert_equal(1, new_post.tag_count_copyright)
          assert_equal(1, new_post.tag_count_general)
          assert_equal(0, new_post.tag_count_character)
          assert_equal(3, new_post.tag_count)

          new_post.tag_string = "babs"
          new_post.updater = @user
          new_post.save

          assert_equal(0, new_post.tag_count_artist)
          assert_equal(0, new_post.tag_count_copyright)
          assert_equal(1, new_post.tag_count_general)
          assert_equal(0, new_post.tag_count_character)
          assert_equal(1, new_post.tag_count)
        end

        should("merge any tag changes that were made after loading the initial set of tags part 1") do
          post = create(:post, tag_string: "aaa bbb ccc")

          # user a adds <ddd>
          post_edited_by_user_a = Post.find(post.id)
          post_edited_by_user_a.old_tag_string = "aaa bbb ccc"
          post_edited_by_user_a.tag_string = "aaa bbb ccc ddd"
          post_edited_by_user_a.updater = @user
          post_edited_by_user_a.save

          # user b removes <ccc> adds <eee>
          post_edited_by_user_b = Post.find(post.id)
          post_edited_by_user_b.old_tag_string = "aaa bbb ccc"
          post_edited_by_user_b.tag_string = "aaa bbb eee"
          post_edited_by_user_b.updater = @user
          post_edited_by_user_b.save

          # final should be <aaa>, <bbb>, <ddd>, <eee>
          final_post = Post.find(post.id)

          assert_equal(%w[aaa bbb ddd eee], TagQuery.scan(final_post.tag_string).sort)
        end

        should("merge any tag changes that were made after loading the initial set of tags part 2") do
          # This is the same as part 1, only the order of operations is reversed.
          # The results should be the same.

          post = create(:post, tag_string: "aaa bbb ccc")

          # user a removes <ccc> adds <eee>
          post_edited_by_user_a = Post.find(post.id)
          post_edited_by_user_a.old_tag_string = "aaa bbb ccc"
          post_edited_by_user_a.tag_string = "aaa bbb eee"
          post_edited_by_user_a.updater = @user
          post_edited_by_user_a.save

          # user b adds <ddd>
          post_edited_by_user_b = Post.find(post.id)
          post_edited_by_user_b.old_tag_string = "aaa bbb ccc"
          post_edited_by_user_b.tag_string = "aaa bbb ccc ddd"
          post_edited_by_user_b.updater = @user
          post_edited_by_user_b.save

          # final should be <aaa>, <bbb>, <ddd>, <eee>
          final_post = Post.find(post.id)

          assert_equal(%w[aaa bbb ddd eee], TagQuery.scan(final_post.tag_string).sort)
        end

        should("merge any parent, source, and rating changes that were made after loading the initial set") do
          post = create(:post, parent: nil, source: "", rating: "q")
          parent_post = create(:post)

          # user a changes rating to safe, adds parent
          post_edited_by_user_a = Post.find(post.id)
          post_edited_by_user_a.old_parent_id = ""
          post_edited_by_user_a.old_source = ""
          post_edited_by_user_a.old_rating = "q"
          post_edited_by_user_a.parent_id = parent_post.id
          post_edited_by_user_a.source = nil
          post_edited_by_user_a.rating = "s"
          post_edited_by_user_a.updater = @user
          post_edited_by_user_a.save

          # user b adds source
          post_edited_by_user_b = Post.find(post.id)
          post_edited_by_user_b.old_parent_id = ""
          post_edited_by_user_b.old_source = ""
          post_edited_by_user_b.old_rating = "q"
          post_edited_by_user_b.parent_id = nil
          post_edited_by_user_b.source = "https://example.com"
          post_edited_by_user_b.rating = "q"
          post_edited_by_user_b.updater = @user
          post_edited_by_user_b.save

          # final post should be rated safe and have the set parent and source
          final_post = Post.find(post.id)

          assert_equal(parent_post.id, final_post.parent_id)
          assert_equal("https://example.com", final_post.source)
          assert_equal("s", final_post.rating)
        end
      end

      context("that has been tagged with a metatag") do
        should("not include the metatag in its tag string") do
          post = create(:post)
          post.tag_string = "aaa pool:1234 pool:test rating:s fav:bob"
          post.updater = @user
          post.save

          assert_equal("aaa", post.tag_string)
        end
      end

      context("when validating tags") do
        should("warn when creating a new general tag") do
          @post.add_tag("tag")
          @post.updater = @user
          @post.save

          assert_match(/Created 1 new tag: \[\[tag\]\]/, @post.warnings.full_messages.join)
        end

        should("warn when adding an artist tag without an artist entry") do
          @post.add_tag("artist:bkub")
          @post.updater = @user
          @post.save

          assert_match(/Artist \[\[bkub\]\] requires an artist entry./, @post.warnings.full_messages.join)
        end

        should("warn when adding a deprecated tag") do
          tag = create(:deprecated_tag)
          @post.add_tag(tag.name)
          @post.updater = @user
          @post.save

          assert_match(/These tags can no longer be used, see their wiki page for more information: \[\[#{tag.name}\]\]/, @post.warnings.full_messages.join)
        end

        should("remove added deprecated tags when saving") do
          tag = create(:deprecated_tag)
          @post.add_tag(tag.name)
          @post.updater = @user
          @post.save

          assert_not(@post.has_tag?(tag.name))
        end

        should("remove an added deprecated tag even if it already has posts") do
          tag = create(:deprecated_tag, post_count: 2)
          @post.add_tag(tag.name)
          @post.updater = @user
          @post.save

          assert_not(@post.has_tag?(tag.name))
          assert_match(/These tags can no longer be used, see their wiki page for more information: \[\[#{tag.name}\]\]/, @post.warnings.full_messages.join)
        end

        should("maintain existing deprecated tags when saving") do
          tag = @post.tags.first
          add_tag = create(:tag)
          create(:wiki_page, title: tag.name)
          tag.update(is_deprecated: true)

          assert(@post.has_tag?(tag.name))
          @post.add_tag(add_tag.name)
          @post.updater = @user
          @post.save

          assert(@post.has_tag?(tag.name))
          assert_includes(@post.deprecated_tags.map(&:name), tag.name)
        end

        should("warn when a post from a known source is missing an artist tag") do
          post = build(:post, source: "https://www.pixiv.net/member_illust.php?mode=medium&illust_id=65985331", uploader: @user)
          post.save

          assert_match(/Artist tag is required/, post.warnings.full_messages.join)
        end

        should("warn when an upload doesn't have enough tags") do
          post = create(:post, tag_string: "tagme")

          assert_match(/Uploads must have at least \d+ general tags/, post.warnings.full_messages.join)
        end

        should("skip the normal tag requirements for in-progress uploads that have an artist tag") do
          artist_tag = create(:artist_tag)
          post = create(:post, tag_string: artist_tag.name, is_in_progress: true)

          assert_empty(post.errors.full_messages)
          assert_no_match(/Uploads must have at least \d+ general tags/, post.warnings.full_messages.join)
          assert_no_match(/Artist tag is required/, post.warnings.full_messages.join)
        end

        should("require an artist tag for in-progress uploads") do
          post = build(:post, tag_string: "tagme", is_in_progress: true)
          post.save

          assert_not(post.persisted?)
          assert_match(/Artist tag is required for in-progress uploads/, post.errors.full_messages.join)
        end

        should("error if the tagcount is above the limit") do
          AdminConfig.any_instance.stubs(:max_tags_per_post).returns(5)
          post = create(:post, tag_string: "1 2 3 4 5")
          post.add_tag("6")
          post.save

          assert_match(/tag count exceeds maximum/, post.errors.full_messages.join)
        end

        should("error if the tagcount via implications is above the limit") do
          AdminConfig.any_instance.stubs(:max_tags_per_post).returns(2)
          create(:tag_implication, antecedent_name: "2", consequent_name: "3")
          post = create(:post, tag_string: "1")
          post.add_tag("2")
          post.updater = @user
          post.save

          assert_match(/tag count exceeds maximum/, post.errors.full_messages.join)
        end

        should("allow removing tags when the post is above the limit") do
          AdminConfig.any_instance.stubs(:max_tags_per_post).returns(2)
          post = build(:post, tag_string: "1 2 3", uploader: @user)
          post.save(validate: false)
          post.remove_tag("3")
          post.updater = @user
          post.save

          assert_no_match(/tag count exceeds maximum/, post.errors.full_messages.join)
        end
      end
    end
  end

  context("Updating:") do
    context("an existing post") do
      setup { @post = create(:post) }

      should("call Tag.increment_post_counts with the correct params") do
        @post.reload
        Tag.expects(:increment_post_counts).once.with(["abc"])
        @post.update_with(@user, tag_string: "tag1 abc")
      end
    end

    context("A rating unlocked post") do
      setup { @post = create(:post) }
      subject { @post }

      should("not allow values S, safe, derp") do
        %w[S safe derp].each do |rating|
          subject.rating = rating
          subject.updater = @user

          assert_not(subject.valid?)
        end
      end

      should("allow values s, q, e") do
        %w[s q e].each do |rating|
          subject.rating = rating
          subject.updater = @user

          assert_predicate(subject, :valid?)
        end
      end
    end

    context("A rating locked post") do
      setup { @post = create(:post, is_rating_locked: true) }
      subject { @post }

      should("not allow values S, safe, derp") do
        %w[S safe derp].each do |rating|
          subject.rating = rating
          subject.updater = @user

          assert_not(subject.valid?)
        end
      end

      should("not allow values s, e") do
        %w[s e].each do |rating|
          subject.rating = rating
          subject.updater = @user

          assert_not(subject.valid?)
        end
      end
    end
  end

  context("Favorites:") do
    context("Removing a post from a user's favorites") do
      setup do
        @user = create(:trusted_user)
        @post = create(:post)
        FavoriteManager.add!(user: @user, post: @post)
        @user.reload
      end

      should("decrement the user's favorite_count") do
        assert_difference("@user.reload.favorite_count", -1) do
          FavoriteManager.remove!(user: @user, post: @post)
        end
      end

      should("not decrement the post's score") do
        @member = create(:user)

        assert_no_difference("@post.score") { FavoriteManager.add!(user: @member, post: @post) }
        assert_no_difference("@post.score") { FavoriteManager.remove!(user: @member, post: @post) }
      end

      should("not decrement the user's favorite_count if the user did not favorite the post") do
        @post2 = create(:post)
        assert_no_difference("@user.reload.favorite_count") do
          FavoriteManager.remove!(user: @user, post: @post2)
        end
      end
    end

    context("Adding a post to a user's favorites") do
      setup do
        @user = create(:trusted_user)
        @post = create(:post)
      end

      should("periodically clean the fav_string") do
        @post.update_column(:fav_string, "fav:1 fav:1 fav:1")
        @post.update_column(:fav_count, 3)
        @post.append_user_to_fav_string(2)

        assert_equal("fav:1 fav:2", @post.fav_string)
        assert_equal(2, @post.fav_count)
      end

      should("increment the user's favorite_count") do
        assert_difference("@user.reload.favorite_count", 1) do
          FavoriteManager.add!(user: @user, post: @post)
        end
      end

      should("not increment the post's score") do
        @member = create(:user)
        FavoriteManager.add!(user: @user, post: @post)

        assert_equal(0, @post.score)
      end

      should("update the fav strings on the post") do
        FavoriteManager.add!(user: @user, post: @post)
        @post.reload

        assert_equal("fav:#{@user.id}", @post.fav_string)
        assert(Favorite.exists?(user_id: @user.id, post_id: @post.id))

        assert_raises(Favorite::Error) { FavoriteManager.add!(user: @user, post: @post) }
        @post.reload

        assert_equal("fav:#{@user.id}", @post.fav_string)
        assert(Favorite.exists?(user_id: @user.id, post_id: @post.id))

        FavoriteManager.remove!(user: @user, post: @post)
        @post.reload

        assert_equal("", @post.fav_string)
        assert_not(Favorite.exists?(user_id: @user.id, post_id: @post.id))

        FavoriteManager.remove!(user: @user, post: @post)
        @post.reload

        assert_equal("", @post.fav_string)
        assert_not(Favorite.exists?(user_id: @user.id, post_id: @post.id))
      end
    end

    context("Moving favorites to a parent post") do
      setup do
        @parent = create(:post)
        @child = create(:post, parent: @parent)

        @user1 = create(:user, enable_privacy_mode: true)
        @trusted1 = create(:trusted_user)
        @user2 = create(:user)

        FavoriteManager.add!(user: @user1, post: @child)
        FavoriteManager.add!(user: @trusted1, post: @child)
        FavoriteManager.add!(user: @user2, post: @child)
        FavoriteManager.add!(user: @user2, post: @parent)

        with_inline_jobs { @child.give_favorites_to_parent(@user) }
        @child.reload
        @parent.reload
      end

      should("move the favorites") do
        assert_equal(0, @child.fav_count)
        assert_equal(0, @child.favorites.count)
        assert_equal("", @child.fav_string)
        assert_equal([], @child.favorites.pluck(:user_id))

        assert_equal(3, @parent.fav_count)
        assert_equal(3, @parent.favorites.count)
      end
    end
  end

  context("Pools:") do
    context("Removing a post from a pool") do
      should("update the post's pool string") do
        post = create(:post)
        pool = create(:pool)
        pool.add!(post, @user)
        pool.remove!(post, @user)
        post.reload

        assert_equal("", post.pool_string)
        pool.remove!(post, @user)
        post.reload

        assert_equal("", post.pool_string)
      end
    end

    context("Adding a post to a pool") do
      should("update the post's pool string") do
        post = create(:post)
        pool = create(:pool)
        pool.add!(post, @user)
        post.reload

        assert_equal("pool:#{pool.id}", post.pool_string)
        pool.add!(post, @user)
        post.reload

        assert_equal("pool:#{pool.id}", post.pool_string)
        pool.remove!(post, @user)
        post.reload

        assert_equal("", post.pool_string)
      end
    end
  end

  context("Uploading:") do
    context("Uploading a post") do
      should("capture who uploaded the post") do
        post = create(:post)
        user1 = create(:user)
        user2 = create(:user)
        create(:user)

        post.uploader = user1

        assert_equal(user1.id, post.uploader_id)

        post.uploader_id = user2.id

        assert_equal(user2.id, post.uploader_id)
        assert_equal(user2.name, post.uploader_name)
      end

      context("tag post counts") do
        setup { @post = build(:post) }

        should("call Tag.increment_post_counts with the correct params") do
          Tag.expects(:increment_post_counts).once.with(%w[tag1 tag2])
          @post.save
        end
      end

      should("increment the uploaders post_upload_count") do
        assert_difference("@user.reload.post_upload_count") do
          create(:post, uploader: @user)
        end
      end
    end
  end

  context("Searching:") do
    should("return posts for the age:<1minute tag") do
      post = create(:post)

      assert_tag_match([post], "age:<1minute")
    end

    should("return posts for the age:<1minute tag when the user is in Pacific time zone") do
      post = create(:post)
      Time.zone = "Pacific Time (US & Canada)"

      assert_tag_match([post], "age:<1minute")
      Time.zone = "Eastern Time (US & Canada)"
    end

    should("return posts for the age:<1minute tag when the user is in Tokyo time zone") do
      post = create(:post)
      Time.zone = "Asia/Tokyo"

      assert_tag_match([post], "age:<1minute")
      Time.zone = "Eastern Time (US & Canada)"
    end

    should("return posts for the ' tag") do
      post1 = create(:post, tag_string: "'")
      create(:post, tag_string: "aaa bbb")

      assert_tag_match([post1], "'")
    end

    should("return posts for the ? tag") do
      post1 = create(:post, tag_string: "?")
      create(:post, tag_string: "aaa bbb")

      assert_tag_match([post1], "?")
    end

    should("return posts for 1 tag") do
      post1 = create(:post, tag_string: "aaa")
      post2 = create(:post, tag_string: "aaa bbb")
      create(:post, tag_string: "bbb ccc")

      assert_tag_match([post2, post1], "aaa")
    end

    should("return posts for a 2 tag join") do
      create(:post, tag_string: "aaa")
      post2 = create(:post, tag_string: "aaa bbb")
      create(:post, tag_string: "bbb ccc")

      assert_tag_match([post2], "aaa bbb")
    end

    should("return posts for a 2 tag union") do
      post1 = create(:post, tag_string: "aaa")
      create(:post, tag_string: "aaab bbb")
      post3 = create(:post, tag_string: "bbb ccc")

      assert_tag_match([post3, post1], "~aaa ~ccc")
    end

    should("return posts for 1 tag with exclusion") do
      post1 = create(:post, tag_string: "aaa")
      create(:post, tag_string: "aaa bbb")
      create(:post, tag_string: "bbb ccc")

      assert_tag_match([post1], "aaa -bbb")
    end

    should("return posts for 1 tag with a pattern") do
      post1 = create(:post, tag_string: "aaa")
      post2 = create(:post, tag_string: "aaab bbb")
      create(:post, tag_string: "bbb ccc")

      assert_tag_match([post2, post1], "a*")
    end

    should("return posts for 2 tags, one with a pattern") do
      create(:post, tag_string: "aaa")
      post2 = create(:post, tag_string: "aaab bbb")
      create(:post, tag_string: "bbb ccc")

      assert_tag_match([post2], "a* bbb")
    end

    should("return posts for the id:<N> metatag") do
      posts = create_list(:post, 3)

      assert_tag_match([posts[1]], "id:#{posts[1].id}")
      assert_tag_match([posts[2]], "id:>#{posts[1].id}")
      assert_tag_match([posts[0]], "id:<#{posts[1].id}")

      assert_tag_match([posts[2], posts[0]], "-id:#{posts[1].id}")
      assert_tag_match([posts[2], posts[1]], "id:>=#{posts[1].id}")
      assert_tag_match([posts[1], posts[0]], "id:<=#{posts[1].id}")
      assert_tag_match([posts[2], posts[0]], "id:#{posts[0].id},#{posts[2].id}")
      assert_tag_match(posts.reverse, "id:#{posts[0].id}..#{posts[2].id}")
    end

    should("return posts for the fav:<name> metatag") do
      users = create_list(:user, 2)
      posts = users.map do |u|
        post = create(:post, tag_string: "abc")
        FavoriteManager.add!(user: u, post: post)
        post
      end

      assert_tag_match([posts[0]], "fav:#{users[0].name}")
      assert_tag_match([posts[1]], "-fav:#{users[0].name}")
    end

    should("return posts for the pool:<name> metatag") do
      create(:pool, name: "test_a")
      create(:pool, name: "test_b")
      post1 = create(:post, tag_string: "pool:test_a")
      post2 = create(:post, tag_string: "pool:test_b")

      assert_tag_match([post1], "pool:test_a")
      assert_tag_match([post2], "-pool:test_a")
      assert_tag_match([], "-pool:test_a -pool:test_b")

      assert_tag_match([post2, post1], "pool:any")
      assert_tag_match([], "pool:none")
    end

    should("return posts for the parent:<N> metatag") do
      parent = create(:post)
      child = create(:post, tag_string: "parent:#{parent.id}")

      assert_tag_match([parent], "parent:none")
      assert_tag_match([child], "-parent:none")
      assert_tag_match([child], "parent:#{parent.id}")

      assert_tag_match([child], "child:none")
      assert_tag_match([parent], "child:any")
    end

    should("return posts for the user:<name> metatag") do
      users = create_list(:user, 2)
      posts = users.map { |u| create(:post, uploader: u) }

      assert_tag_match([posts[0]], "user:#{users[0].name}")
      assert_tag_match([posts[1]], "-user:#{users[0].name}")
    end

    should("return posts for the approver:<name> metatag") do
      users = create_list(:user, 2)
      posts = users.map { |u| create(:post, approver: u) }
      posts << create(:post, approver: nil)

      assert_tag_match([posts[0]], "approver:#{users[0].name}")
      assert_tag_match([posts[2], posts[1]], "-approver:#{users[0].name}")
      assert_tag_match([posts[1], posts[0]], "approver:any")
      assert_tag_match([posts[2]], "approver:none")
    end

    should("return posts for the commenter:<name> metatag") do
      users = create_list(:user, 2, created_at: 2.weeks.ago)
      posts = create_list(:post, 2)
      users.zip(posts).map { |u, p| create(:comment, post: p, creator: u) }

      assert_tag_match([posts[0]], "commenter:#{users[0].name}")
      assert_tag_match([posts[1]], "commenter:#{users[1].name}")
    end

    should("return posts for the commenter:<any|none> metatag") do
      posts = create_list(:post, 2)
      create(:comment, post: posts[0], is_hidden: false)
      create(:comment, post: posts[1], is_hidden: true)

      assert_tag_match([posts[0]], "commenter:any")
      assert_tag_match([posts[1]], "commenter:none")
    end

    should("Return posts for the disapprover:<name> metatag") do
      posts = create_list(:post, 3, is_pending: true)
      @user = create(:janitor_user)
      @user2 = create(:janitor_user)
      @user3 = create(:user)
      create(:post_disapproval, user: @user, post: posts[0], reason: "borderline_quality")
      create(:post_disapproval, user: @user2, post: posts[1], reason: "borderline_quality")
      create(:post_disapproval, user: @user2, post: posts[0], reason: "borderline_quality")

      # refuse to filter for non-approvers
      assert_tag_match(posts.reverse, "disapprover:#{@user.name}", @user3)
      assert_tag_match(posts.reverse, "disapprover:!#{@user.id}", @user3)

      assert_tag_match([posts[0]], "disapprover:#{@user.name}", @user)
      assert_tag_match([posts[0]], "disapprover:!#{@user.id}", @user)
    end

    should("Return posts for the disapprover:<any|none> metatag") do
      posts = create_list(:post, 3, is_pending: true)
      @user = create(:janitor_user)
      @user2 = create(:janitor_user)
      @user3 = create(:user)
      create(:post_disapproval, user: @user, post: posts[0], reason: "borderline_quality")
      create(:post_disapproval, user: @user2, post: posts[1], reason: "borderline_quality")
      create(:post_disapproval, user: @user2, post: posts[0], reason: "borderline_quality")

      assert_tag_match(posts.reverse, "disapprover:any", @user3)
      assert_tag_match(posts.reverse, "disapprover:none", @user3)

      assert_tag_match([posts[2]], "disapprover:none", @user) # TODO: !All
      assert_tag_match([posts[1], posts[0]], "disapprover:any", @user) # TODO: !none
    end

    should("Return posts for the disapprovals:<n> metatag") do
      posts = create_list(:post, 3, is_pending: true)
      @user = create(:janitor_user)
      @user2 = create(:janitor_user)
      @user3 = create(:user)
      create(:post_disapproval, user: @user, post: posts[0], reason: "borderline_quality")
      create(:post_disapproval, user: @user2, post: posts[1], reason: "borderline_quality")
      create(:post_disapproval, user: @user2, post: posts[0], reason: "borderline_quality")

      assert_tag_match(posts.reverse, "disapprovals:1", @user3)
      assert_tag_match(posts.reverse, "disapprovals:2", @user3)
      assert_tag_match(posts.reverse, "disapprovals:0", @user3)
      assert_tag_match(posts.reverse, "disapprovals:>=1", @user3)

      assert_tag_match([posts[1]], "disapprovals:1", @user)
      assert_tag_match([posts[0]], "disapprovals:2", @user)
      assert_tag_match([posts[2]], "disapprovals:0", @user)
      assert_tag_match([posts[1], posts[0]], "disapprovals:>=1", @user)
    end

    should("Return posts for the disapprovals:<any|none> metatag") do
      posts = create_list(:post, 3, is_pending: true)
      @user = create(:janitor_user)
      @user2 = create(:janitor_user)
      @user3 = create(:user)
      create(:post_disapproval, user: @user, post: posts[0], reason: "borderline_quality")
      create(:post_disapproval, user: @user2, post: posts[1], reason: "borderline_quality")
      create(:post_disapproval, user: @user2, post: posts[0], reason: "borderline_quality")

      assert_tag_match(posts.reverse, "disapprovals:any", @user3)
      assert_tag_match(posts.reverse, "disapprovals:none", @user3)

      assert_tag_match([posts[2]], "disapprovals:none", @user)
      assert_tag_match([posts[1], posts[0]], "disapprovals:any", @user)
    end

    should("return posts for the noter:<name> metatag") do
      users = create_list(:user, 2)
      posts = create_list(:post, 2)
      users.zip(posts).map { |u, p| create(:note, creator: u, post: p) }

      assert_tag_match([posts[0]], "noter:#{users[0].name}")
      assert_tag_match([posts[1]], "noter:#{users[1].name}")
    end

    should("return posts for the noter:<any|none> metatag") do
      posts = create_list(:post, 2)
      create(:note, post: posts[0], is_active: true)
      create(:note, post: posts[1], is_active: false)

      assert_tag_match([posts[0]], "noter:any")
      assert_tag_match([posts[1]], "noter:none")
    end

    should("return posts for the description:<text> metatag") do
      posts = create_list(:post, 2)
      posts[0].update_attribute(:description, "abc")
      posts[1].update_attribute(:description, "efg")

      assert_tag_match([posts[0]], "description:abc")
      assert_tag_match([posts[1]], "description:efg")
    end

    should("return posts for the date:<d> metatag") do
      post = create(:post, created_at: Time.parse("2017-01-01 12:00"))

      assert_tag_match([post], "date:2017-01-01")
    end

    should("return posts for the age:<n> metatag") do
      post = create(:post)

      assert_tag_match([post], "age:<60")
      assert_tag_match([post], "age:<60s")
      assert_tag_match([post], "age:<1mi")
      assert_tag_match([post], "age:<1h")
      assert_tag_match([post], "age:<1d")
      assert_tag_match([post], "age:<1w")
      assert_tag_match([post], "age:<1mo")
      assert_tag_match([post], "age:<1y")
    end

    should("return posts for the ratio:<x:y> metatag") do
      post = create(:post, media_asset: build(:random_upload_media_asset, image_width: 1000, image_height: 500))

      assert_tag_match([post], "ratio:2:1")
      assert_tag_match([post], "ratio:2.0")
    end

    should("return posts for the status:<type> metatag") do
      pending = create(:post, is_pending: true)
      flagged = create(:post, is_flagged: true)
      deleted = create(:post, is_deleted: true)
      all = [deleted, flagged, pending]

      assert_tag_match([flagged, pending], "status:modqueue")
      assert_tag_match([pending], "status:pending")
      assert_tag_match([flagged], "status:flagged")
      assert_tag_match([deleted], "status:deleted")
      assert_tag_match([], "status:active")
      assert_tag_match(all, "status:any")
      assert_tag_match(all, "status:all")

      # TODO: These don't quite make sense, what should hide deleted posts and what shouldn't?
      assert_tag_match(all - [deleted, flagged, pending], "-status:modqueue")
      assert_tag_match(all - [deleted, pending], "-status:pending")
      assert_tag_match(all - [deleted, flagged], "-status:flagged")

      assert_tag_match(all - [deleted], "-status:deleted")
      assert_tag_match(all, "-status:active")
    end

    should("hide unlisted posts from search unless searched for by status or id") do
      unlisted = create(:post, is_unlisted: true)
      listed = create(:post)
      all = [listed, unlisted]

      assert_tag_match([listed], "")
      assert_tag_match([unlisted], "status:unlisted")
      assert_tag_match(all, "status:any")
      assert_tag_match(all, "status:all")
      assert_tag_match([listed], "-status:unlisted")
      assert_tag_match([unlisted], "id:#{unlisted.id}")
    end

    should("hide in-progress posts from search unless searched for by status or id") do
      in_progress = create(:post, is_in_progress: true, tag_string: create(:artist_tag).name)
      listed = create(:post)
      all = [listed, in_progress]

      assert_tag_match([listed], "")
      assert_tag_match([in_progress], "status:in_progress")
      assert_tag_match(all, "status:any")
      assert_tag_match(all, "status:all")
      assert_tag_match([listed], "-status:in_progress")
      assert_tag_match([in_progress], "id:#{in_progress.id}")
    end

    should("return posts for the filetype:<ext> metatag") do
      png = create(:post, media_asset: build(:random_upload_media_asset, file_ext: "png"))
      jpg = create(:post, media_asset: build(:random_upload_media_asset, file_ext: "jpg"))

      assert_tag_match([png], "filetype:png")
      assert_tag_match([jpg], "-filetype:png")
    end

    should("return posts for the tagcount:<n> metatags") do
      @post = create(:post, tag_string: "artist:wokada copyright:vocaloid char:hatsune_miku twintails meta:hi lore:test_(lore) cont:test_(va) gender:male", uploader: create(:admin_user))

      assert_tag_match([@post], "tagcount:8")
      assert_tag_match([], "tagcount:9")
      assert_tag_match([@post], "arttags:1")
      assert_tag_match([@post], "copytags:1")
      assert_tag_match([@post], "chartags:1")
      assert_tag_match([@post], "gentags:1")
      assert_tag_match([@post], "metatags:1")
      assert_tag_match([@post], "lortags:1")
      assert_tag_match([@post], "conttags:1")
      assert_tag_match([@post], "gendertags:1")
      assert_tag_match([], "gentags:0")
    end

    should("return posts for the md5:<md5> metatag") do
      post1 = create(:post, media_asset: build(:random_upload_media_asset, md5: "abcd"))
      create(:post)

      assert_tag_match([post1], "md5:abcd")
    end

    should("return posts for a source search") do
      post1 = create(:post, source: "abcd")
      post2 = create(:post, source: "abcdefg")
      post3 = create(:post, source: "")

      assert_tag_match([post2], "source:abcde")
      assert_tag_match([post3, post1], "-source:abcde")

      assert_tag_match([post3], "source:none")
      assert_tag_match([post2, post1], "-source:none")
    end

    should("return posts for a case insensitive source search") do
      post1 = create(:post, source: "ABCD")
      create(:post, source: "1234")

      assert_tag_match([post1], "source:*abcd")
    end

    should("return posts for a pixiv source search") do
      url = "https://i1.pixiv.net/img123/img/artist-name/789.png"
      post = create(:post, source: url)

      assert_tag_match([post], "source:*.pixiv.net/img*/artist-name/*")
      assert_tag_match([],     "source:*.pixiv.net/img*/artist-fake/*")
      assert_tag_match([post], "source:https://*.pixiv.net/img*/img/artist-name/*")
      assert_tag_match([],     "source:https://*.pixiv.net/img*/img/artist-fake/*")
    end

    should("return posts for a rating:<s|q|e> metatag") do
      s = create(:post, rating: "s")
      q = create(:post, rating: "q")
      e = create(:post, rating: "e")
      all = [e, q, s]

      assert_tag_match([s], "rating:s")
      assert_tag_match([q], "rating:q")
      assert_tag_match([e], "rating:e")

      assert_tag_match(all - [s], "-rating:s")
      assert_tag_match(all - [q], "-rating:q")
      assert_tag_match(all - [e], "-rating:e")
    end

    should("return posts for a locked:<rating|note|status> metatag") do
      rating_locked = create(:post, is_rating_locked: true)
      note_locked   = create(:post, is_note_locked: true)
      status_locked = create(:post, is_status_locked: true)
      all = [status_locked, note_locked, rating_locked]

      assert_tag_match([rating_locked], "locked:rating")
      assert_tag_match([note_locked], "locked:note")
      assert_tag_match([status_locked], "locked:status")

      assert_tag_match(all - [rating_locked], "-locked:rating")
      assert_tag_match(all - [note_locked], "-locked:note")
      assert_tag_match(all - [status_locked], "-locked:status")
    end

    should("return posts for a upvote:<user>, downvote:<user> metatag") do
      old_user = create(:moderator_user, created_at: 5.days.ago)
      upvoted   = create(:post, tag_string: "abc")
      downvoted = create(:post, tag_string: "abc")
      VoteManager::Posts.vote!(user: old_user, ip_addr: "127.0.0.1", post: upvoted, score: 1)
      VoteManager::Posts.vote!(user: old_user, ip_addr: "127.0.0.1", post: downvoted, score: -1)

      assert_tag_match([upvoted],   "upvote:#{old_user.name}", old_user)
      assert_tag_match([downvoted], "downvote:#{old_user.name}", old_user)
    end

    # FIXME: This test fails randomly at different assertions
    should("return posts ordered by a particular attribute") do
      skip("fails randomly at different assertions")
      posts = (1..2).map do |n|
        tags = ["tagme", "gentag1 gentag2 artist:arttag char:chartag copy:copytag"]

        p = create(
          :post,
          score:        n,
          fav_count:    n,
          file_size:    1.megabyte * n,
          # posts[0] is portrait, posts[1] is landscape. posts[1].mpixels > posts[0].mpixels.
          image_height: 100 * n * n,
          image_width:  100 * (3 - n) * n,
          tag_string:   tags[n - 1],
        )

        create(:comment, post: p, do_not_bump_post: false)
        create(:note, post: p)
        p
      end

      create(:note, post: posts.second)

      assert_tag_match(posts.reverse, "order:id_desc")
      assert_tag_match(posts.reverse, "order:score")
      assert_tag_match(posts.reverse, "order:favcount")
      assert_tag_match(posts.reverse, "order:change")
      assert_tag_match(posts.reverse, "order:comment")
      assert_tag_match(posts.reverse, "order:comment_bumped")
      assert_tag_match(posts.reverse, "order:disapproval_desc")
      assert_tag_match(posts.reverse, "order:note")
      assert_tag_match(posts.reverse, "order:mpixels")
      assert_tag_match(posts.reverse, "order:portrait")
      assert_tag_match(posts.reverse, "order:filesize")
      assert_tag_match(posts.reverse, "order:tagcount")
      assert_tag_match(posts.reverse, "order:gentags")
      assert_tag_match(posts.reverse, "order:arttags")
      assert_tag_match(posts.reverse, "order:chartags")
      assert_tag_match(posts.reverse, "order:copytags")
      assert_tag_match(posts.reverse, "order:rank")
      assert_tag_match(posts.reverse, "order:note_count")
      assert_tag_match(posts.reverse, "order:note_count_desc")
      assert_tag_match(posts.reverse, "order:notes")
      assert_tag_match(posts.reverse, "order:notes_desc")

      assert_tag_match(posts, "order:id_asc")
      assert_tag_match(posts, "order:score_asc")
      assert_tag_match(posts, "order:favcount_asc")
      assert_tag_match(posts, "order:change_asc")
      assert_tag_match(posts, "order:comment_asc")
      assert_tag_match(posts, "order:comment_bumped_asc")
      assert_tag_match(posts, "order:disapproval_asc")
      assert_tag_match(posts, "order:note_asc")
      assert_tag_match(posts, "order:mpixels_asc")
      assert_tag_match(posts, "order:landscape")
      assert_tag_match(posts, "order:filesize_asc")
      assert_tag_match(posts, "order:tagcount_asc")
      assert_tag_match(posts, "order:gentags_asc")
      assert_tag_match(posts, "order:arttags_asc")
      assert_tag_match(posts, "order:chartags_asc")
      assert_tag_match(posts, "order:copytags_asc")
      assert_tag_match(posts, "order:note_count_asc")
      assert_tag_match(posts, "order:notes_asc")
    end

    should("return posts for order:comment_bumped") do
      post1 = create(:post)
      post2 = create(:post)
      post3 = create(:post)

      create(:comment, post: post1)
      create(:comment, post: post2, do_not_bump_post: true)
      create(:comment, post: post3)

      assert_tag_match([post3, post1], "order:comment_bumped")
      assert_tag_match([post1, post3], "order:comment_bumped_asc")

      create(:comment, post: post2)

      assert_tag_match([post2, post3, post1], "order:comment_bumped")
      assert_tag_match([post1, post3, post2], "order:comment_bumped_asc")
    end

    should("return posts for a filesize search") do
      post = create(:post, media_asset: create(:random_upload_media_asset, file_size: 1.megabyte))

      assert_tag_match([post], "filesize:1mb")
      assert_tag_match([post], "filesize:1000kb")
      assert_tag_match([post], "filesize:1048576b")
    end

    should("not count free tags against the user's search limit") do
      post1 = create(:post, tag_string: "aaa bbb rating:s")

      GayFurCity.config.expects(:is_unlimited_tag).with("rating:s").once.returns(true)
      GayFurCity.config.expects(:is_unlimited_tag).with(anything).twice.returns(false)

      assert_tag_match([post1], "aaa bbb rating:s")
    end

    should("succeed for exclusive tag searches with no other tag") do
      create(:post, rating: "s", tag_string: "aaa")
      assert_nothing_raised do
        Post.tag_match("-aaa", User.anonymous)
      end
    end

    should("succeed for exclusive tag searches combined with a metatag") do
      create(:post, rating: "s", tag_string: "aaa")
      assert_nothing_raised do
        Post.tag_match("-aaa id:>0", User.anonymous)
      end
    end

    should("return posts for verified artists") do
      assert_tag_match([], "artverified:true")
      assert_tag_match([], "artverified:false")
      artist = create(:artist, linked_user: @user)
      post = create(:post, tag_string: artist.name, uploader: @user)

      assert_tag_match([], "artverified:false")
      assert_tag_match([post], "artverified:true")
      assert_tag_match([], "~artverified:false")
      assert_tag_match([post], "~artverified:true")
      assert_tag_match([], "-artverified:true")
      assert_tag_match([post], "-artverified:false")
    end

    should("return posts for verified artists after update") do
      assert_tag_match([], "artverified:true")
      assert_tag_match([], "artverified:false")
      post = create(:post, tag_string: "artist:test", uploader: @user)
      with_inline_jobs { create(:artist, name: "test", linked_user: @user) }

      assert_tag_match([], "artverified:false")
      assert_tag_match([post], "artverified:true")
    end

    should("return posts for replacements") do
      assert_tag_match([], "pending_replacements:true")
      assert_tag_match([], "pending_replacements:false")
      post = create(:post)
      create(:png_replacement, creator: @user, post: post)

      assert_tag_match([post], "pending_replacements:true")
    end

    should("return no posts when the replacement is not pending anymore") do
      post1 = create(:post)
      upload = create(:gif_upload, uploader: @user, tag_string: "tst")
      post2 = upload.post
      post3 = create(:post)
      post4 = create(:post)
      replacement1 = create(:png_replacement, creator: @user, post: post1)
      replacement1.reject!(@user)
      replacement2 = create(:png_replacement, creator: @user, post: post2)
      replacement2.approve!(@user, penalize_current_uploader: true)
      replacement3 = create(:jpg_replacement, creator: @user, post: post3)
      promoted_post = replacement3.promote!(@user).post
      replacement4 = create(:webm_replacement, creator: @user, post: post4)
      replacement4.destroy_with!(@user)

      assert_tag_match([], "pending_replacements:true")
      assert_tag_match([promoted_post, post4, post3, post2, post1], "pending_replacements:false")
      assert_tag_match([], "-pending_replacements:false")
      assert_tag_match([promoted_post, post4, post3, post2, post1], "-pending_replacements:true")
      assert_tag_match([], "~pending_replacements:true")
      assert_tag_match([promoted_post, post4, post3, post2, post1], "~pending_replacements:false")
    end

    should("not error for values beyond Integer.MAX_VALUE") do
      assert_tag_match([], "id:1234567890987654321")
    end

    context("() tag groups") do
      should("require every tag in a ( a b ) group to match") do
        post1 = create(:post, tag_string: "solo duo")
        create(:post, tag_string: "solo")

        assert_tag_match([post1], "( solo duo )")
      end

      should("forbid every tag in a -( a b ) group from all matching at once") do
        post1 = create(:post, tag_string: "solo")
        post2 = create(:post, tag_string: "duo")
        create(:post, tag_string: "solo duo")

        assert_tag_match([post2, post1], "-( solo duo )")
      end

      should("match if any tag in a ~( a b ) group matches") do
        post1 = create(:post, tag_string: "solo")
        post2 = create(:post, tag_string: "duo")
        create(:post, tag_string: "trio")

        assert_tag_match([post2, post1], "~( solo ) ~( duo )")
      end

      should("allow metatags inside a () group") do
        post1 = create(:post, tag_string: "solo", rating: "s")
        create(:post, tag_string: "solo", rating: "e")

        assert_tag_match([post1], "( rating:s solo )")
      end

      should("combine a () group with tags outside it") do
        post1 = create(:post, tag_string: "solo duo trio")
        create(:post, tag_string: "solo duo")

        assert_tag_match([post1], "trio ( solo duo )")
      end

      should("not mistake a tag's own literal parentheses for a group") do
        create(:tag, name: "fluffy_(oc)", category: TagCategory.character)
        post1 = create(:post, tag_string: "fluffy_(oc)")
        create(:post, tag_string: "solo")

        assert_tag_match([post1], "fluffy_(oc)")
      end

      should("support arbitrarily nested () groups") do
        post1 = create(:post, tag_string: "solo duo")
        post2 = create(:post, tag_string: "solo trio")
        create(:post, tag_string: "solo")

        # ~ inside the nested group makes each of its own tags optional (OR) - ~( duo trio )
        # would instead mean the *whole* (duo trio) (AND'd) group is optional relative to solo.
        assert_tag_match([post2, post1], "( solo ( ~duo ~trio ) )")
      end
    end
  end

  context("Voting:") do
    setup do
      @user = create(:trusted_user, created_at: 7.days.ago)
      @post = create(:post)
    end

    should("not allow duplicate votes") do
      assert_nothing_raised { VoteManager::Posts.vote!(user: @user, ip_addr: "127.0.0.1", post: @post, score: 1) }
      # Need unvote is returned upon duplicates that are accounted for.
      assert_equal(:need_unvote, VoteManager::Posts.vote!(user: @user, ip_addr: "127.0.0.1", post: @post, score: 1)[1])
      @post.reload

      assert_equal(1, PostVote.count)
      assert_equal(1, @post.score)
    end

    should("allow undoing of votes") do
      # We deliberately don't call post.reload until the end to verify that
      # post.unvote! returns the correct score even when not forcibly reloaded.
      VoteManager::Posts.vote!(post: @post, user: @user, ip_addr: "127.0.0.1", score: 1)

      assert_equal(1, @post.score)

      VoteManager::Posts.unvote!(post: @post, user: @user)

      assert_equal(0, @post.score)

      assert_nothing_raised { VoteManager::Posts.vote!(post: @post, user: @user, ip_addr: "127.0.0.1", score: -1) }
      assert_equal(-1, @post.score)

      VoteManager::Posts.unvote!(post: @post, user: @user)

      assert_equal(0, @post.score)

      assert_nothing_raised { VoteManager::Posts.vote!(post: @post, user: @user, ip_addr: "127.0.0.1", score: 1) }
      assert_equal(1, @post.score)

      @post.reload

      assert_equal(1, @post.score)
    end

    should("periodically clean the vote_string") do
      @post.update_columns(vote_string: "down:1 locked:1 up:1", score: -1)
      @post.append_user_to_vote_string(2, "down")

      assert_same_elements(%w[down:1 down:2], @post.vote_string.split)
      assert_equal(-2, @post.score)
    end

    should("update the vote strings on the post") do
      VoteManager::Posts.vote!(user: @user, ip_addr: "127.0.0.1", post: @post, score: 1)
      @post.reload

      assert_equal("up:#{@user.id}", @post.vote_string)
      assert(PostVote.exists?(user_id: @user.id, post_id: @post.id))

      VoteManager::Posts.vote!(user: @user, ip_addr: "127.0.0.1", post: @post, score: 1)
      @post.reload

      assert_equal("up:#{@user.id}", @post.vote_string)
      assert(PostVote.exists?(user_id: @user.id, post_id: @post.id))

      VoteManager::Posts.unvote!(user: @user, post: @post)
      @post.reload

      assert_equal("", @post.vote_string)
      assert_not(PostVote.exists?(user_id: @user.id, post_id: @post.id))

      VoteManager::Posts.unvote!(user: @user, post: @post)
      @post.reload

      assert_equal("", @post.vote_string)
      assert_not(PostVote.exists?(user_id: @user.id, post_id: @post.id))
    end

    context("Moving votes to a parent post") do
      setup do
        GayFurCity.config.stubs(:disable_age_checks).returns(true)
        @parent = create(:post)
        @child = create(:post, parent: @parent)

        @user1 = create(:user, enable_privacy_mode: true)
        @trusted1 = create(:trusted_user)
        @user2 = create(:user)
        @user3 = create(:user)

        VoteManager::Posts.vote!(user: @user1, ip_addr: "127.0.0.1", post: @child, score: 1)
        VoteManager::Posts.vote!(user: @trusted1, ip_addr: "127.0.0.1", post: @child, score: -1)
        VoteManager::Posts.vote!(user: @user2, ip_addr: "127.0.0.1", post: @child, score: -1)
        VoteManager::Posts.vote!(user: @user2, ip_addr: "127.0.0.1", post: @parent, score: -1)

        with_inline_jobs { @child.give_votes_to_parent(@user) }
        @child.reload
        @parent.reload
      end

      should("move the votes") do
        assert_equal(0, @child.score)
        assert_equal(0, @child.votes.count)
        assert_equal("", @child.vote_string)
        assert_equal([], @child.votes.pluck(:user_id))

        assert_equal(-1, @parent.score)
        assert_equal(3, @parent.votes.count)
        assert_same_elements(%W[down:#{@user2.id} up:#{@user1.id} down:#{@trusted1.id}], @parent.vote_string.split)
      end

      should("not move locked votes") do
        vote, _status = VoteManager::Posts.vote!(user: @user3, ip_addr: "127.0.0.1", post: @child, score: 1)
        VoteManager::Posts.lock!(vote.id, create(:admin_user))
        with_inline_jobs { @child.give_votes_to_parent(@user) }

        assert_equal(1, @child.votes.count)
        assert_equal([@user3.id], @child.votes.pluck(:user_id))

        assert_equal(3, @parent.votes.count)
      end
    end
  end

  context("Reverting: ") do
    context("a post that is rating locked") do
      setup do
        @user = create(:trusted_user)
        @post = create(:post, rating: "s")
        @post.update_with(@user, rating: "q", is_rating_locked: true)
      end

      should("not revert the rating") do
        @post.revert_to!(@post.versions.first, @user)

        assert_not(@post.valid?)
        assert_equal(["Rating is locked and cannot be changed. Unlock the post first."], @post.errors.full_messages)
        assert_equal(@post.versions.last.rating, @post.reload.rating)
      end

      should("revert the rating after unlocking") do
        @post.update_with(@user, rating: "e", is_rating_locked: false)
        @post.revert_to!(@post.versions.first, @user)

        assert_predicate(@post, :valid?)
        assert_equal(@post.versions.first.rating, @post.rating)
      end
    end

    context("a post that has been updated") do
      setup do
        @post = create(:post, rating: "q", tag_string: "aaa", source: "")
        @post.reload
        @post.update_with(@user, tag_string: "aaa bbb ccc ddd")
        @post.reload
        @post.update_with(@user, tag_string: "bbb xxx yyy", source: "xyz")
        @post.reload
        @post.update_with(@user, tag_string: "bbb mmm yyy", source: "abc")
        @post.reload
      end

      context("and then reverted to an early version") do
        setup do
          @version = @post.versions.second
          @post.revert_to!(@version, @user)
          @post.reload
        end

        should("correctly revert all fields") do
          assert_equal("aaa bbb ccc ddd", @post.tag_string)
          assert_equal("", @post.source)
          assert_equal("q", @post.rating)
          assert_equal("Revert to version #{@version.version}", @post.versions.last.reason)
        end
      end

      context("and then reverted to a later version") do
        setup do
          @post.revert_to(@post.versions[-2])
        end

        should("correctly revert all fields") do
          assert_equal("bbb invalid_source xxx yyy", @post.tag_string)
          assert_equal("xyz", @post.source)
          assert_equal("q", @post.rating)
        end
      end
    end
  end

  context("URLs:") do
    should("generate the correct urls for animated gifs") do
      @post = build(:post, tag_string: "animated_gif", media_asset: build(:random_upload_media_asset, md5: "deadbeef", file_ext: "gif"))

      assert_equal("#{GayFurCity.config.hostname}/data/posts/preview/deadbeef.webp", @post.preview_file_url(@user))
      assert_raises(MediaAssetWithVariants::VariantNotFoundError) { @post.large_file_url(@user) }
      assert_equal("#{GayFurCity.config.hostname}/data/posts/deadbeef.gif", @post.file_url(@user))
    end
  end

  context("Notes:") do
    context("#copy_notes_to") do
      setup do
        @src = create(:post, tag_string: "translated partially_translated", media_asset: build(:random_upload_media_asset, image_width: 100, image_height: 100))
        @dst = create(:post, tag_string: "translation_request", media_asset: build(:random_upload_media_asset, image_width: 200, image_height: 200))

        create(:note, x: 10, y: 10, width: 10, height: 10, body: "test", post: @src)
        create(:note, x: 10, y: 10, width: 10, height: 10, body: "deleted", is_active: false, post: @src)
        @src.reload

        @src.copy_notes_to(@dst, @user)
      end

      should("copy notes and tags") do
        assert_equal(1, @dst.notes.active.length)
        assert_equal("low_res partially_translated thumbnail translated", @dst.tag_string)
      end

      should("rescale notes") do
        note = @dst.notes.active.first

        assert_equal([20, 20, 20, 20], [note.x, note.y, note.width, note.height])
      end
    end
  end

  context("Metatags:") do
    context("set:") do
      setup do
        @set = create(:post_set, creator: @user)
        @post = create(:post)
      end

      context("with an id") do
        should("work") do
          @post.update_with(@user, tag_string_diff: "set:#{@set.id}")

          assert_equal([@post.id], @set.reload.post_ids)
          assert_equal("set:#{@set.id}", @post.pool_string)
        end

        should("gracefully fail if the set is full") do
          AdminConfig.stubs(:get_with_bypass).with(:set_post_limit, @user).returns(0)
          @post.update_with(@user, tag_string_diff: "set:#{@set.id}")

          assert_equal(["Sets can only have up to 0 posts each"], @post.errors.full_messages)
          assert_equal([], @set.reload.post_ids)
          assert_equal("", @post.pool_string)
        end
      end

      context("with a shortname") do
        should("work") do
          @post.update_with(@user, tag_string_diff: "set:#{@set.shortname}")

          assert_equal([@post.id], @set.reload.post_ids)
          assert_equal("set:#{@set.id}", @post.pool_string)
        end

        should("gracefully fail if the set is full") do
          AdminConfig.stubs(:get_with_bypass).with(:set_post_limit, @user).returns(0)
          @post.update_with(@user, tag_string_diff: "set:#{@set.shortname}")

          assert_equal(["Sets can only have up to 0 posts each"], @post.errors.full_messages)
          assert_equal([], @set.reload.post_ids)
          assert_equal("", @post.pool_string)
        end
      end
    end

    context("pool:") do
      setup do
        @pool = create(:pool)
        @pool2 = create(:pool, name: "Test_Pool")
        @post = create(:post)
      end

      context("with an id") do
        should("work") do
          @post.update_with(@user, tag_string_diff: "pool:#{@pool.id}")

          assert_equal([@post.id], @pool.reload.post_ids)
          assert_equal("pool:#{@pool.id}", @post.pool_string)
        end

        should("gracefully fail if the pool is full") do
          AdminConfig.stubs(:get_with_bypass).with(:pool_post_limit, @user).returns(0)
          @post.update_with(@user, tag_string_diff: "pool:#{@pool.id}")

          assert_equal(["Pools can only have up to 0 posts each"], @post.errors.full_messages)
          assert_equal([], @pool.reload.post_ids)
          assert_equal("", @post.pool_string)
        end
      end

      context("with a name") do
        should("work") do
          @post.update_with(@user, tag_string_diff: "pool:#{@pool.name}")

          assert_equal([@post.id], @pool.reload.post_ids)
          assert_equal("pool:#{@pool.id}", @post.pool_string)
        end

        should("work with capital letters") do
          @post.update_with(@user, tag_string_diff: "pool:#{@pool2.name}")

          assert_equal([@post.id], @pool2.reload.post_ids)
          assert_equal("pool:#{@pool2.id}", @post.pool_string)
        end

        should("gracefully fail if the pool is full") do
          AdminConfig.stubs(:get_with_bypass).with(:pool_post_limit, @user).returns(0)
          @post.update_with(@user, tag_string_diff: "pool:#{@pool.name}")

          assert_equal(["Pools can only have up to 0 posts each"], @post.errors.full_messages)
          assert_equal([], @pool.reload.post_ids)
          assert_equal("", @post.pool_string)
        end
      end
    end

    context("newpool:") do
      setup do
        @post = create(:post)
      end

      should("work") do
        assert_difference("Pool.count", 1) do
          @post.update_with(@user, tag_string_diff: "newpool:test")
        end
        @pool = Pool.last

        assert_equal([@post.id], @pool.reload.post_ids)
        assert_equal("pool:#{@pool.id}", @post.pool_string)
        assert_equal("test", @pool.name)
      end

      should("work with capital letters") do
        assert_difference("Pool.count", 1) do
          @post.update_with(@user, tag_string_diff: "newpool:Test2_Pool")
        end
        @pool = Pool.last

        assert_equal([@post.id], @pool.reload.post_ids)
        assert_equal("pool:#{@pool.id}", @post.pool_string)
        assert_equal("Test2_Pool", @pool.name)
      end
    end
  end

  context("Character groups:") do
    setup do
      create(:tag, name: "fluffy_(oc)", category: TagCategory.character)
      create(:tag, name: "rex_(oc)", category: TagCategory.character)
    end

    should("populate character_groups from character_groups_attributes, folding the tags into tag_string") do
      post = create(:post, tag_string: "solo")
      save_with_groups(post, [{ characters: ["fluffy_(oc)"], tags: ["blue_eyes"] }], "solo")

      assert_equal([{ "tags" => %w[fluffy_(oc) blue_eyes] }], post.character_groups)
      assert_includes(post.tag_string.split, "blue_eyes")
      assert_includes(post.tag_string.split, "fluffy_(oc)")
    end

    should("preserve existing groups on a plain edit that doesn't resubmit character_groups_attributes") do
      post = create(:post, tag_string: "solo")
      save_with_groups(post, [{ characters: ["fluffy_(oc)"], tags: ["blue_eyes"] }], "solo")

      post.updater = @janitor
      post.ungrouped_tag_string = "solo new_tag"
      post.save!

      assert_equal([{ "tags" => %w[fluffy_(oc) blue_eyes] }], post.character_groups)
      assert_includes(post.tag_string.split, "new_tag")
    end

    should("clear groups (while leaving their tags on the post as general tags) when character_groups_attributes is explicitly empty") do
      post = create(:post, tag_string: "solo")
      save_with_groups(post, [{ characters: ["fluffy_(oc)"], tags: ["blue_eyes"] }], "solo")

      post.updater = @janitor
      post.character_groups_attributes = []
      post.ungrouped_tag_string = post.tag_string
      post.save!

      assert_empty(post.character_groups)
      assert_includes(post.tag_string.split, "blue_eyes")
      assert_includes(post.tag_string.split, "fluffy_(oc)")
    end

    should("actually remove a tag when it's dropped from ungrouped_tag_string") do
      post = create(:post, tag_string: "solo")
      save_with_groups(post, [], "solo duo")

      post.updater = @janitor
      post.character_groups_attributes = []
      post.ungrouped_tag_string = "solo"
      post.save!

      assert_equal("solo", post.tag_string)
    end

    should("allow the same tag to be attributed to more than one character") do
      post = create(:post, tag_string: "duo")
      save_with_groups(post, [
        { characters: ["fluffy_(oc)"], tags: ["blue_eyes"] },
        { characters: ["rex_(oc)"], tags: ["blue_eyes"] },
      ], "duo")

      assert_equal(1, post.tag_string.split.count("blue_eyes"))
      assert_equal(2, post.character_groups.size)
      assert(post.character_groups.all? { |g| g["tags"].include?("blue_eyes") })
    end

    should("resolve an aliased tag to its canonical name within a group") do
      create(:tag_alias, antecedent_name: "old_name", consequent_name: "blue_eyes")
      post = create(:post, tag_string: "solo")
      save_with_groups(post, [{ characters: ["fluffy_(oc)"], tags: ["old_name"] }], "solo")

      assert_equal([{ "tags" => %w[fluffy_(oc) blue_eyes] }], post.character_groups)
    end

    should("sweep a grouped tag's implications into the same group") do
      create(:tag, name: "domestic_cat", category: TagCategory.species)
      create(:tag, name: "felid", category: TagCategory.species)
      create(:tag_implication, antecedent_name: "domestic_cat", consequent_name: "felid")
      post = create(:post, tag_string: "solo")
      save_with_groups(post, [{ characters: ["fluffy_(oc)"], tags: ["domestic_cat"] }], "solo")

      assert_equal([{ "tags" => %w[fluffy_(oc) domestic_cat felid] }], post.character_groups)
    end

    should("drop artist, meta, and invalid category tags out of a group into the ungrouped tags") do
      create(:tag, name: "some_artist", category: TagCategory.artist)
      create(:tag, name: "some_meta")
      create(:tag, name: "some_invalid")
      Tag.where(name: "some_meta").update_all(category: TagCategory.meta)
      Tag.where(name: "some_invalid").update_all(category: TagCategory.invalid)
      post = create(:post, tag_string: "solo")
      save_with_groups(post, [{ characters: ["fluffy_(oc)"], tags: %w[blue_eyes some_artist some_meta some_invalid] }], "solo")

      assert_equal([{ "tags" => %w[fluffy_(oc) blue_eyes] }], post.character_groups)
      assert_includes(post.ungrouped_tags, "some_artist")
      assert_includes(post.ungrouped_tags, "some_meta")
      assert_includes(post.ungrouped_tags, "some_invalid")
    end

    should("prune a tag from its group when it's force-removed by locked tags") do
      post = create(:post, tag_string: "solo")
      save_with_groups(post, [{ characters: ["fluffy_(oc)"], tags: ["blue_eyes"] }], "solo")

      post.updater = @janitor
      post.locked_tags = "-blue_eyes"
      post.save!

      assert_equal([{ "tags" => ["fluffy_(oc)"] }], post.character_groups)
    end

    should("not attribute a locked-tag force-add to any existing group") do
      post = create(:post, tag_string: "solo")
      save_with_groups(post, [{ characters: ["fluffy_(oc)"], tags: ["blue_eyes"] }], "solo")

      post.updater = @janitor
      post.locked_tags = "forced_tag"
      post.save!

      assert_includes(post.ungrouped_tags, "forced_tag")
      assert_not_includes(post.character_groups.flat_map { |g| g["tags"] }, "forced_tag")
    end

    should("parse {} groups embedded directly in tag_string, for API/manual editing") do
      post = create(:post, tag_string: "solo {fluffy_(oc) blue_eyes} digital_media_(artwork)")

      assert_equal([{ "tags" => %w[fluffy_(oc) blue_eyes] }], post.character_groups)
      assert_not_includes(post.tag_string, "{")
      assert_includes(post.tag_string.split, "fluffy_(oc)")
      assert_includes(post.tag_string.split, "blue_eyes")
    end

    should("reject tag_string with unbalanced or nested {} groups") do
      post = build(:post, tag_string: "solo {fluffy_(oc) blue_eyes")

      assert_not(post.valid?)
      assert_predicate(post.errors[:tag_string], :present?)
    end

    should("keep group membership when a grouped tag is renamed via an approved alias") do
      post = create(:post, tag_string: "solo")
      save_with_groups(post, [{ characters: ["fluffy_(oc)"], tags: ["blue_eyes"] }], "solo")

      with_inline_jobs do
        create(:tag_alias, antecedent_name: "blue_eyes", consequent_name: "azure_eyes").approve!(@janitor)
      end
      post.reload

      assert_equal([{ "tags" => %w[fluffy_(oc) azure_eyes] }], post.character_groups)
    end

    context("#character_groups_for_api") do
      should("split each group's character tags from its attribute tags") do
        post = create(:post, tag_string: "solo")
        save_with_groups(post, [{ characters: ["fluffy_(oc)"], tags: %w[blue_eyes smiling] }], "solo")

        result = post.character_groups_for_api

        assert_equal(1, result.size)
        assert_equal(["fluffy_(oc)"], result.first[:characters])
        assert_equal(%w[blue_eyes smiling].sort, result.first[:tags].sort)
      end

      should("treat a group with no character-category tag as anonymous (empty characters)") do
        post = create(:post, tag_string: "solo")
        save_with_groups(post, [{ characters: [], tags: ["waving"] }], "solo")

        result = post.character_groups_for_api

        assert_equal([], result.first[:characters])
        assert_equal(["waving"], result.first[:tags])
      end
    end

    context("#ungrouped_tags") do
      should("exclude every tag attributed to a character") do
        post = create(:post, tag_string: "solo")
        save_with_groups(post, [{ characters: ["fluffy_(oc)"], tags: ["blue_eyes"] }], "solo")

        assert_equal(["solo"], post.ungrouped_tags)
      end
    end
  end
end

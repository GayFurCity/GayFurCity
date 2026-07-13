# frozen_string_literal: true

require("test_helper")

class TagAliasTest < ActiveSupport::TestCase
  def assert_undo_data(tag_alias, name, **values)
    tag_alias.reload
    data = tag_alias.undo_data.find { |d| d.first == name.to_s }

    assert(data, "undo data for #{name} not found")
    assert_equal(values.transform_keys(&:to_s), data[1])
  end

  context("A tag alias") do
    setup do
      @admin = create(:admin_user)

      @user = create(:user, created_at: 1.month.ago)
    end

    context("on validation") do
      subject do
        create(:tag, name: "aaa")
        create(:tag, name: "bbb")
        create(:tag_alias, antecedent_name: "aaa", consequent_name: "bbb", status: "active")
      end

      should(allow_value("active").for(:status))
      should(allow_value("deleted").for(:status))
      should(allow_value("pending").for(:status))
      should(allow_value("processing").for(:status))
      should(allow_value("queued").for(:status))
      should(allow_value("error: derp").for(:status))

      should_not(allow_value("ACTIVE").for(:status))
      should_not(allow_value("error").for(:status))
      should_not(allow_value("derp").for(:status))

      should(allow_value(nil).for(:forum_topic_id))
      should_not(allow_value(-1).for(:forum_topic_id).with_message("must exist", against: :forum_topic))

      should(allow_value(nil).for(:approver_id))
      should_not(allow_value(-1).for(:approver_id).with_message("must exist", against: :approver))

      should_not(allow_value(nil).for(:creator_id))
      should_not(allow_value(-1).for(:creator_id).with_message("must exist", against: :creator))

      should("not allow duplicate active aliases") do
        ta1 = create(:tag_alias)

        assert_predicate(ta1, :valid?)

        assert_raises(ActiveRecord::RecordInvalid) do
          create(:tag_alias, status: "pending")
        end
      end
    end

    context("#estimate_update_count") do
      resets_post_index!

      setup do
        create(:post, tag_string: "aaa bbb ccc")
        @alias = create(:tag_alias, antecedent_name: "aaa", consequent_name: "bbb", status: "pending")
      end

      should("get the right count") do
        assert_equal(1, @alias.estimate_update_count)
      end
    end

    context("#approvable_by?") do
      setup do
        @mod = create(:moderator_user)
        @owner = create(:owner_user)
        @ta = create(:tag_alias, status: "pending", creator: @user)
        @dnp = create(:avoid_posting, creator: @owner)
        @ta2 = create(:tag_alias, antecedent_name: @dnp.artist_name, consequent_name: "ccc", status: "pending", creator: @user)
        @ta3 = create(:tag_alias, antecedent_name: "ddd", consequent_name: @dnp.artist_name, status: "pending", creator: @user)
      end

      should("not allow creator") do
        assert_not(@ta.approvable_by?(@user))
      end

      should("allow admins") do
        assert(@ta.approvable_by?(@admin))
      end

      should("now allow mods") do
        assert_not(@ta.approvable_by?(@mod))
      end

      should("not allow admins if antecedent/consequent is dnp") do
        assert_not(@ta2.approvable_by?(@admin))
        assert_not(@ta3.approvable_by?(@admin))
      end

      should("allow owner") do
        assert(@ta2.approvable_by?(@owner))
        assert(@ta3.approvable_by?(@owner))
      end
    end

    context("#rejectable_by?") do
      setup do
        @user = create(:user)
        @mod = create(:moderator_user)
        @ta = create(:tag_alias, status: "pending", creator: @user)
      end

      should("allow creator") do
        assert(@ta.rejectable_by?(@user))
      end

      should("allow admins") do
        assert(@ta.rejectable_by?(@admin))
      end

      should("now allow mods") do
        assert_not(@ta.rejectable_by?(@mod))
      end
    end

    should("populate the creator information") do
      ta = create(:tag_alias, antecedent_name: "aaa", consequent_name: "bbb", creator: @user)

      assert_equal(@user.id, ta.creator_id)
    end

    should("convert a tag to its normalized version") do
      create(:tag, name: "aaa")
      create(:tag, name: "bbb")
      create(:tag_alias, antecedent_name: "aaa", consequent_name: "bbb")

      assert_equal(["bbb"], TagAlias.to_aliased("aaa"))
      assert_equal(%w[bbb ccc], TagAlias.to_aliased(%w[aaa ccc]))
      assert_equal(%w[ccc bbb], TagAlias.to_aliased(%w[ccc bbb]))
      assert_equal(["bbb"], TagAlias.to_aliased(%w[aaa aaa]))
    end

    should("update any affected posts when saved") do
      post1 = create(:post, tag_string: "aaa bbb eee")
      post2 = create(:post, tag_string: "ccc ddd eee")

      ta = create(:tag_alias, antecedent_name: "aaa", consequent_name: "ccc")
      ta2 = create(:tag_alias, antecedent_name: "eee", consequent_name: "fff")
      assert_difference("PostVersion.count", 2) do
        with_inline_jobs do
          ta.approve!(@admin)
          ta2.approve!(@admin)
        end
      end

      assert_equal("bbb ccc fff", post1.reload.tag_string)
      assert_equal("ccc ddd fff", post2.reload.tag_string)
      assert_undo_data(ta, :update_post_tags, ids: [post1.id], old: "aaa", new: "ccc")
    end

    should("not validate for transitive relations") do
      create(:tag_alias, antecedent_name: "bbb", consequent_name: "ccc")
      assert_difference("TagAlias.count", 0) do
        ta2 = build(:tag_alias, antecedent_name: "aaa", consequent_name: "bbb", creator: @user)
        ta2.save

        assert_predicate(ta2.errors, :any?, "Tag alias should be invalid")
        assert_equal("A tag alias for bbb already exists", ta2.errors.full_messages.join)
      end
    end

    should("move existing aliases") do
      ta1 = create(:tag_alias, antecedent_name: "aaa", consequent_name: "bbb", status: "pending")
      ta2 = create(:tag_alias, antecedent_name: "bbb", consequent_name: "ccc", status: "pending")
      with_inline_jobs do
        ta1.approve!(@admin)
        ta2.approve!(@admin)
      end

      assert_equal("ccc", ta1.reload.consequent_name)
      assert_undo_data(ta2, :update_tag_alias_consequent_name, id: ta1.id, old: "bbb", new: "ccc")
    end

    should("move existing implications") do
      ti = create(:tag_implication, antecedent_name: "aaa", consequent_name: "bbb")
      ta = create(:tag_alias, antecedent_name: "bbb", consequent_name: "ccc")
      with_inline_jobs { ta.approve!(@admin) }

      assert_equal("ccc", ti.reload.consequent_name)
      assert_undo_data(ta, :update_tag_implication_consequent_name, id: ti.id, old: "bbb", new: "ccc")
    end

    should("not push the antecedent's category to the consequent if the antecedent is general") do
      create(:tag, name: "aaa")
      tag2 = create(:artist_tag, name: "bbb")
      ta = create(:tag_alias, antecedent_name: "aaa", consequent_name: "bbb")
      tag2.reload

      assert_equal(TagCategory.artist, tag2.category)
      assert_not_includes(ta.reload.undo_data.map(&:first), "update_tag_category")
    end

    should("not push the antecedent's category to the consequent if the consequent is non-general") do
      create(:artist_tag, name: "aaa")
      tag2 = create(:copyright_tag, name: "bbb")
      ta = create(:tag_alias, antecedent_name: "aaa", consequent_name: "bbb")
      with_inline_jobs { ta.approve!(@admin) }

      assert_equal(TagCategory.copyright, tag2.reload.category)
      assert_not_includes(ta.reload.undo_data.map(&:first), "update_tag_category")
    end

    should("push the antecedent's category to the consequent") do
      tag = create(:artist_tag, name: "aaa")
      tag2 = create(:tag, name: "bbb")
      old = tag2.category
      ta = create(:tag_alias, antecedent_name: "aaa", consequent_name: "bbb")
      with_inline_jobs { ta.approve!(@admin) }

      assert_equal(TagCategory.artist, tag2.reload.category)
      assert_equal("alias ##{ta.id} (aaa -> bbb)", TagVersion.last.reason)
      assert_undo_data(ta, :update_tag_category, id: tag2.id, old: old, new: tag.category)
    end

    should("not push the antecedent's category if the consequent is locked") do
      create(:artist_tag, name: "aaa")
      tag2 = create(:copyright_tag, name: "bbb", is_locked: true)
      ta = create(:tag_alias, antecedent_name: "aaa", consequent_name: "bbb")
      with_inline_jobs { ta.approve!(@admin) }

      assert_equal(TagCategory.copyright, tag2.reload.category)
      assert_not_includes(ta.reload.undo_data.map(&:first), "update_tag_category")
    end

    should("update artist name") do
      artist = create(:artist, name: "aaa")
      ta = create(:tag_alias, antecedent_name: "aaa", consequent_name: "bbb")
      Tag.find_by!(name: "bbb").update(category: TagCategory.artist) # avoid the category being carried down
      with_inline_jobs { ta.approve!(@admin) }

      assert_equal("bbb", artist.reload.name)
      assert_undo_data(ta, :update_artist_name, id: artist.id, old: "aaa", new: "bbb")
    end

    should("not fail if an artist with the same name is locked") do
      ta = create(:tag_alias, antecedent_name: "aaa", consequent_name: "bbb")
      artist = create(:artist, name: "aaa", is_locked: true, creator: @admin)
      Tag.find_by!(name: "bbb").update(category: TagCategory.artist) # avoid the category being carried down
      artist.tag.update(category: TagCategory.artist)

      with_inline_jobs { ta.approve!(@admin) }

      assert_equal("active", ta.reload.status)
      assert_equal("bbb", artist.reload.name)
      assert_undo_data(ta, :update_artist_name, id: artist.id, old: "aaa", new: "bbb")
    end

    should("update wiki page title") do
      wiki = create(:wiki_page, title: "aaa")
      ta = create(:tag_alias, antecedent_name: "aaa", consequent_name: "bbb")
      with_inline_jobs { ta.approve!(@admin) }

      assert_equal("bbb", wiki.reload.title)
      assert_undo_data(ta, :update_wiki_page_title, id: wiki.id, old: "aaa", new: "bbb")
    end

    should("error on approve if it is not valid anymore") do
      create(:tag_alias, antecedent_name: "aaa", consequent_name: "bbb", status: "active")
      ta = build(:tag_alias, antecedent_name: "aaa", consequent_name: "bbb", status: "pending", creator: @admin)
      ta.save(validate: false)
      with_inline_jobs { ta.approve!(@admin) }

      assert_match("error", ta.reload.status)
    end

    should("allow rejecting if an active duplicate exists") do
      create(:tag_alias, antecedent_name: "aaa", consequent_name: "bbb", status: "active")
      ta = build(:tag_alias, antecedent_name: "aaa", consequent_name: "bbb", status: "pending", creator: @admin)
      ta.save(validate: false)
      ta.reject!(@admin)

      assert_equal("deleted", ta.reload.status)
    end

    should("allow rejecting if an active transitive exists") do
      create(:tag_alias, antecedent_name: "aaa", consequent_name: "bbb", status: "active")
      ta = build(:tag_alias, antecedent_name: "bbb", consequent_name: "aaa", status: "pending", creator: @admin)
      ta.save(validate: false)
      ta.reject!(@admin)

      assert_equal("deleted", ta.reload.status)
    end

    should("update locked tags on approve") do
      ta = create(:tag_alias, antecedent_name: "aaa", consequent_name: "bbb", status: "pending")
      post1 = create(:post, locked_tags: "aaa foo")
      post2 = create(:post, locked_tags: "-aaa foo")
      with_inline_jobs { ta.approve!(@admin) }

      ta.reload

      assert_equal("bbb foo", post1.reload.locked_tags)
      assert_equal("-bbb foo", post2.reload.locked_tags)
      assert_undo_data(ta, :update_post_tags, ids: [post1.id], old: "aaa", new: "bbb")
      assert_undo_data(ta, :update_post_locked_tags, ids: [post1.id, post2.id], old: "aaa", new: "bbb")
    end

    should("update blacklists when approved") do
      ta = create(:tag_alias, antecedent_name: "aaa", consequent_name: "bbb", status: "pending")
      user = create(:user, blacklisted_tags: "foo aaa bar")
      with_inline_jobs { ta.approve!(@admin) }

      assert_equal("foo bbb bar", user.reload.blacklisted_tags)
      assert_undo_data(ta, :update_blacklists, old: "aaa", new: "bbb")
    end

    should("rewrite wiki page body links") do
      ta = create(:tag_alias, antecedent_name: "aaa", consequent_name: "bbb", status: "pending")
      wiki = create(:wiki_page, body: "abc [[aaa]] def\nghi")
      with_inline_jobs { ta.approve!(@admin) }
      wiki.reload

      assert_equal("abc [[bbb]] def\nghi", wiki.body)
      assert_undo_data(ta, :update_wiki_page_body, id: wiki.id, old: "aaa", new: "bbb")
    end

    should("rewrite pool description links") do
      ta = create(:tag_alias, antecedent_name: "aaa", consequent_name: "bbb", status: "pending")
      pool = create(:pool, description: "abc [[aaa]] def\nghi")
      with_inline_jobs { ta.approve!(@admin) }
      pool.reload

      assert_equal("abc [[bbb]] def\nghi", pool.description)
      assert_undo_data(ta, :update_pool_description, id: pool.id, old: "aaa", new: "bbb")
    end

    should("update tag followers") do
      ta = create(:tag_alias, antecedent_name: "aaa", consequent_name: "bbb", status: "pending")
      follower = create(:tag_follower, tag: Tag.find_by(name: "aaa"))
      with_inline_jobs { ta.approve!(@admin) }
      follower.reload

      assert_equal("bbb", follower.tag_name)
      assert_undo_data(ta, :update_tag_follower, id: follower.id, old: "aaa", new: "bbb")
    end

    context("with an associated forum topic") do
      setup do
        @admin = create(:admin_user)
        @topic = create(:forum_topic, title: TagAliasRequest.topic_title("aaa", "bbb"))
        @post = create(:forum_post, topic_id: @topic.id, body: "Reason: test")
        @alias = create(:tag_alias, antecedent_name: "aaa", consequent_name: "bbb", forum_topic: @topic, forum_post: @post, status: "pending")
      end

      should("update the topic when processed") do
        assert_difference("ForumPost.count") do
          with_inline_jobs { @alias.approve!(@admin) }
        end
      end

      should("update the parent post") do
        previous = @post.body
        with_inline_jobs { @alias.approve!(@admin) }
        @post.reload

        assert_not_equal(previous, @post.body)
      end

      should("update the topic when rejected") do
        assert_difference("ForumPost.count") do
          @alias.reject!(@admin)
        end
      end

      should("update the topic when failed") do
        TagMover.any_instance.stubs(:update_blacklists!).raises(Exception, "oh no")
        with_inline_jobs { @alias.approve!(@admin) }
        @topic.reload
        @alias.reload

        assert_equal("[FAILED] Tag alias: aaa -> bbb", @topic.title)
        assert_match(/error: oh no/, @alias.status)
        assert_match(/The tag alias .* failed during processing/, @topic.posts.last.body)
      end
    end

    context("undo!") do
      should("undo update_tag_category") do
        create(:tag, name: "aaa", category: TagCategory.copyright)
        tag = create(:tag, name: "bbb")
        ta = create(:tag_alias, antecedent_name: "aaa", consequent_name: "bbb", status: "pending")
        with_inline_jobs { ta.approve!(@admin) }

        assert_equal(TagCategory.copyright, tag.reload.category)
        assert_not_equal([], ta.reload.undo_data)
        with_inline_jobs { ta.undo!(@admin) }

        assert_equal(TagCategory.general, tag.reload.category)
        assert_equal([], ta.reload.undo_data)
      end

      should("undo update_artist_name") do
        artist = create(:artist, name: "aaa")
        ta = create(:tag_alias, antecedent_name: "aaa", consequent_name: "bbb", status: "pending")
        with_inline_jobs { ta.approve!(@admin) }

        assert_equal("bbb", artist.reload.name)
        assert_not_equal([], ta.reload.undo_data)
        with_inline_jobs { ta.undo!(@admin) }

        assert_equal("aaa", artist.reload.name)
        assert_equal([], ta.reload.undo_data)
      end

      should("undo update_wiki_page_title") do
        wiki = create(:wiki_page, title: "aaa")
        ta = create(:tag_alias, antecedent_name: "aaa", consequent_name: "bbb", status: "pending")
        with_inline_jobs { ta.approve!(@admin) }

        assert_equal("bbb", wiki.reload.title)
        assert_not_equal([], ta.reload.undo_data)
        with_inline_jobs { ta.undo!(@admin) }

        assert_equal("aaa", wiki.reload.title)
        assert_equal([], ta.reload.undo_data)
      end

      should("undo update_post_tags") do
        post = create(:post, tag_string: "aaa")
        ta = create(:tag_alias, antecedent_name: "aaa", consequent_name: "bbb", status: "pending")
        with_inline_jobs { ta.approve!(@admin) }

        assert_equal("bbb", post.reload.tag_string)
        assert_not_equal([], ta.reload.undo_data)
        with_inline_jobs { ta.undo!(@admin) }

        assert_equal("aaa", post.reload.tag_string)
        assert_equal([], ta.reload.undo_data)
      end

      should("undo update_post_locked_tags") do
        post1 = create(:post, locked_tags: "aaa ccc")
        post2 = create(:post, locked_tags: "-aaa ccc")
        ta = create(:tag_alias, antecedent_name: "aaa", consequent_name: "bbb", status: "pending")
        with_inline_jobs { ta.approve!(@admin) }

        assert_equal("bbb ccc", post1.reload.locked_tags)
        assert_equal("-bbb ccc", post2.reload.locked_tags)
        assert_not_equal([], ta.reload.undo_data)
        with_inline_jobs { ta.undo!(@admin) }

        assert_equal("aaa ccc", post1.reload.locked_tags)
        assert_equal("-aaa ccc", post2.reload.locked_tags)
        assert_equal([], ta.reload.undo_data)
      end

      should("undo update_tag_alias_consequent_name") do
        ta1 = create(:tag_alias, antecedent_name: "aaa", consequent_name: "bbb", status: "pending")
        ta2 = create(:tag_alias, antecedent_name: "bbb", consequent_name: "ccc", status: "pending")
        with_inline_jobs do
          ta1.approve!(@admin)
          ta2.approve!(@admin)
        end

        assert_equal("ccc", ta1.reload.consequent_name)
        assert_not_equal([], ta2.reload.undo_data)
        with_inline_jobs { ta2.undo!(@admin) }

        assert_equal("bbb", ta1.reload.consequent_name)
        assert_equal([], ta2.reload.undo_data)
      end

      should("undo destroy_tag_alias") do
        skip("Unreachable via TagAlias#approve!: triggering this requires an active reverse alias (Q -> P) to already exist before approving P -> Q, but absence_of_transitive_relation re-validates on every save of the alias being approved (including TagAlias#process!'s own status update), so the approval itself is rejected once a conflicting active reverse alias exists. This path is only reachable via BulkUpdateRequestCommands::Rename, which moves tags without saving a TagAlias record and so records its undo data on the BUR command, not on a TagAlias.")
      end

      should("undo update_tag_implication_antecedent_name") do
        ti = create(:tag_implication, antecedent_name: "aaa", consequent_name: "bbb")
        ta = create(:tag_alias, antecedent_name: "aaa", consequent_name: "ccc", status: "pending")
        with_inline_jobs do
          ta.approve!(@admin)
        end

        assert_equal("ccc", ti.reload.antecedent_name)
        assert_not_equal([], ta.reload.undo_data)
        with_inline_jobs { ta.undo!(@admin) }

        assert_equal("aaa", ti.reload.antecedent_name)
        assert_equal([], ta.reload.undo_data)
      end

      should("undo update_tag_implication_consequent_name") do
        ti = create(:tag_implication, antecedent_name: "aaa", consequent_name: "bbb")
        ta = create(:tag_alias, antecedent_name: "bbb", consequent_name: "ccc", status: "pending")
        with_inline_jobs do
          ta.approve!(@admin)
        end

        assert_equal("ccc", ti.reload.consequent_name)
        assert_not_equal([], ta.reload.undo_data)
        with_inline_jobs { ta.undo!(@admin) }

        assert_equal("bbb", ti.reload.consequent_name)
        assert_equal([], ta.reload.undo_data)
      end

      should("undo destroy_tag_implication") do
        ti = create(:tag_implication, antecedent_name: "aaa", consequent_name: "bbb")
        ta = create(:tag_alias, antecedent_name: "aaa", consequent_name: "bbb", status: "pending")
        with_inline_jobs { ta.approve!(@admin) }

        assert_not(TagImplication.exists?(id: ti.id))
        assert_not_equal([], ta.reload.undo_data)
        with_inline_jobs { ta.undo!(@admin) }

        assert(TagImplication.active.exists?(antecedent_name: "aaa", consequent_name: "bbb"))
        assert_equal([], ta.reload.undo_data)
      end

      should("undo update_blacklists") do
        user = create(:user, blacklisted_tags: "abc aaa def\nghi")
        ta = create(:tag_alias, antecedent_name: "aaa", consequent_name: "bbb", status: "pending")
        with_inline_jobs do
          ta.approve!(@admin)
        end

        assert_equal("abc bbb def\nghi", user.reload.blacklisted_tags)
        assert_not_equal([], ta.reload.undo_data)
        with_inline_jobs { ta.undo!(@admin) }

        assert_equal("abc aaa def\nghi", user.reload.blacklisted_tags)
        assert_equal([], ta.reload.undo_data)
      end

      should("undo rewrite_wiki_page_body") do
        wiki = create(:wiki_page, body: "abc [[aaa]] def\nghi")
        ta = create(:tag_alias, antecedent_name: "aaa", consequent_name: "bbb", status: "pending")
        with_inline_jobs do
          ta.approve!(@admin)
        end

        assert_equal("abc [[bbb]] def\nghi", wiki.reload.body)
        assert_not_equal([], ta.reload.undo_data)
        with_inline_jobs { ta.undo!(@admin) }

        assert_equal("abc [[aaa]] def\nghi", wiki.reload.body)
        assert_equal([], ta.reload.undo_data)
      end

      should("undo rewrite_pool_description") do
        pool = create(:pool, description: "abc [[aaa]] def\nghi")
        ta = create(:tag_alias, antecedent_name: "aaa", consequent_name: "bbb", status: "pending")
        with_inline_jobs do
          ta.approve!(@admin)
        end

        assert_equal("abc [[bbb]] def\nghi", pool.reload.description)
        assert_not_equal([], ta.reload.undo_data)
        with_inline_jobs { ta.undo!(@admin) }

        assert_equal("abc [[aaa]] def\nghi", pool.reload.description)
        assert_equal([], ta.reload.undo_data)
      end

      should("undo update_tag_follower") do
        follower = create(:tag_follower, tag: create(:tag, name: "aaa"))
        ta = create(:tag_alias, antecedent_name: "aaa", consequent_name: "bbb", status: "pending")
        with_inline_jobs do
          ta.approve!(@admin)
        end

        assert_equal("bbb", follower.reload.tag_name)
        assert_not_equal([], ta.reload.undo_data)
        with_inline_jobs { ta.undo!(@admin) }

        assert_equal("aaa", follower.reload.tag_name)
        assert_equal([], ta.reload.undo_data)
      end
    end
  end
end

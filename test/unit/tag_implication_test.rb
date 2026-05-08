# frozen_string_literal: true

require("test_helper")

class TagImplicationTest < ActiveSupport::TestCase
  context("A tag implication") do
    setup do
      @admin = create(:admin_user)
      @user = create(:user, created_at: 1.month.ago)
    end

    context("on validation") do
      subject do
        create(:tag, name: "aaa")
        create(:tag, name: "bbb")
        create(:tag_implication, antecedent_name: "aaa", consequent_name: "bbb")
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

      should("not allow duplicate active implications") do
        create(:tag_implication, antecedent_name: "aaa", consequent_name: "bbb", status: "pending")
        ti2 = build(:tag_implication, antecedent_name: "aaa", consequent_name: "bbb", status: "active")
        ti2.save

        assert_match(/Antecedent name has already been taken/, ti2.errors.full_messages.join)
      end
    end

    context("#estimate_update_count") do
      setup do
        reset_post_index
        create(:post, tag_string: "aaa bbb ccc")
        @implication = create(:tag_implication, antecedent_name: "aaa", consequent_name: "bbb", status: "pending")
      end

      should("get the right count") do
        assert_equal(1, @implication.estimate_update_count)
      end
    end

    context("#approvable_by?") do
      setup do
        @mod = create(:moderator_user)
        @owner = create(:owner_user)
        @ti = create(:tag_implication, status: "pending", creator: @user)
        @dnp = create(:avoid_posting, creator: @owner)
        @ti2 = create(:tag_implication, antecedent_name: @dnp.artist_name, consequent_name: "ccc", status: "pending", creator: @user)
        @ti3 = create(:tag_implication, antecedent_name: "ddd", consequent_name: @dnp.artist_name, status: "pending", creator: @user)
      end

      should("not allow creator") do
        assert_not(@ti.approvable_by?(@user))
      end

      should("allow admins") do
        assert(@ti.approvable_by?(@admin))
      end

      should("now allow mods") do
        assert_not(@ti.approvable_by?(@mod))
      end

      should("not allow admins if antecedent/consequent is dnp") do
        assert_not(@ti2.approvable_by?(@admin))
        assert_not(@ti3.approvable_by?(@admin))
      end

      should("allow owner") do
        assert(@ti2.approvable_by?(@owner))
        assert(@ti3.approvable_by?(@owner))
      end
    end

    context("#rejectable_by?") do
      setup do
        @mod = create(:moderator_user)
        @ti = create(:tag_implication, status: "pending", creator: @user)
      end

      should("allow creator") do
        assert(@ti.rejectable_by?(@user))
      end

      should("allow admins") do
        assert(@ti.rejectable_by?(@admin))
      end

      should("now allow mods") do
        assert_not(@ti.rejectable_by?(@mod))
      end
    end

    should("ignore pending implications when building descendant names") do
      ti2 = build(:tag_implication, antecedent_name: "b", consequent_name: "c", status: "pending")
      ti2.save
      ti1 = create(:tag_implication, antecedent_name: "a", consequent_name: "b")

      assert_equal(%w[b], ti1.descendant_names)
    end

    should("populate the creator information") do
      ti = create(:tag_implication, antecedent_name: "aaa", consequent_name: "bbb", creator: @admin)

      assert_equal(@admin.id, ti.creator_id)
    end

    should("ensure both tags exist") do
      create(:tag_implication, antecedent_name: "a", consequent_name: "b")

      assert(Tag.exists?(name: "a"))
      assert(Tag.exists?(name: "b"))
    end

    should("not validate when a tag directly implicates itself") do
      ti = build(:tag_implication, antecedent_name: "a", consequent_name: "a")

      assert_predicate(ti, :invalid?)
      assert_includes(ti.errors[:base], "Cannot implicate a tag to itself")
    end

    should("not validate when a circular relation is created") do
      ti1 = create(:tag_implication, antecedent_name: "aaa", consequent_name: "bbb")
      ti2 = create(:tag_implication, antecedent_name: "bbb", consequent_name: "ccc")
      ti3 = build(:tag_implication, antecedent_name: "bbb", consequent_name: "aaa", creator: @user)

      assert_predicate(ti1, :valid?)
      assert_predicate(ti2, :valid?)
      assert_not(ti3.valid?)
      assert_equal("Tag implication cannot create a circular relation with another tag implication", ti3.errors.full_messages.join)
    end

    should("not validate when a transitive relation is created") do
      create(:tag_implication, antecedent_name: "a", consequent_name: "b")
      create(:tag_implication, antecedent_name: "b", consequent_name: "c")
      ti_ac = build(:tag_implication, antecedent_name: "a", consequent_name: "c", creator: @user)
      ti_ac.save

      assert_equal("a already implies c through another implication", ti_ac.errors.full_messages.join)
    end

    should("not allow for duplicates") do
      create(:tag_implication, antecedent_name: "aaa", consequent_name: "bbb")
      ti2 = build(:tag_implication, antecedent_name: "aaa", consequent_name: "bbb")
      ti2.save

      assert_predicate(ti2.errors, :any?, "Tag implication should not have validated.")
      assert_includes(ti2.errors.full_messages, "Antecedent name has already been taken")
    end

    should("not validate if its antecedent or consequent are aliased to another tag") do
      create(:tag_alias, antecedent_name: "aaa", consequent_name: "a")
      create(:tag_alias, antecedent_name: "bbb", consequent_name: "b")
      ti = build(:tag_implication, antecedent_name: "aaa", consequent_name: "bbb")

      assert_predicate(ti, :invalid?)
      assert_includes(ti.errors[:base], "Antecedent tag must not be aliased to another tag")
      assert_includes(ti.errors[:base], "Consequent tag must not be aliased to another tag")
    end

    should("allow rejecting if active aliases exist") do
      create(:tag_alias, antecedent_name: "aaa", consequent_name: "bbb")
      ti = build(:tag_implication, antecedent_name: "aaa", consequent_name: "bbb", status: "pending", creator: @user)
      ti.save(validate: false)

      ti.reject!(@admin)

      assert_equal("deleted", ti.reload.status)
    end

    should("calculate all its descendants") do
      ti1 = create(:tag_implication, antecedent_name: "bbb", consequent_name: "ccc")

      assert_equal(%w[ccc], ti1.descendant_names)
      ti2 = create(:tag_implication, antecedent_name: "aaa", consequent_name: "bbb")

      assert_equal(%w[bbb ccc], ti2.descendant_names)
      ti1.reload

      assert_equal(%w[ccc], ti1.descendant_names)
    end

    should("update its descendants on save") do
      ti1 = create(:tag_implication, antecedent_name: "aaa", consequent_name: "bbb", status: "active")
      ti2 = create(:tag_implication, antecedent_name: "ccc", consequent_name: "ddd", status: "active")
      ti1.reload
      ti2.reload
      ti2.update(
        antecedent_name: "bbb",
      )
      ti1.reload
      ti2.reload

      assert_equal(%w[bbb ddd], ti1.descendant_names)
      assert_equal(%w[ddd], ti2.descendant_names)
    end

    should("update the descendants for all of its parents on destroy") do
      ti1 = create(:tag_implication, antecedent_name: "aaa", consequent_name: "bbb")
      ti2 = create(:tag_implication, antecedent_name: "xxx", consequent_name: "bbb")
      ti3 = create(:tag_implication, antecedent_name: "bbb", consequent_name: "ccc")
      ti4 = create(:tag_implication, antecedent_name: "ccc", consequent_name: "ddd")
      ti1.reload
      ti2.reload
      ti3.reload
      ti4.reload

      assert_equal(%w[bbb ccc ddd], ti1.descendant_names)
      assert_equal(%w[bbb ccc ddd], ti2.descendant_names)
      assert_equal(%w[ccc ddd], ti3.descendant_names)
      assert_equal(%w[ddd], ti4.descendant_names)
      ti3.destroy
      ti1.reload
      ti2.reload
      ti4.reload

      assert_equal(%w[bbb], ti1.descendant_names)
      assert_equal(%w[bbb], ti2.descendant_names)
      assert_equal(%w[ddd], ti4.descendant_names)
    end

    should("update the descendants for all of its parents on create") do
      ti1 = create(:tag_implication, antecedent_name: "aaa", consequent_name: "bbb")
      ti1.reload

      assert_equal("active", ti1.status)
      assert_equal(%w[bbb], ti1.descendant_names)

      ti2 = create(:tag_implication, antecedent_name: "bbb", consequent_name: "ccc")
      ti1.reload
      ti2.reload

      assert_equal("active", ti1.status)
      assert_equal("active", ti2.status)
      assert_equal(%w[bbb ccc], ti1.descendant_names)
      assert_equal(%w[ccc], ti2.descendant_names)

      ti3 = create(:tag_implication, antecedent_name: "ccc", consequent_name: "ddd")
      ti1.reload
      ti2.reload
      ti3.reload

      assert_equal(%w[bbb ccc ddd], ti1.descendant_names)
      assert_equal(%w[ccc ddd], ti2.descendant_names)

      ti4 = create(:tag_implication, antecedent_name: "ccc", consequent_name: "eee")
      ti1.reload
      ti2.reload
      ti3.reload
      ti4.reload

      assert_equal(%w[bbb ccc ddd eee], ti1.descendant_names)
      assert_equal(%w[ccc ddd eee], ti2.descendant_names)
      assert_equal(%w[ddd], ti3.descendant_names)
      assert_equal(%w[eee], ti4.descendant_names)

      ti5 = create(:tag_implication, antecedent_name: "xxx", consequent_name: "bbb")
      ti1.reload
      ti2.reload
      ti3.reload
      ti4.reload
      ti5.reload

      assert_equal(%w[bbb ccc ddd eee], ti1.descendant_names)
      assert_equal(%w[ccc ddd eee], ti2.descendant_names)
      assert_equal(%w[ddd], ti3.descendant_names)
      assert_equal(%w[eee], ti4.descendant_names)
      assert_equal(%w[bbb ccc ddd eee], ti5.descendant_names)
    end

    should("update any affected post when saved") do
      p1 = create(:post, tag_string: "aaa bbb ccc")
      ti1 = create(:tag_implication, antecedent_name: "aaa", consequent_name: "xxx")
      ti2 = create(:tag_implication, antecedent_name: "aaa", consequent_name: "yyy")
      assert_difference("PostVersion.count", 1) do
        with_inline_jobs do
          ti1.approve!(@admin)
          ti2.approve!(@admin)
        end
      end

      assert_equal("aaa bbb ccc xxx yyy", p1.reload.tag_string)
    end

    should("error on approve if its not valid anymore") do
      create(:tag_implication, antecedent_name: "aaa", consequent_name: "bbb", status: "active")
      ti = build(:tag_implication, antecedent_name: "aaa", consequent_name: "bbb", status: "pending", creator: @user)
      ti.save(validate: false)
      with_inline_jobs { ti.approve!(@admin) }

      assert_match("error", ti.reload.status)
    end

    should("ignore tag count limits on approve") do
      Config.any_instance.stubs(:max_tags_per_post).returns(5)
      ti = create(:tag_implication, antecedent_name: "5", consequent_name: "6", status: "pending")
      post = create(:post, tag_string: "1 2 3 4 5")
      with_inline_jobs { ti.approve!(@admin) }

      assert_equal("1 2 3 4 5 6", post.reload.tag_string)
    end

    context("with an associated forum topic") do
      setup do
        @admin = create(:admin_user)
        @topic = create(:forum_topic, title: TagImplicationRequest.topic_title("aaa", "bbb"))
        @post = create(:forum_post, topic_id: @topic.id, body: "Reason: test")
        @implication = create(:tag_implication, antecedent_name: "aaa", consequent_name: "bbb", forum_topic: @topic, forum_post: @post, status: "pending")
      end

      should("update the topic when processed") do
        assert_difference("ForumPost.count") do
          with_inline_jobs { @implication.approve!(@admin) }
        end
        @post.reload
        @topic.reload

        assert_match(/The tag implication .* has been approved/, @post.body)
        assert_equal("[APPROVED] Tag implication: aaa -> bbb", @topic.title)
      end

      should("update the topic when rejected") do
        assert_difference("ForumPost.count") do
          @implication.reject!(@user)
        end
        @post.reload
        @topic.reload

        assert_match(/The tag implication .* has been rejected/, @post.body)
        assert_equal("[REJECTED] Tag implication: aaa -> bbb", @topic.title)
      end
    end
  end
end

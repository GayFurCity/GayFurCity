# frozen_string_literal: true

require("test_helper")

class PostVersionTest < ActiveSupport::TestCase
  context("A post") do
    setup do
      @user = create(:user, created_at: 1.month.ago)
    end

    context("that has multiple versions: ") do
      setup do
        @post = create(:post, tag_string: "1", uploader: @user)
        @post.update_with(@user, tag_string: "1 2")
        @post.update_with(@user, tag_string: "2 3")
      end

      context("a version record") do
        setup do
          @version = PostVersion.last
        end

        should("know its previous version") do
          assert_not_nil(@version.previous)
          assert_equal("1 2", @version.previous.tags)
        end
      end

      should("undo the changes") do
        version = @post.versions.second
        version.undo!(@user)
        @post.reload

        assert_equal("3", @post.tag_string)
        assert_equal("Undo of version #{version.version}", @post.versions.last.reason)
      end
    end

    context("that is tagged with a pool:<name> metatag") do
      setup do
        @pool = create(:pool)
        @post = create(:post, tag_string: "tagme pool:#{@pool.id}")
      end

      should("create a version") do
        assert_equal("tagme", @post.tag_string)
        assert_equal("pool:#{@pool.id}", @post.pool_string)

        assert_equal(1, @post.versions.size)
        assert_equal("tagme", @post.versions.last.tags)
      end
    end

    context("that has been created") do
      setup do
        @parent = create(:post)
        @post = create(:post, tag_string: "aaa bbb ccc", rating: "e", parent: @parent, source: "xyz")
      end

      should("also create a version") do
        assert_equal(1, @post.versions.size)
        @version = @post.versions.last

        assert_equal("aaa bbb ccc invalid_source", @version.tags)
        assert_equal(@post.rating, @version.rating)
        assert_equal(@post.parent_id, @version.parent_id)
        assert_equal(@post.source, @version.source)
      end
    end

    context("that has been updated") do
      setup do
        @post = create(:post, tag_string: "aaa bbb ccc", rating: "q", source: "xyz")
        @post.update_with(@user, tag_string: "bbb ccc xxx", source: "")
      end

      should("also create a version") do
        assert_equal(2, @post.versions.size)
        @version = @post.versions.last

        assert_equal("bbb ccc xxx", @version.tags)
        assert_equal("q", @version.rating)
        assert_equal("", @version.source)
        assert_nil(@version.parent_id)
      end

      should("not create a version if updating the post fails") do
        @post.stubs(:update_typed_tags).raises(NotImplementedError)

        assert_equal(2, @post.versions.size)
        assert_raise(NotImplementedError) { @post.update_with(@user, tag_string: "zzz") }
        assert_equal(2, @post.versions.size)
      end

      should("should create a version if the rating changes") do
        assert_difference("@post.versions.size", 1) do
          @post.update_with(@user, rating: "s")

          assert_equal("s", @post.versions.last.rating)
        end
      end

      should("should create a version if the source changes") do
        assert_difference("@post.versions.size", 1) do
          @post.update_with(@user, source: "blah")

          assert_equal("blah", @post.versions.last.source)
        end
      end

      should("should create a version if the parent changes") do
        assert_difference("@post.versions.size", 1) do
          @parent = create(:post)
          @post.update_with(@user, parent_id: @parent.id)

          assert_equal(@parent.id, @post.versions.last.parent_id)
        end
      end

      should("should create a version if the tags change") do
        assert_difference("@post.versions.size", 1) do
          @post.update_with(@user, tag_string: "blah")

          assert_equal("blah", @post.versions.last.tags)
        end
      end
    end
  end

  context("Character groups:") do
    setup do
      @user = create(:user, created_at: 1.month.ago)
      create(:tag, name: "fluffy_(oc)", category: TagCategory.character)
      @post = create(:post, tag_string: "solo")
      @v1 = @post.versions.last
    end

    should("create a new version for a pure re-grouping edit that doesn't change tag_string") do
      @post.update_with(@user, ungrouped_tag_string: "solo fluffy_(oc) blue_eyes")
      base_tag_string = @post.tag_string

      assert_difference("@post.versions.size", 1) do
        @post.update_with(@user, character_groups_attributes: [{ characters: ["fluffy_(oc)"], tags: ["blue_eyes"] }], ungrouped_tag_string: base_tag_string)
      end
    end

    should("record character_groups on the version") do
      @post.update_with(@user, character_groups_attributes: [{ characters: ["fluffy_(oc)"], tags: ["blue_eyes"] }], ungrouped_tag_string: "solo")

      assert_equal([{ "tags" => %w[fluffy_(oc) blue_eyes] }], @post.versions.last.character_groups)
    end

    context("#tag_rows") do
      should("show a row for a new named character with row_status :added") do
        @post.update_with(@user, character_groups_attributes: [{ characters: ["fluffy_(oc)"], tags: ["blue_eyes"] }], ungrouped_tag_string: "solo")
        v2 = @post.versions.last

        rows = v2.tag_rows(@v1)
        character_row = rows.find { |r| r[:label] == "fluffy_(oc)" }

        assert_equal(:added, character_row[:row_status])
        assert_equal(%w[blue_eyes fluffy_(oc)], character_row[:added].map { |t| t[:name] }.sort)
      end

      should("attribute a tag added to an existing character without re-flagging the character as added") do
        @post.update_with(@user, character_groups_attributes: [{ characters: ["fluffy_(oc)"], tags: [] }], ungrouped_tag_string: "solo")
        v2 = @post.versions.last

        @post.update_with(@user, character_groups_attributes: [{ characters: ["fluffy_(oc)"], tags: ["blue_eyes"] }], ungrouped_tag_string: @post.ungrouped_tags.join(" "))
        v3 = @post.versions.last

        rows = v3.tag_rows(v2)
        character_row = rows.find { |r| r[:label] == "fluffy_(oc)" }

        assert_nil(character_row[:row_status])
        assert_equal(["blue_eyes"], character_row[:added].map { |t| t[:name] })
      end

      should("not show a character row at all when its group is cleared but its tags stay on the post (just ungrouped)") do
        @post.update_with(@user, character_groups_attributes: [{ characters: ["fluffy_(oc)"], tags: ["blue_eyes"] }], ungrouped_tag_string: "solo")
        v2 = @post.versions.last

        @post.update_with(@user, character_groups_attributes: [], ungrouped_tag_string: @post.tag_string)
        v3 = @post.versions.last

        rows = v3.tag_rows(v2)

        assert_nil(rows.find { |r| r[:label] == "fluffy_(oc)" })
        general_row = rows.find { |r| r[:label].nil? }

        assert_includes(general_row[:unchanged], "blue_eyes")
        assert_includes(general_row[:unchanged], "fluffy_(oc)")
      end

      should("show row_status :removed when a character's tags are dropped from the post in the same edit that clears its group") do
        @post.update_with(@user, character_groups_attributes: [{ characters: ["fluffy_(oc)"], tags: ["blue_eyes"] }], ungrouped_tag_string: "solo")
        v2 = @post.versions.last

        @post.update_with(@user, character_groups_attributes: [], ungrouped_tag_string: "solo")
        v3 = @post.versions.last

        rows = v3.tag_rows(v2)
        character_row = rows.find { |r| r[:label] == "fluffy_(oc)" }

        assert_equal(:removed, character_row[:row_status])
        assert_equal(%w[blue_eyes fluffy_(oc)], character_row[:removed].map { |t| t[:name] }.sort)
      end

      should("bucket an anonymous group's tags under an Unnamed row") do
        @post.update_with(@user, character_groups_attributes: [{ characters: [], tags: ["waving"] }], ungrouped_tag_string: "solo")
        v2 = @post.versions.last

        rows = v2.tag_rows(@v1)
        unnamed_row = rows.find { |r| r[:label] == "Unnamed #1" }

        assert_not_nil(unnamed_row)
        assert_equal(["waving"], unnamed_row[:added].map { |t| t[:name] })
      end

      should("bucket ungrouped tags under a nil-label row") do
        @post.update_with(@user, ungrouped_tag_string: "solo new_tag")
        v2 = @post.versions.last

        rows = v2.tag_rows(@v1)
        general_row = rows.find { |r| r[:label].nil? }

        assert_not_nil(general_row)
        assert_includes(general_row[:added].map { |t| t[:name] }, "new_tag")
      end
    end
  end
end

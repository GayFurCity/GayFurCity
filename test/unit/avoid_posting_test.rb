# frozen_string_literal: true

require("test_helper")

class AvoidPostingTest < ActiveSupport::TestCase
  context("An avoid posting entry") do
    setup do
      @owner_user = create(:owner_user)
      @avoid_posting = create(:avoid_posting)
    end

    should("create an artist") do
      assert_difference("Artist.count", 1) do
        create(:avoid_posting)
      end
    end

    should("create a create modaction") do
      assert_difference("ModAction.count", 1) do
        create(:avoid_posting, creator: @owner_user)
      end

      @mod = ModAction.last

      assert_equal("avoid_posting_create", @mod.action)
      assert_equal(@owner_user.id, @mod.creator_id)
    end

    should("create an update modaction") do
      assert_difference("ModAction.count", 1) do
        @avoid_posting.update_with(@owner_user, details: "test")
      end

      @mod = ModAction.last

      assert_equal("avoid_posting_update", @mod.action)
      assert_equal(@owner_user.id, @mod.creator_id)
    end

    should("create a delete modaction") do
      assert_difference("ModAction.count", 1) do
        @avoid_posting.update_with(@owner_user, is_active: false)
      end

      @mod = ModAction.last

      assert_equal("avoid_posting_delete", @mod.action)
      assert_equal(@owner_user.id, @mod.creator_id)
    end

    should("create an undelete modaction") do
      @avoid_posting.update_column(:is_active, false)

      assert_difference("ModAction.count", 1) do
        @avoid_posting.update_with(@owner_user, is_active: true)
      end

      @mod = ModAction.last

      assert_equal("avoid_posting_undelete", @mod.action)
      assert_equal(@owner_user.id, @mod.creator_id)
    end

    should("create a destroy modaction") do
      assert_difference("ModAction.count", 1) do
        @avoid_posting.destroy_with(@owner_user)
      end

      @mod = ModAction.last

      assert_equal("avoid_posting_destroy", @mod.action)
      assert_equal(@owner_user.id, @mod.creator_id)
    end

    should("create a version when updated") do
      assert_difference("AvoidPostingVersion.count", 1) do
        @avoid_posting.update_with(@owner_user, details: "test")
      end

      @apv = AvoidPostingVersion.last

      assert_equal("test", @apv.details)
      assert_equal(@owner_user.id, @apv.updater_id)
    end
  end
end

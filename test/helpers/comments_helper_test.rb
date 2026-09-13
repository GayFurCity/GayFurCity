# frozen_string_literal: true

require("test_helper")

# rubocop:disable YiffSpace/CurrentOutsideOfRequests -- simulating the viewer for comment_edited_notice
class CommentsHelperTest < ActionView::TestCase
  include(ApplicationHelper)

  context("comment_edited_notice") do
    setup do
      @user = create(:user)
      @mod = create(:moderator_user)
      @post = create(:post)
      @comment = create(:comment, post: @post, creator: @user)
    end

    should("be blank when the comment has never been edited") do
      CurrentUser.scoped(@user) do
        assert_equal("", comment_edited_notice(@comment))
      end
    end

    should("not show a count for a single edit by someone else") do
      @comment.update_with(@mod, body: "edit 1")

      CurrentUser.scoped(@user) do
        html = comment_edited_notice(@comment)

        assert_includes(html, "Updated by")
        assert_not_includes(html, "times")
      end
    end

    should("show the count for consecutive edits by someone else, to anyone") do
      @comment.update_with(@mod, body: "edit 1")
      @comment.update_with(@mod, body: "edit 2")

      CurrentUser.scoped(@user) do
        assert_includes(comment_edited_notice(@comment), "Updated 2 times by")
      end
    end

    should("reset the count when a different user edits in between") do
      @comment.update_with(@mod, body: "edit 1")
      @comment.update_with(@user, body: "edit 2")

      CurrentUser.scoped(@mod) do
        html = comment_edited_notice(@comment)

        assert_includes(html, "Updated ")
        assert_not_includes(html, "times")
      end
    end

    should("only show the self-edit count to moderators") do
      travel_to(10.minutes.from_now) do
        @comment.update_with(@user, body: "edit 1")
        @comment.update_with(@user, body: "edit 2")
      end

      CurrentUser.scoped(@user) do
        html = comment_edited_notice(@comment)

        assert_includes(html, "Updated ")
        assert_not_includes(html, "times")
      end

      CurrentUser.scoped(@mod) do
        assert_includes(comment_edited_notice(@comment), "Updated 2 times")
      end
    end
  end
end
# rubocop:enable YiffSpace/CurrentOutsideOfRequests

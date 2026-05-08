# frozen_string_literal: true

require("test_helper")

module PostSets
  class PostTest < ActiveSupport::TestCase
    context("In all cases") do
      setup do
        @user = create(:user)

        @post1 = create(:post, tag_string: "a")
        @post2 = create(:post, tag_string: "b")
        @post3 = create(:post, tag_string: "c")
      end

      context("a set for page 2") do
        setup do
          @set = PostSets::Post.new("", 2, limit: 1, current_user: @user)
        end

        should("return the second element") do
          assert_equal(@post2.id, @set.posts.first.id)
        end
      end

      context("a set for the 'a' tag query") do
        setup do
          @post4 = create(:post, tag_string: "a")
          @post5 = create(:post, tag_string: "a")
        end

        context("with no page") do
          setup do
            @set = PostSets::Post.new("a", nil, current_user: @user)
          end

          should("return the first element") do
            assert_equal(@post5.id, @set.posts.first.id)
          end
        end

        context("for before the first element") do
          setup do
            @set = PostSets::Post.new("a", "b#{@post5.id}", limit: 1, current_user: @user)
          end

          should("return the second element") do
            assert_equal(@post4.id, @set.posts.first.id)
          end
        end

        context("for after the second element") do
          setup do
            @set = PostSets::Post.new("a", "a#{@post4.id}", limit: 1, current_user: @user)
          end

          should("return the first element") do
            assert_equal(@post5.id, @set.posts.first.id)
          end
        end
      end

      context("#limit method") do
        should("take the limit from the params first, then the limit:<n> metatag") do
          set = PostSets::Post.new("a limit:23 b", 1, limit: "42", current_user: @user)

          assert_equal("42", set.limit)

          set = PostSets::Post.new("a limit:23 b", 1, current_user: @user)

          assert_equal("23", set.limit)

          set = PostSets::Post.new("a", 1, current_user: @user)

          assert_nil(set.limit)
        end
      end
    end
  end
end

# frozen_string_literal: true

require("test_helper")

module PostSets
  class FavoritesTest < ActiveSupport::TestCase
    context("In all cases") do
      setup do
        @user = create(:user)

        @post1 = create(:post)
        @post2 = create(:post)
        @post3 = create(:post)
        FavoriteManager.add!(user: @user, post: @post2)
        FavoriteManager.add!(user: @user, post: @post1)
        FavoriteManager.add!(user: @user, post: @post3)
      end

      context("a favorite set for before the most recent post") do
        setup do
          id = ::Favorite.where(user_id: @user.id, post_id: @post3.id).first.id
          @set = PostSets::Favorites.new(@user, "b#{id}", limit: 1, current_user: @user)
        end

        context("a sequential paginator") do
          should("return the second most recent element") do
            assert_equal(@post1.id, @set.posts.first.id)
          end

          # FIXME: PaginatedArray does not preserve mode and mode_seq
          should("know what page it's on") do
            skip("PaginatedArray does not preserve mode and mode_seq")

            assert_not(@set.posts.is_first_page?)
            assert_not(@set.posts.is_last_page?)
          end
        end
      end

      context("a favorite set for after the third most recent post") do
        setup do
          id = ::Favorite.where(user_id: @user.id, post_id: @post2.id).first.id
          @set = PostSets::Favorites.new(@user, "a#{id}", limit: 1, current_user: @user)
        end

        context("a sequential paginator") do
          should("return the second most recent element") do
            assert_equal(@post1.id, @set.posts.first.id)
          end
        end
      end

      context("a favorite set for before the second most recent post") do
        setup do
          id = ::Favorite.where(user_id: @user.id, post_id: @post1.id).first.id
          @set = PostSets::Favorites.new(@user, "b#{id}", limit: 1, current_user: @user)
        end

        context("a sequential paginator") do
          should("return the third most recent element") do
            assert_equal(@post2.id, @set.posts.first.id)
          end
        end
      end

      context("a favorite set for after the second most recent post") do
        setup do
          id = ::Favorite.where(user_id: @user.id, post_id: @post1.id).first.id
          @set = PostSets::Favorites.new(@user, "a#{id}", limit: 1, current_user: @user)
        end

        context("a sequential paginator") do
          should("return the most recent element") do
            assert_equal(@post3.id, @set.posts.first.id)
          end
        end
      end

      context("a favorite set for page 2") do
        setup do
          @set = PostSets::Favorites.new(@user, 2, limit: 1, current_user: @user)
        end

        context("a numbered paginator") do
          should("return the second most recent element") do
            assert_equal(@post1.id, @set.posts.first.id)
          end
        end
      end

      context("a favorite set with no page specified") do
        setup do
          @set = PostSets::Favorites.new(@user, nil, limit: 1, current_user: @user)
        end

        should("return the most recent element") do
          assert_equal(@post3.id, @set.posts.first.id)
        end
      end
    end
  end
end

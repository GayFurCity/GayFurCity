# frozen_string_literal: true

require("test_helper")

class FavoritesControllerTest < ActionDispatch::IntegrationTest
  context("The favorites controller") do
    setup do
      @user = create(:user)
    end

    context("index action") do
      setup do
        @post = create(:post)
        FavoriteManager.add!(user: @user, post: @post)
      end

      context("with a specified tags parameter") do
        should("redirect to the posts controller") do
          get_auth(favorites_path, @user, params: { tags: "fav:#{@user.name} abc" })

          assert_redirected_to(posts_path(tags: "fav:#{@user.name} abc"))
        end
      end

      should("display the current user's favorites") do
        get_auth(favorites_path, @user)

        assert_response(:success)
      end

      context("access control") do
        asserts do
          access.gte(User::Levels::REJECTED).get(favorites_path)
          access.gte(User::Levels::REJECTED).json.get(favorites_path)
        end
      end
    end

    context("create action") do
      setup do
        @post = create(:post)
      end

      should("create a favorite for the current user") do
        assert_difference({ "Favorite.count" => 1, "PostVote.count" => 0 }) do
          post_auth(favorites_path, @user, params: { format: "json", post_id: @post.id })
        end
      end

      should("create a favorite and vote for the current user if upvote=true") do
        assert_difference(%w[Favorite.count PostVote.count], 1) do
          post_auth(favorites_path, @user, params: { format: "json", post_id: @post.id, upvote: "true" })
        end
      end

      context("access control") do
        asserts do
          access.gte(User::Levels::REJECTED).post(favorites_path).params { { post_id: @post.id } }.success(:redirect)
          access.gte(User::Levels::REJECTED).json.post(favorites_path).params { { post_id: @post.id } }
        end
      end
    end

    context("destroy action") do
      setup do
        @post = create(:post)
        FavoriteManager.add!(user: @user, post: @post)
      end

      should("remove the favorite from the current user") do
        assert_difference("Favorite.count", -1) do
          delete_auth(favorite_path(@post), @user, params: { format: "js" })
        end
      end

      context("access control") do
        asserts do
          access.gte(User::Levels::REJECTED).delete { favorite_path(@post) }.success(:redirect)
          access.gte(User::Levels::REJECTED).json.delete { favorite_path(@post) }
        end
      end
    end

    context("clear action") do
      setup do
        @post = create(:post)
        FavoriteManager.add!(user: @user, post: @post)
      end

      should("work") do
        assert_difference("Favorite.count", -1) do
          put_auth(clear_favorites_path, @user)

          assert_redirected_to(favorites_path)
          perform_enqueued_jobs(only: ClearUserFavoritesJob)
        end
      end

      should("limit to once a week") do
        put_auth(clear_favorites_path, @user)

        assert_redirected_to(favorites_path)
        put_auth(clear_favorites_path, @user)

        assert_response(:too_many_requests)
      end

      context("access control") do
        asserts do
          access.gte(User::Levels::REJECTED).put(clear_favorites_path).success(:redirect)
          access.gte(User::Levels::REJECTED).json.put(clear_favorites_path).success(:no_content)
        end
      end
    end
  end
end

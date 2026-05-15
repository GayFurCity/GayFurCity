# frozen_string_literal: true

require("test_helper")

class NewsUpdatesControllerTest < ActionDispatch::IntegrationTest
  context("the news updates controller") do
    setup do
      @admin = create(:admin_user)
      @news_update = create(:news_update)
    end

    context("index action") do
      should("render") do
        get_auth(news_updates_path, @admin)

        assert_response(:success)
      end

      context("access control") do
        asserts do
          access.gte(User::Levels::ANONYMOUS).get(news_updates_path)
          access.gte(User::Levels::ANONYMOUS).json.get(news_updates_path)
        end
      end
    end

    context("new action") do
      should("render") do
        get_auth(new_news_update_path, @admin)

        assert_response(:success)
      end

      context("access control") do
        asserts do
          access.gte(User::Levels::ADMIN).get(new_news_update_path)
        end
      end
    end

    context("edit action") do
      should("render") do
        get_auth(edit_news_update_path(@news_update), @admin)

        assert_response(:success)
      end

      context("access control") do
        asserts do
          access.gte(User::Levels::ADMIN).get { edit_news_update_path(@news_update) }
        end
      end
    end

    context("update action") do
      should("work") do
        put_auth(news_update_path(@news_update), @admin, params: { news_update: { message: "zzz" } })

        assert_redirected_to(news_updates_path)
      end

      context("access control") do
        asserts do
          access.gte(User::Levels::ADMIN).put { news_update_path(@news_update) }.params({ news_update: { message: "zzz" } }).success(:redirect)
          access.gte(User::Levels::ADMIN).json.put { news_update_path(@news_update) }.params({ news_update: { message: "zzz" } })
        end
      end
    end

    context("create action") do
      should("work") do
        assert_difference("NewsUpdate.count") do
          post_auth(news_updates_path, @admin, params: { news_update: { message: "zzz" } })
        end
        assert_redirected_to(news_updates_path)
      end

      context("access control") do
        asserts do
          access.gte(User::Levels::ADMIN).post(news_updates_path).params({ news_update: { message: "zzz" } }).success(:redirect)
          access.gte(User::Levels::ADMIN).json.post(news_updates_path).params({ news_update: { message: "zzz" } })
        end
      end
    end

    context("destroy action") do
      should("work") do
        assert_difference("NewsUpdate.count", -1) do
          delete_auth(news_update_path(@news_update), @admin)
        end
        assert_redirected_to(news_updates_path)
      end

      context("access control") do
        asserts do
          access.gte(User::Levels::ADMIN).delete { news_update_path(@news_update) }.success(:redirect)
          access.gte(User::Levels::ADMIN).json.delete { news_update_path(@news_update) }.success(:no_content)
        end
      end
    end
  end
end

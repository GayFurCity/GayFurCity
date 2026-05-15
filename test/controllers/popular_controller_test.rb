# frozen_string_literal: true

require("test_helper")

class PopularControllerTest < ActionDispatch::IntegrationTest
  context("The popular controller") do
    context("index action") do
      should("render") do
        get(popular_index_path)

        assert_response(:success)
      end

      context("access control") do
        asserts do
          access.gte(User::Levels::ANONYMOUS).get(popular_index_path)
        end
      end
    end

    context("uploads action") do
      should("render") do
        get(uploads_popular_index_path)

        assert_response(:success)
      end

      context("access control") do
        asserts do
          access.gte(User::Levels::ANONYMOUS).get(uploads_popular_index_path)
          access.gte(User::Levels::ANONYMOUS).json.get(uploads_popular_index_path)
        end
      end
    end

    context("views action") do
      should("render") do
        get(views_popular_index_path)

        assert_response(:success)
      end

      context("access control") do
        asserts do
          access.gte(User::Levels::ANONYMOUS).get(views_popular_index_path)
          access.gte(User::Levels::ANONYMOUS).json.get(views_popular_index_path)
        end
      end
    end

    context("top_views action") do
      should("render") do
        get(top_views_popular_index_path)

        assert_response(:success)
      end

      context("access control") do
        asserts do
          access.gte(User::Levels::ANONYMOUS).get(top_views_popular_index_path)
          access.gte(User::Levels::ANONYMOUS).json.get(top_views_popular_index_path)
        end
      end
    end

    context("followed_tags action") do
      should("render") do
        get(followed_tags_popular_index_path)

        assert_response(:success)
      end

      context("access control") do
        asserts do
          access.gte(User::Levels::ANONYMOUS).get(followed_tags_popular_index_path)
          access.gte(User::Levels::ANONYMOUS).json.get(followed_tags_popular_index_path)
        end
      end
    end

    context("searches action") do
      should("render") do
        get(searches_popular_index_path)

        assert_response(:success)
      end

      should("escape search tags in the html response") do
        tag = %("><script>alert("xss")</script>)
        Reports.stubs(:get_post_searches_rank).returns([{ "tag" => tag, "count" => 1 }])

        get(searches_popular_index_path)

        assert_response(:success)
        assert_includes(@response.body, CGI.escapeHTML(tag))
        assert_not_includes(@response.body, tag)
      end

      context("access control") do
        asserts do
          access.gte(User::Levels::ANONYMOUS).get(searches_popular_index_path)
          access.gte(User::Levels::ANONYMOUS).json.get(searches_popular_index_path)
        end
      end
    end

    context("top_searches action") do
      should("render") do
        get(top_searches_popular_index_path)

        assert_response(:success)
      end

      context("access control") do
        asserts do
          access.gte(User::Levels::ANONYMOUS).get(top_searches_popular_index_path)
          access.gte(User::Levels::ANONYMOUS).json.get(top_searches_popular_index_path)
        end
      end
    end

    context("missed_searches action") do
      should("render") do
        get(missed_searches_popular_index_path)

        assert_response(:success)
      end

      context("access control") do
        asserts do
          access.gte(User::Levels::ANONYMOUS).get(missed_searches_popular_index_path)
          access.gte(User::Levels::ANONYMOUS).json.get(missed_searches_popular_index_path)
        end
      end
    end

    context("top_missed_searches action") do
      should("render") do
        get(missed_searches_popular_index_path)

        assert_response(:success)
      end

      context("access control") do
        asserts do
          access.gte(User::Levels::ANONYMOUS).get(top_missed_searches_popular_index_path)
          access.gte(User::Levels::ANONYMOUS).json.get(top_missed_searches_popular_index_path)
        end
      end
    end
  end
end

# frozen_string_literal: true

require("test_helper")

class HelpControllerTest < ActionDispatch::IntegrationTest
  context("The help controller") do
    setup do
      @user = create(:user)
      @admin = create(:admin_user)
      @wiki = create(:wiki_page, title: "help")
      @help = create(:help_page, wiki_page: @wiki, name: "very_important")
    end

    context("index action") do
      should("render") do
        get(help_pages_path)

        assert_response(:success)
      end

      context("access control") do
        asserts do
          access.gte(User::Levels::ANONYMOUS).get(help_pages_path)
          access.gte(User::Levels::ANONYMOUS).json.get(help_pages_path)
        end
      end
    end

    context("show action") do
      should("render") do
        get(help_page_path(@help))

        assert_response(:success)
      end

      should("render for name") do
        get(help_page_path(id: @help.name))

        assert_response(:success)
      end

      should("render for name with space") do
        get(help_page_path(id: @help.name.gsub("_", " ")))

        assert_response(:success)
      end

      should("redirect if not found and format is html") do
        get(help_page_path(id: "invalid"))

        assert_redirected_to(help_pages_path)
      end

      should("not redirect if not found and format is json") do
        get(help_page_path(id: "invalid"), params: { format: :json })

        assert_response(:not_found)
      end

      context("access control") do
        asserts do
          access.gte(User::Levels::ANONYMOUS).get { help_page_path(@help) }
          access.gte(User::Levels::ANONYMOUS).json.get { help_page_path(@help) }
        end
      end
    end

    context("new action") do
      should("render") do
        get_auth(new_help_page_path, @admin)

        assert_response(:success)
      end

      context("access control") do
        asserts do
          access.gte(User::Levels::ADMIN).get(new_help_page_path)
        end
      end
    end

    context("create action") do
      should("work") do
        post_auth(help_pages_path, @admin, params: { help_page: { name: "test", wiki_page_id: create(:wiki_page).id } })

        assert_redirected_to(HelpPage.last)
      end

      context("access control") do
        asserts do
          access.gte(User::Levels::ADMIN).post(help_pages_path).params { { help_page: { name: SecureRandom.hex(6), wiki_page_id: create(:wiki_page).id } } }.success(:redirect)
          access.gte(User::Levels::ADMIN).json.post(help_pages_path).params { { help_page: { name: SecureRandom.hex(6), wiki_page_id: create(:wiki_page).id } } }
        end
      end
    end

    context("edit action") do
      should("render") do
        get_auth(edit_help_page_path(@help), @admin)

        assert_response(:success)
      end

      context("access control") do
        asserts do
          access.gte(User::Levels::ADMIN).get { edit_help_page_path(@help) }
        end
      end
    end

    context("update action") do
      should("work") do
        put_auth(help_page_path(@help), @admin, params: { help_page: { name: "test2" } })

        assert_redirected_to(@help)
        assert_equal("test2", @help.reload.name)
      end

      context("access control") do
        asserts do
          access.gte(User::Levels::ADMIN).put { help_page_path(@help) }.params({ help_page: { name: "test" } }).success(:redirect)
          access.gte(User::Levels::ADMIN).json.put { help_page_path(@help) }.params({ help_page: { name: "test" } })
        end
      end
    end

    context("destroy action") do
      should("work") do
        delete_auth(help_page_path(@help), @admin)

        assert_redirected_to(help_pages_path)
        assert_raises(ActiveRecord::RecordNotFound) { @help.reload }
      end

      context("access control") do
        asserts do
          access.gte(User::Levels::ADMIN).delete { help_page_path(@help) }.success(:redirect)
          access.gte(User::Levels::ADMIN).json.delete { help_page_path(@help) }.success(:no_content)
        end
      end
    end
  end
end

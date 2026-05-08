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

      should("restrict access") do
        assert_access(User::Levels::ANONYMOUS) { |user| get_auth(help_pages_path, user) }
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

      should("restrict access") do
        assert_access(User::Levels::ANONYMOUS) { |user| get_auth(help_page_path(@help), user) }
      end
    end

    context("new action") do
      should("render") do
        get_auth(new_help_page_path, @admin)

        assert_response(:success)
      end

      should("restrict access") do
        assert_access(User::Levels::ADMIN) { |user| get_auth(new_help_page_path, user) }
      end
    end

    context("create action") do
      should("work") do
        post_auth(help_pages_path, @admin, params: { help_page: { name: "test", wiki_page_id: create(:wiki_page).id } })

        assert_redirected_to(HelpPage.last)
      end

      should("restrict access") do
        assert_access(User::Levels::ADMIN, success_response: :redirect) { |user| post_auth(help_pages_path, user, params: { help_page: { name: SecureRandom.hex(6), wiki_page_id: create(:wiki_page).id } }) }
      end
    end

    context("edit action") do
      should("render") do
        get_auth(edit_help_page_path(@help), @admin)

        assert_response(:success)
      end

      should("restrict access") do
        assert_access(User::Levels::ADMIN) { |user| get_auth(edit_help_page_path(@help), user) }
      end
    end

    context("update action") do
      should("work") do
        put_auth(help_page_path(@help), @admin, params: { help_page: { name: "test2" } })

        assert_redirected_to(@help)
        assert_equal("test2", @help.reload.name)
      end

      should("restrict access") do
        assert_access(User::Levels::ADMIN, success_response: :redirect) { |user| put_auth(help_page_path(@help), user, params: { help_page: { name: "test" } }) }
      end
    end

    context("destroy action") do
      should("work") do
        delete_auth(help_page_path(@help), @admin)

        assert_redirected_to(help_pages_path)
        assert_raises(ActiveRecord::RecordNotFound) { @help.reload }
      end

      should("restrict access") do
        assert_access(User::Levels::ADMIN, success_response: :redirect) { |user| delete_auth(help_page_path(create(:help_page)), user) }
      end
    end
  end
end

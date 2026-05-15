# frozen_string_literal: true

require("test_helper")

class WikiPagesControllerTest < ActionDispatch::IntegrationTest
  context("The wiki pages controller") do
    setup do
      @user = create(:user)
      @mod = create(:moderator_user)
      @owner = create(:owner_user)
      @wiki_page = create(:wiki_page)
    end

    context("index action") do
      setup do
        @wiki_page_abc = create(:wiki_page, title: "abc")
        @wiki_page_def = create(:wiki_page, title: "def")
      end

      should("list all wiki_pages") do
        get(wiki_pages_path)

        assert_response(:success)
      end

      context("access control") do
        asserts do
          access.gte(User::Levels::ANONYMOUS).get(wiki_pages_path)
          access.gte(User::Levels::ANONYMOUS).json.get(wiki_pages_path)
        end
      end

      context("search parameters") do
        subject { wiki_pages_path }
        setup do
          WikiPageVersion.delete_all
          WikiPage.delete_all
          @creator = create(:trusted_user)
          @updater = create(:trusted_user)
          @admin = create(:admin_user)
          @parent = create(:wiki_page, title: "bar")
          @wiki_page = create(:wiki_page, title: "foo", body: "[[bar]] baz", protection_level: User::Levels::TRUSTED, creator: @creator, creator_ip_addr: "127.0.0.2", updater: @updater, updater_ip_addr: "127.0.0.3", parent: @parent.title)
        end

        asserts do
          search(:title, "foo").records { [@wiki_page] }
          search(:title_matches, "foo").records { [@wiki_page] }
          search(:body_matches, "baz").records { [@wiki_page] }
          search(:protection_level, User::Levels::TRUSTED).records { [@wiki_page] }
          search(:parent, "bar").records { [@wiki_page] }
          search(:linked_to, "bar").records { [@wiki_page] }
          search(:not_linked_to, "bar").records { [@parent] }
          search(:creator_id).value { @creator.id }.records { [@wiki_page] }
          search(:creator_name).value { @creator.name }.records { [@wiki_page] }
          search(:ip_addr, "127.0.0.2").records { [@wiki_page] }.user { @admin }
          search(:updater_id).value { @updater.id }.records { [@wiki_page] }
          search(:updater_name).value { @updater.name }.records { [@wiki_page] }
          search(:updater_ip_addr, "127.0.0.3").records { [@wiki_page] }.user { @admin }
          search.shared.records { [@wiki_page, @parent] }
        end
      end
    end

    context("show action") do
      should("render") do
        get(wiki_page_path(@wiki_page))

        assert_response(:success)
      end

      should("render for a title") do
        get(wiki_page_path(id: @wiki_page.title))

        assert_response(:success)
      end

      should("redirect html requests for a nonexistent title") do
        get(wiki_page_path("what"))

        assert_redirected_to(show_or_new_wiki_pages_path(title: "what"))
      end

      should("return 404 to api requests for a nonexistent title") do
        get(wiki_page_path("what"), as: :json)

        assert_response(:not_found)
      end

      should("render for a negated tag") do
        @wiki_page.update_columns(title: "-aaa")
        get(wiki_page_path(@wiki_page))

        assert_response(:success)
      end

      context("access control") do
        asserts do
          access.gte(User::Levels::ANONYMOUS).get { wiki_page_path(@wiki_page) }
          access.gte(User::Levels::ANONYMOUS).json.get { wiki_page_path(@wiki_page) }
        end
      end
    end

    context("show_or_new action") do
      should("redirect when given a title") do
        get(show_or_new_wiki_pages_path, params: { title: @wiki_page.title })

        assert_redirected_to(@wiki_page)
      end

      should("render when given a nonexistent title") do
        get(show_or_new_wiki_pages_path, params: { title: "what" })

        assert_response(:success)
      end

      context("access control") do
        asserts do
          access.gte(User::Levels::ANONYMOUS).get(show_or_new_wiki_pages_path).params({ title: "what" })
        end
      end
    end

    context("new action") do
      should("render") do
        get_auth(new_wiki_page_path, @mod, params: { wiki_page: { title: "test" } })

        assert_response(:success)
      end

      context("access control") do
        asserts do
          access.gte(User::Levels::MEMBER).get(new_wiki_page_path)
        end
      end
    end

    context("edit action") do
      should("render") do
        get_auth(wiki_page_path(@wiki_page), @mod)

        assert_response(:success)
      end

      context("access control") do
        asserts do
          access.gte(User::Levels::MEMBER).get { edit_wiki_page_path(@wiki_page) }
        end
      end

      context("protected access control") do
        setup { @wiki_page.update_columns(protection_level: User::Levels::ADMIN) }

        asserts do
          access.gte(User::Levels::ADMIN).get { edit_wiki_page_path(@wiki_page) }
        end
      end
    end

    context("create action") do
      should("create a wiki_page") do
        assert_difference("WikiPage.count", 1) do
          post_auth(wiki_pages_path, @user, params: { wiki_page: { title: "abc", body: "abc" } })
        end
      end

      context("access control") do
        asserts do
          access.gte(User::Levels::MEMBER).post(wiki_pages_path).params { { wiki_page: { title: SecureRandom.hex(6), body: SecureRandom.hex(6) } } }.success(:redirect)
          access.gte(User::Levels::MEMBER).json.post(wiki_pages_path).params { { wiki_page: { title: SecureRandom.hex(6), body: SecureRandom.hex(6) } } }
        end
      end
    end

    context("update action") do
      setup do
        @tag = create(:tag, name: @wiki_page.title, post_count: 42)
      end

      should("update a wiki_page") do
        put_auth(wiki_page_path(@wiki_page), @user, params: { wiki_page: { body: "xyz" } })
        @wiki_page.reload

        assert_equal("xyz", @wiki_page.body)
      end

      should("not rename a wiki page with a non-empty tag") do
        ogtitle = @wiki_page.title
        put_auth(wiki_page_path(@wiki_page), @user, params: { wiki_page: { title: "bar" } })

        assert_equal(ogtitle, @wiki_page.reload.title)
      end

      should("set protection level") do
        put_auth(wiki_page_path(@wiki_page), @owner, params: { wiki_page: { protection_level: User::Levels::ADMIN } })

        assert_equal(User::Levels::ADMIN, @wiki_page.reload.protection_level)
      end

      should("update protection level") do
        @wiki_page.update_column(:protection_level, User::Levels::JANITOR)
        put_auth(wiki_page_path(@wiki_page), @owner, params: { wiki_page: { protection_level: User::Levels::ADMIN } })

        assert_equal(User::Levels::ADMIN, @wiki_page.reload.protection_level)
      end

      should("set protection level on internal page") do
        @wiki_page = create(:wiki_page, title: "internal:test", creator: @owner)
        put_auth(wiki_page_path(@wiki_page), @owner, params: { wiki_page: { protection_level: User::Levels::ADMIN } })

        assert_redirected_to(wiki_page_path(@wiki_page))
        assert_equal(User::Levels::ADMIN, @wiki_page.reload.protection_level)
      end

      should("not allow setting protection level above editor's level") do
        put_auth(wiki_page_path(@wiki_page), @mod, params: { wiki_page: { protection_level: User::Levels::ADMIN } })

        assert_nil(@wiki_page.reload.protection_level)
      end

      context("access control") do
        asserts do
          access.gte(User::Levels::MEMBER).put { wiki_page_path(@wiki_page) }.params { { wiki_page: { body: SecureRandom.hex(6) } } }.success(:redirect)
          access.gte(User::Levels::MEMBER).json.put { wiki_page_path(@wiki_page) }.params { { wiki_page: { body: SecureRandom.hex(6) } } }
        end
      end

      context("protections access control") do
        setup { @wiki_page.update_columns(protection_level: User::Levels::ADMIN) }

        asserts do
          access.gte(User::Levels::ADMIN).put { wiki_page_path(@wiki_page) }.params { { wiki_page: { body: SecureRandom.hex(6) } } }.success(:redirect)
          access.gte(User::Levels::ADMIN).json.put { wiki_page_path(@wiki_page) }.params { { wiki_page: { body: SecureRandom.hex(6) } } }
        end
      end
    end

    context("destroy action") do
      setup do
        @wiki_page = create(:wiki_page)
      end

      should("destroy a wiki_page") do
        delete_auth(wiki_page_path(@wiki_page), create(:admin_user))
        assert_raises(ActiveRecord::RecordNotFound) { @wiki_page.reload }
      end

      context("access control") do
        asserts do
          access.gte(User::Levels::ADMIN).delete { wiki_page_path(@wiki_page) }.success(:redirect)
          access.gte(User::Levels::ADMIN).json.delete { wiki_page_path(@wiki_page) }.success(:no_content)
        end
      end

      context("protections access control") do
        setup { @wiki_page = create(:wiki_page, protection_level: User::Levels::OWNER, creator: @owner) }

        asserts do
          access.gte(User::Levels::OWNER).delete { wiki_page_path(@wiki_page) }.success(:redirect)
          access.gte(User::Levels::OWNER).json.delete { wiki_page_path(@wiki_page) }.success(:no_content)
        end
      end
    end

    context("revert action") do
      setup do
        @wiki_page = create(:wiki_page, body: "1")
        travel_to(1.day.from_now) do
          @wiki_page.update_with(@user, body: "1 2")
        end
        travel_to(2.days.from_now) do
          @wiki_page.update_with(@user, body: "1 2 3")
        end
      end

      should("revert to a previous version") do
        version = @wiki_page.versions.first

        assert_equal("1", version.body)
        put_auth(revert_wiki_page_path(@wiki_page), @user, params: { version_id: version.id })
        @wiki_page.reload

        assert_equal("1", @wiki_page.body)
      end

      should("not allow reverting to a previous version of another wiki page") do
        @wiki_page2 = create(:wiki_page)

        put_auth(revert_wiki_page_path(@wiki_page), @user, params: { version_id: @wiki_page2.versions.first.id })
        @wiki_page.reload

        assert_not_equal(@wiki_page.body, @wiki_page2.body)
        assert_response(:missing)
      end

      context("access control") do
        asserts do
          access.gte(User::Levels::MEMBER).put { revert_wiki_page_path(@wiki_page) }.params { { version_id: @wiki_page.versions.first.id } }.success(:redirect)
          access.gte(User::Levels::MEMBER).json.put { revert_wiki_page_path(@wiki_page) }.params { { version_id: @wiki_page.versions.first.id } }
        end
      end

      context("protections access control") do
        setup { @wiki_page.update_column(:protection_level, User::Levels::ADMIN) }

        asserts do
          access.gte(User::Levels::ADMIN).put { revert_wiki_page_path(@wiki_page) }.params { { version_id: @wiki_page.versions.first.id } }.success(:redirect)
          access.gte(User::Levels::ADMIN).json.put { revert_wiki_page_path(@wiki_page) }.params { { version_id: @wiki_page.versions.first.id } }
        end
      end
    end
  end
end

# frozen_string_literal: true

require("test_helper")

module WikiPages
  class VersionsControllerTest < ActionDispatch::IntegrationTest
    context("The wiki page versions controller") do
      setup do
        @user = create(:user)
        @wiki_page = create(:wiki_page)
        @wiki_page.update_with(@user, body: "1 2")
        @wiki_page.update_with(@user, body: "2 3")
      end

      context("index action") do
        should("list all versions") do
          get(wiki_page_versions_path)

          assert_response(:success)
        end

        should("list all versions that match the search criteria") do
          get(wiki_page_versions_path, params: { search: { wiki_page_id: @wiki_page.id } })

          assert_response(:success)
        end

        context("access control") do
          asserts do
            access.gte(User::Levels::ANONYMOUS).get(wiki_page_versions_path)
            access.gte(User::Levels::ANONYMOUS).json.get(wiki_page_versions_path)
          end
        end

        context("search parameters") do
          subject { wiki_page_versions_path }
          setup do
            WikiPageVersion.delete_all
            @updater = create(:trusted_user)
            @admin = create(:admin_user)
            @wiki_page = create(:wiki_page, creator: @updater, updater_ip_addr: "127.0.0.2", title: "foo", body: "bar", protection_level: User::Levels::TRUSTED)
            @wiki_page_version = @wiki_page.versions.first
          end

          asserts do
            search(:wiki_page_id).value { @wiki_page.id }.records { [@wiki_page_version] }
            search(:title, "foo").records { [@wiki_page_version] }
            search(:body, "bar").records { [@wiki_page_version] }
            search(:protection_level, User::Levels::TRUSTED).records { [@wiki_page_version] }
            search(:updater_id).value { @updater.id }.records { [@wiki_page_version] }
            search(:updater_name).value { @updater.name }.records { [@wiki_page_version] }
            search(:ip_addr, "127.0.0.2").records { [@wiki_page_version] }.user { @admin }
            search.shared.records { [@wiki_page_version] }
          end
        end
      end

      context("show action") do
        should("render") do
          get(wiki_page_version_path(@wiki_page.versions.first))

          assert_response(:success)
        end

        context("access control") do
          asserts do
            access.gte(User::Levels::ANONYMOUS).get { wiki_page_version_path(@wiki_page.versions.first) }
            access.gte(User::Levels::ANONYMOUS).json.get { wiki_page_version_path(@wiki_page.versions.first) }
          end
        end
      end

      context("diff action") do
        should("render") do
          get(diff_wiki_page_versions_path, params: { thispage: @wiki_page.versions.first.id, otherpage: @wiki_page.versions.last.id })

          assert_response(:success)
        end

        context("access control") do
          asserts do
            access.gte(User::Levels::ANONYMOUS).get(diff_wiki_page_versions_path).params { { thispage: @wiki_page.versions.first.id, otherpage: @wiki_page.versions.last.id } }
          end
        end
      end
    end
  end
end

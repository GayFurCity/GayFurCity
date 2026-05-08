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

        should("restrict access") do
          assert_access(User::Levels::ANONYMOUS) { |user| get_auth(wiki_page_versions_path, user) }
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

          assert_search_param(:wiki_page_id, -> { @wiki_page.id }, -> { [@wiki_page_version] })
          assert_search_param(:title, "foo", -> { [@wiki_page_version] })
          assert_search_param(:body, "bar", -> { [@wiki_page_version] })
          assert_search_param(:protection_level, User::Levels::TRUSTED, -> { [@wiki_page_version] })
          assert_search_param(:updater_id, -> { @updater.id }, -> { [@wiki_page_version] })
          assert_search_param(:updater_name, -> { @updater.name }, -> { [@wiki_page_version] })
          assert_search_param(:ip_addr, "127.0.0.2", -> { [@wiki_page_version] }, -> { @admin })
          assert_shared_search_params(-> { [@wiki_page_version] })
        end
      end

      context("show action") do
        should("render") do
          get(wiki_page_version_path(@wiki_page.versions.first))

          assert_response(:success)
        end

        should("restrict access") do
          assert_access(User::Levels::ANONYMOUS) { |user| get_auth(wiki_page_version_path(@wiki_page.versions.first), user) }
        end
      end

      context("diff action") do
        should("render") do
          get(diff_wiki_page_versions_path, params: { thispage: @wiki_page.versions.first.id, otherpage: @wiki_page.versions.last.id })

          assert_response(:success)
        end

        should("restrict access") do
          assert_access(User::Levels::ANONYMOUS) { |user| get_auth(diff_wiki_page_versions_path, user, params: { thispage: @wiki_page.versions.first.id, otherpage: @wiki_page.versions.last.id }) }
        end
      end
    end
  end
end

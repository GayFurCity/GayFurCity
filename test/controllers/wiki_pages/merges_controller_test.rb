# frozen_string_literal: true

require("test_helper")

module WikiPages
  class MergesControllerTest < ActionDispatch::IntegrationTest
    context("The wiki page merges controller") do
      setup do
        @user = create(:trusted_user, created_at: 1.month.ago)
        @admin = create(:admin_user)
        @wiki_page = create(:wiki_page)
        @ogversion = @wiki_page.versions.first
        @target = create(:wiki_page)
      end

      context("show action") do
        should("render") do
          get_auth(merge_wiki_page_path(@wiki_page), @admin)
        end

        should("restrict access") do
          assert_access(User::Levels::ADMIN) { |user| get_auth(merge_wiki_page_path(@wiki_page), user) }
        end
      end

      context("create action") do
        should("work") do
          assert_difference({ "ModAction.count" => 2, "WikiPageVersion.count" => 1 }) do
            post_auth(merge_wiki_page_path(@wiki_page), @admin, params: { wiki_page: { target_wiki_page_id: @target.id } })

            assert_redirected_to(wiki_page_path(@target))
          end
          assert_equal(0, @wiki_page.versions.count)
          assert_equal(3, @target.versions.count)
          assert_equal(@target.id, @ogversion.reload.wiki_page_id)
          assert_equal(%w[wiki_page_merge wiki_page_delete], ModAction.last(2).map(&:action))
        end

        should("restrict access") do
          @wiki_pages = create_list(:wiki_page, User::Levels.constants.length)
          assert_access(User::Levels::ADMIN, success_response: :redirect) { |user| post_auth(merge_wiki_page_path(@wiki_pages.shift), user, params: { wiki_page: { target_wiki_page_id: @target.id } }) }
        end
      end
    end
  end
end

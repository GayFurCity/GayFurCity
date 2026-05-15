# frozen_string_literal: true

require("test_helper")

class DtextLinksControllerTest < ActionDispatch::IntegrationTest
  context("The DText links controller") do
    setup do
      create(:wiki_page, title: "case", body: "[[test]]")
      create(:forum_post, body: "[[case]]")
      create(:pool, description: "[[case]]")
      create(:tag, name: "test")
    end

    context("index action") do
      should("render") do
        get(dtext_links_path)

        assert_response(:success)
      end

      context("search parameters") do
        subject { dtext_links_path }
        setup do
          DtextLink.delete_all
          @tag = create(:tag)
          @target = create(:wiki_page, title: @tag.name)
          @wiki = create(:wiki_page, body: "[[#{@target.title}]]")
          @wiki_link = @wiki.dtext_links.first
          @pool = create(:pool, description: "[[#{@target.title}]]")
          @pool_link = @pool.dtext_links.first
          @forum_post = create(:forum_post, body: "[[#{@target.title}]]", id: rand(50_000..500_000)) # ensure ids don't overlap
          @forum_post_link = @forum_post.dtext_links.first
          @external_wiki = create(:wiki_page, body: "https://google.com")
          @external_wiki_link = @external_wiki.dtext_links.first
        end

        asserts do
          search(:link_type, DtextLink.link_types["wiki_link"]).records { [@forum_post_link, @pool_link, @wiki_link] }
          search(:link_type, DtextLink.link_types["external_link"]).records { [@external_wiki_link] }
          search(:link_target).value { @target.title }.records { [@forum_post_link, @pool_link, @wiki_link] }
          search(:link_target, "https://google.com").records { [@external_wiki_link] }
          search(:model_type, "Pool").records { [@pool_link] }
          search(:model_id).value { @forum_post.id }.records { [@forum_post_link] }
          search(:wiki_page_title).value { @target.title }.records { [@forum_post_link, @pool_link, @wiki_link] }
          search(:tag_name).value { @target.title }.records { [@forum_post_link, @pool_link, @wiki_link] }
          search(:has_linked_wiki, "true").records { [@forum_post_link, @pool_link, @wiki_link] }
          search(:has_linked_tag, "true").records { [@forum_post_link, @pool_link, @wiki_link] }
          search.shared.records { [@external_wiki_link, @forum_post_link, @pool_link, @wiki_link] }
        end
      end
    end
  end
end

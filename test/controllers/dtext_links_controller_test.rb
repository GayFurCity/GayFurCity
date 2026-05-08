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

        assert_search_param(:link_type, DtextLink.link_types["wiki_link"], -> { [@forum_post_link, @pool_link, @wiki_link] })
        assert_search_param(:link_type, DtextLink.link_types["external_link"], -> { [@external_wiki_link] })
        assert_search_param(:link_target, -> { @target.title }, -> { [@forum_post_link, @pool_link, @wiki_link] })
        assert_search_param(:link_target, "https://google.com", -> { [@external_wiki_link] })
        assert_search_param(:model_type, "Pool", -> { [@pool_link] })
        assert_search_param(:model_id, -> { @forum_post.id }, -> { [@forum_post_link] })
        assert_search_param(:wiki_page_title, -> { @target.title }, -> { [@forum_post_link, @pool_link, @wiki_link] })
        assert_search_param(:tag_name, -> { @target.title }, -> { [@forum_post_link, @pool_link, @wiki_link] })
        assert_search_param(:has_linked_wiki, "true", -> { [@forum_post_link, @pool_link, @wiki_link] })
        assert_search_param(:has_linked_tag, "true", -> { [@forum_post_link, @pool_link, @wiki_link] })
        assert_shared_search_params(-> { [@external_wiki_link, @forum_post_link, @pool_link, @wiki_link] })
      end
    end
  end
end

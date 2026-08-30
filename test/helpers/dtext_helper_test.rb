# frozen_string_literal: true

require("test_helper")

class DtextHelperTest < ActiveSupport::TestCase
  context("DTextHelper") do
    context(".parse") do
      should("escape raw html input") do
        html = DTextHelper.parse(%(<script>alert("xss")</script><img src=x onerror=alert("xss")>)).fetch(:dtext)

        assert_includes(html, '&lt;script&gt;alert("xss")&lt;/script&gt;')
        assert_includes(html, '&lt;img src=x onerror=alert("xss")&gt;')
        assert_not_includes(html, "<script>alert(\"xss\")</script>")
        assert_not_includes(html, %{<img src=x onerror=alert("xss")>})
      end

      should("recognize a pasted internal url and shorten it to an id link") do
        GayFurCity.config.stubs(:domain).returns("example.com")
        html = DTextHelper.parse("<http://example.com/artists/123> <http://example.com/characters/456>").fetch(:dtext)

        assert_includes(html, %(class="dtext-link dtext-id-link dtext-artist-id-link" href="/artists/123"))
        assert_includes(html, %(class="dtext-link dtext-id-link dtext-character-id-link" href="/characters/456"))
      end

      should("strip a port from the configured domain before matching") do
        GayFurCity.config.stubs(:domain).returns("example.com:4000")
        html = DTextHelper.parse("<http://example.com:4000/artists/123>").fetch(:dtext)

        assert_includes(html, %(class="dtext-link dtext-id-link dtext-artist-id-link" href="/artists/123"))
      end

      should("still treat a genuinely external url as external") do
        GayFurCity.config.stubs(:domain).returns("example.com")
        html = DTextHelper.parse("<http://other-site.example/artists/123>").fetch(:dtext)

        assert_includes(html, "dtext-external-link")
      end

      should("let a caller override the default domain options") do
        GayFurCity.config.stubs(:domain).returns("example.com")
        html = DTextHelper.parse("<http://example.com/artists/123>", internal_domains: []).fetch(:dtext)

        assert_not_includes(html, "dtext-artist-id-link")
      end
    end
  end
end

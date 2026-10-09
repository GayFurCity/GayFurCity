# frozen_string_literal: true

require("test_helper")

class LinkHelperTest < ActionView::TestCase
  setup do
    create(:domain_icon, domain: "e621.net", aliases: %w[e926.net])
    create(:domain_icon, domain: "furaffinity.net", aliases: %w[facdn.net])
    create(:domain_icon, domain: "inkbunny.net", aliases: %w[ib.metapix.net])
  end

  test("for a non-handled url") do
    assert_nil(hostname_for_link("https://example.org"))
  end

  test("for a invalid url") do
    assert_nil(hostname_for_link("https:example.com"))
  end

  test("for a non-url") do
    assert_nil(hostname_for_link("text"))
  end

  test("for a normal domain") do
    assert_equal("e621.net", hostname_for_link("https://e621.net"))
    assert_equal("e621.net", hostname_for_link("https://www.e621.net"))
  end

  test("for a domain with aliases") do
    assert_equal("e621.net", hostname_for_link("https://e926.net"))
    assert_equal("furaffinity.net", hostname_for_link("https://d.facdn.net"))

    assert_equal("inkbunny.net", hostname_for_link("https://ib.metapix.net"))
    assert_equal("inkbunny.net", hostname_for_link("https://qb.ib.metapix.net"))
  end

  test("for a subdomain") do
    assert_equal("furaffinity.net", hostname_for_link("https://a.b.furaffinity.net/x.png"))
  end

  test("for a link that contains square brackets") do
    assert_equal("furaffinity.net", hostname_for_link("https://d.furaffinity.net/square_[brackets].png"))
  end

  test("it returns the uploaded icon if a hostname is found") do
    icon = DomainIcon.find_by(domain: "furaffinity.net")

    assert_match(icon.file_url(user: nil), favicon_for_link("https://furaffinity.net"))
  end

  test("it returns a fontawesome icon if no hostname is found") do
    assert_match("globe", favicon_for_link("https://example.org"))
  end

  test("for this site's domain") do
    assert_equal("example.com", hostname_for_link("https://example.com/posts/1"))
    assert_equal("example.com", hostname_for_link("https://discord.example.com"))
    assert_match(SiteAsset.file_url("favicon-32x32.png"), favicon_for_link("https://example.com/posts/1"))
  end
end

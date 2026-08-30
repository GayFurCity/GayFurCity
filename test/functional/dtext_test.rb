# frozen_string_literal: true

require("test_helper")

class DtextTest < ActiveSupport::TestCase
  include(Rails.application.routes.url_helpers)

  def assert_parse_dtext(expected, text, **)
    assert_equal(expected, DText.parse(text, **)[:dtext])
  end

  def assert_parse_id_link(parse, text, clazz, url, **)
    rel = %(rel="external nofollow noreferrer" ) unless url.starts_with?("/")

    assert_parse_dtext(%(<p><a #{rel}class="dtext-link dtext-id-link #{clazz}" href="#{url}">#{text}</a></p>), parse, **)
  end

  def u(val)
    CGI.unescape(val)
  end

  context("DText") do
    context("id links") do
      should("parse post #") do
        assert_parse_id_link("post #123", "post #123", "dtext-post-id-link", "/posts/123")
      end

      should("parse post changes #") do
        assert_parse_id_link("post changes #123", "post changes #123", "dtext-post-changes-for-id-link", u(post_versions_path(search: { post_id: 123 })))
      end

      should("parse post changes # with version") do
        assert_parse_id_link("post changes #123:1", "post changes #123", "dtext-post-changes-for-id-version-link", u(post_versions_path(search: { post_id: 123, version: 1 })))
      end

      should("parse flag #") do
        assert_parse_id_link("flag #123", "flag #123", "dtext-post-flag-id-link", u(url_for(controller: "posts/flags", action: "show", only_path: true, id: 123)))
      end

      should("parse note #") do
        assert_parse_id_link("note #123", "note #123", "dtext-note-id-link", u(note_path(id: 123)))
      end

      should("parse forum #") do
        assert_parse_id_link("forum #123", "forum #123", "dtext-forum-post-id-link", u(forum_post_path(id: 123)))
      end

      should("parse forumpost #") do
        assert_parse_id_link("forumpost #123", "forum #123", "dtext-forum-post-id-link", u(forum_post_path(id: 123)))
      end

      should("parse forum post #") do
        assert_parse_id_link("forum post #123", "forum #123", "dtext-forum-post-id-link", u(forum_post_path(id: 123)))
      end

      should("parse topic #") do
        assert_parse_id_link("topic #123", "topic #123", "dtext-forum-topic-id-link", u(forum_topic_path(id: 123)))
      end

      should("parse forum topic #") do
        assert_parse_id_link("forum topic #123", "topic #123", "dtext-forum-topic-id-link", u(forum_topic_path(id: 123)))
      end

      should("parse topic # with page") do
        assert_parse_id_link("topic #123/p2", "topic #123 (page 2)", "dtext-forum-topic-id-link", u(forum_topic_path(id: 123, page: 2)))
      end

      should("parse forum topic # with page") do
        assert_parse_id_link("forum topic #123/p2", "topic #123 (page 2)", "dtext-forum-topic-id-link", u(forum_topic_path(id: 123, page: 2)))
      end

      should("parse comment #") do
        assert_parse_id_link("comment #123", "comment #123", "dtext-comment-id-link", u(comment_path(id: 123)))
      end

      should("parse dmail #") do
        assert_parse_id_link("dmail #123", "dmail #123", "dtext-dmail-id-link", u(dmail_path(id: 123)))
      end

      should("parse dmail # with key") do
        assert_parse_id_link("dmail #123/abc", "dmail #123", "dtext-dmail-id-link", u(dmail_path(id: 123, key: "abc")))
      end

      should("parse pool #") do
        assert_parse_id_link("pool #123", "pool #123", "dtext-pool-id-link", u(pool_path(id: 123)))
      end

      should("parse user #") do
        assert_parse_id_link("user #123", "user #123", "dtext-user-id-link", u(user_path(id: 123)))
      end

      should("parse artist #") do
        assert_parse_id_link("artist #123", "artist #123", "dtext-artist-id-link", u(artist_path(id: 123)))
      end

      should("parse artist changes #") do
        assert_parse_id_link("artist changes #123", "artist changes #123", "dtext-artist-changes-for-id-link", u(artist_versions_path(search: { artist_id: 123 })))
      end

      should("parse ban #") do
        assert_parse_id_link("ban #123", "ban #123", "dtext-ban-id-link", u(ban_path(id: 123)))
      end

      should("parse bur #") do
        assert_parse_id_link("bur #123", "BUR #123", "dtext-bulk-update-request-id-link", u(bulk_update_request_path(id: 123)))
      end

      should("parse alias #") do
        assert_parse_id_link("alias #123", "alias #123", "dtext-tag-alias-id-link", u(tag_alias_path(id: 123)))
      end

      should("parse implication #") do
        assert_parse_id_link("implication #123", "implication #123", "dtext-tag-implication-id-link", u(tag_implication_path(id: 123)))
      end

      should("parse mod action #") do
        assert_parse_id_link("mod action #123", "mod action #123", "dtext-mod-action-id-link", u(mod_action_path(id: 123)))
      end

      should("parse record #") do
        assert_parse_id_link("record #123", "record #123", "dtext-user-feedback-id-link", u(user_feedback_path(id: 123)))
      end

      should("parse wiki #") do
        assert_parse_id_link("wiki #123", "wiki #123", "dtext-wiki-page-id-link", u(wiki_page_path(id: 123)))
      end

      should("parse wiki page #") do
        assert_parse_id_link("wiki page #123", "wiki #123", "dtext-wiki-page-id-link", u(wiki_page_path(id: 123)))
      end

      should("parse wikipage #") do
        assert_parse_id_link("wikipage #123", "wiki #123", "dtext-wiki-page-id-link", u(wiki_page_path(id: 123)))
      end

      should("parse wiki changes #") do
        assert_parse_id_link("wiki changes #123", "wiki changes #123", "dtext-wiki-page-changes-for-id-link", u(wiki_page_versions_path(search: { wiki_page_id: 123 })))
      end

      should("parse wiki page changes #") do
        assert_parse_id_link("wiki page changes #123", "wiki changes #123", "dtext-wiki-page-changes-for-id-link", u(wiki_page_versions_path(search: { wiki_page_id: 123 })))
      end

      should("parse wikipage changes #") do
        assert_parse_id_link("wikipage changes #123", "wiki changes #123", "dtext-wiki-page-changes-for-id-link", u(wiki_page_versions_path(search: { wiki_page_id: 123 })))
      end

      should("parse set #") do
        assert_parse_id_link("set #123", "set #123", "dtext-set-id-link", u(post_set_path(id: 123)))
      end

      should("parse ticket #") do
        assert_parse_id_link("ticket #123", "ticket #123", "dtext-ticket-id-link", u(ticket_path(id: 123)))
      end

      should("parse takedown #") do
        assert_parse_id_link("takedown #123", "takedown #123", "dtext-takedown-id-link", u(takedown_path(id: 123)))
      end

      should("parse take down #") do
        assert_parse_id_link("take down #123", "takedown #123", "dtext-takedown-id-link", u(takedown_path(id: 123)))
      end

      should("parse takedown request #") do
        assert_parse_id_link("takedown request #123", "takedown #123", "dtext-takedown-id-link", u(takedown_path(id: 123)))
      end

      should("parse take down request #") do
        assert_parse_id_link("take down request #123", "takedown #123", "dtext-takedown-id-link", u(takedown_path(id: 123)))
      end

      should("parse avoid posting #") do
        assert_parse_id_link("avoid posting #123", "avoid posting #123", "dtext-avoid-posting-id-link", u(avoid_posting_path(id: 123)))
      end

      should("parse dnp #") do
        assert_parse_id_link("dnp #123", "avoid posting #123", "dtext-avoid-posting-id-link", u(avoid_posting_path(id: 123)))
      end

      should("parse issue #") do
        assert_parse_id_link("issue #123", "issue #123", "dtext-github-id-link", "#{GayFurCity.config.source_code_url}/issues/123")
      end

      should("parse pull #") do
        assert_parse_id_link("pull #123", "pull #123", "dtext-github-pull-id-link", "#{GayFurCity.config.source_code_url}/pull/123")
      end

      should("parse commit #") do
        assert_parse_id_link("commit #123", "commit #123", "dtext-github-commit-id-link", "#{GayFurCity.config.source_code_url}/commit/123")
      end
    end

    context("[[]]") do
      should("parse") do
        assert_parse_dtext(%(<p><a rel="nofollow" class="dtext-link dtext-wiki-link" href="/wiki/show_or_new?title=test">test</a></p>), "[[test]]")
      end

      should("parse anchor") do
        assert_parse_dtext(%(<p><a rel="nofollow" class="dtext-link dtext-wiki-link" href="/wiki/show_or_new?title=test#anchor">test</a></p>), "[[test#Anchor]]")
        assert_parse_dtext(%(<p><a rel="nofollow" class="dtext-link dtext-wiki-link" href="/wiki/show_or_new?title=test#anchor">test</a></p>), "[[test#anchor]]")
      end

      should("include spaces") do
        assert_parse_dtext(%(<p><a rel="nofollow" class="dtext-link dtext-wiki-link" href="/wiki/show_or_new?title=cd_ef">abcd efgh</a></p>), "ab[[cd ef]]gh")
      end

      should("include adjacent text on the right") do
        assert_parse_dtext(%(<p>ab <a rel="nofollow" class="dtext-link dtext-wiki-link" href="/wiki/show_or_new?title=cd">cdef</a></p>), "ab [[cd]]ef")
      end

      should("include adjacent text on the left") do
        assert_parse_dtext(%(<p><a rel="nofollow" class="dtext-link dtext-wiki-link" href="/wiki/show_or_new?title=cd">abcd</a> ef</p>), "ab[[cd]] ef")
      end

      should("include adjacent text on both sides") do
        assert_parse_dtext(%(<p><a rel="nofollow" class="dtext-link dtext-wiki-link" href="/wiki/show_or_new?title=cd">abcdef</a></p>), "ab[[cd]]ef")
      end

      context("masked") do
        should("parse") do
          assert_parse_dtext(%(<p><a rel="nofollow" class="dtext-link dtext-wiki-link" href="/wiki/show_or_new?title=test">Test</a></p>), "[[test|Test]]")
        end

        should("parse anchor") do
          assert_parse_dtext(%(<p><a rel="nofollow" class="dtext-link dtext-wiki-link" href="/wiki/show_or_new?title=test#anchor">Test</a></p>), "[[test#Anchor|Test]]")
          assert_parse_dtext(%(<p><a rel="nofollow" class="dtext-link dtext-wiki-link" href="/wiki/show_or_new?title=test#anchor">Test</a></p>), "[[test#anchor|Test]]")
        end

        should("include spaces") do
          assert_parse_dtext(%(<p><a rel="nofollow" class="dtext-link dtext-wiki-link" href="/wiki/show_or_new?title=cd_ef">abij klgh</a></p>), "ab[[cd ef|ij kl]]gh")
        end

        should("include adjacent text on the right") do
          assert_parse_dtext(%(<p>ab <a rel="nofollow" class="dtext-link dtext-wiki-link" href="/wiki/show_or_new?title=cd">ghef</a></p>), "ab [[cd|gh]]ef")
        end

        should("include adjacent text on the left") do
          assert_parse_dtext(%(<p><a rel="nofollow" class="dtext-link dtext-wiki-link" href="/wiki/show_or_new?title=cd">abgh</a> ef</p>), "ab[[cd|gh]] ef")
        end

        should("include adjacent text on both sides") do
          assert_parse_dtext(%(<p><a rel="nofollow" class="dtext-link dtext-wiki-link" href="/wiki/show_or_new?title=cd">abghef</a></p>), "ab[[cd|gh]]ef")
        end

        should("parse with parentheses") do
          assert_parse_dtext(%(<p><a rel="nofollow" class="dtext-link dtext-wiki-link" href="/wiki/show_or_new?title=test_%28testing%29">test</a></p>), "[[test (testing)|]]")
        end
      end
    end

    context("{{}}") do
      should("parse") do
        assert_parse_dtext(%(<p><a class="dtext-link dtext-post-search-link" href="/posts?tags=test">test</a></p>), "{{test}}")
      end

      should("include spaces") do
        assert_parse_dtext(%(<p><a class="dtext-link dtext-post-search-link" href="/posts?tags=cd%20ef">abcd efgh</a></p>), "ab{{cd ef}}gh")
      end

      should("include adjacent text on the right") do
        assert_parse_dtext(%(<p>ab <a class="dtext-link dtext-post-search-link" href="/posts?tags=cd">cdef</a></p>), "ab {{cd}}ef")
      end

      should("include adjacent text on the left") do
        assert_parse_dtext(%(<p><a class="dtext-link dtext-post-search-link" href="/posts?tags=cd">abcd</a> ef</p>), "ab{{cd}} ef")
      end

      should("include adjacent text on both sides") do
        assert_parse_dtext(%(<p><a class="dtext-link dtext-post-search-link" href="/posts?tags=cd">abcdef</a></p>), "ab{{cd}}ef")
      end

      context("masked") do
        should("parse") do
          assert_parse_dtext(%(<p><a class="dtext-link dtext-post-search-link" href="/posts?tags=test">Test</a></p>), "{{test|Test}}")
        end

        should("include spaces") do
          assert_parse_dtext(%(<p><a class="dtext-link dtext-post-search-link" href="/posts?tags=cd%20ef">abij klgh</a></p>), "ab{{cd ef|ij kl}}gh")
        end

        should("include adjacent text on the right") do
          assert_parse_dtext(%(<p>ab <a class="dtext-link dtext-post-search-link" href="/posts?tags=cd">ghef</a></p>), "ab {{cd|gh}}ef")
        end

        should("include adjacent text on the left") do
          assert_parse_dtext(%(<p><a class="dtext-link dtext-post-search-link" href="/posts?tags=cd">abgh</a> ef</p>), "ab{{cd|gh}} ef")
        end

        should("include adjacent text on both sides") do
          assert_parse_dtext(%(<p><a class="dtext-link dtext-post-search-link" href="/posts?tags=cd">abghef</a></p>), "ab{{cd|gh}}ef")
        end
      end
    end

    context("thumb #") do
      should("parse") do
        assert_parse_dtext(%(<p><a class="dtext-link dtext-id-link dtext-post-id-link thumb-placeholder-link" data-id="123" href="/posts/123">post #123</a></p>), "thumb #123")
        assert_equal([123], DText.parse("thumb #123")[:post_ids])
      end

      should("not parse more than allowed") do
        assert_parse_id_link("thumb #123", "post #123", "dtext-post-id-link", "/posts/123", max_thumbs: 0)
        assert_equal([], DText.parse("thumb #123", max_thumbs: 0)[:post_ids])
      end
    end

    context("headers") do
      should("parse") do
        assert_parse_dtext(%(<h1>test</h1>), "h1. test")
        assert_parse_dtext(%(<h2>test</h2>), "h2. test")
        assert_parse_dtext(%(<h3>test</h3>), "h3. test")
        assert_parse_dtext(%(<h4>test</h4>), "h4. test")
        assert_parse_dtext(%(<h5>test</h5>), "h5. test")
        assert_parse_dtext(%(<h6>test</h6>), "h6. test")
      end

      should("parse with id") do
        assert_parse_dtext(%(<h1>test <a id="id"></a></h1>), "h1. test [#id]")
        assert_parse_dtext(%(<h2>test <a id="id"></a></h2>), "h2. test [#id]")
        assert_parse_dtext(%(<h3>test <a id="id"></a></h3>), "h3. test [#id]")
        assert_parse_dtext(%(<h4>test <a id="id"></a></h4>), "h4. test [#id]")
        assert_parse_dtext(%(<h5>test <a id="id"></a></h5>), "h5. test [#id]")
        assert_parse_dtext(%(<h6>test <a id="id"></a></h6>), "h6. test [#id]")
      end
    end

    context("elements") do
      context("[spoiler]") do
        should("parse") do
          assert_parse_dtext(%(<div class="spoiler"><p>test</p></div>), "[spoiler]test[/spoiler]")
        end
      end

      context("[nodtext]") do
        should("parse") do
          assert_parse_dtext(%(<p>test</p>), "[nodtext]test[/nodtext]")
        end

        should("not parse enclosed dtext") do
          assert_parse_dtext(%(<p>[quote]test[/quote]</p>), "[nodtext][quote]test[/quote][/nodtext]")
        end
      end

      context("[quote]") do
        should("parse") do
          assert_parse_dtext(%(<blockquote><p>test</p></blockquote>), "[quote]test[/quote]")
        end

        should("parse nested") do
          assert_parse_dtext(%(<blockquote><blockquote><p>test</p></blockquote></blockquote>), "[quote][quote]test[/quote][/quote]")
        end
      end

      context("[section]") do
        should("parse") do
          assert_parse_dtext(%(<details><summary></summary><div><p>test</p></div></details>), "[section]test[/section]")
        end

        should("parse expanded") do
          assert_parse_dtext(%(<details open><summary></summary><div><p>test</p></div></details>), "[section,expanded]test[/section]")
        end

        should("parse with title") do
          assert_parse_dtext(%(<details><summary>Click On Me</summary><div><p>test</p></div></details>), "[section=Click On Me]test[/section]")
        end

        should("parse expanded with title") do
          assert_parse_dtext(%(<details open><summary>Click On Me</summary><div><p>test</p></div></details>), "[section,expanded=Click On Me]test[/section]")
        end
      end

      context("[code]") do
        should("parse") do
          assert_parse_dtext(%(<pre>test</pre>), "[code]test[/code]")
        end

        should("parse with language") do
          assert_parse_dtext(%(<pre class="language-ruby">test</pre>), "[code=ruby]test[/code]")
        end
      end

      context("[table]") do
        should("parse") do
          assert_parse_dtext(%(<table class="striped"></table>), "[table][/table]")
        end

        context("[colgroup]") do
          should("parse") do
            assert_parse_dtext(%(<table class="striped"><colgroup></colgroup></table>), "[table][colgroup][/colgroup][/table]")
          end
        end

        context("[col]") do
          should("parse") do
            assert_parse_dtext(%(<table class="striped"><col></table>), "[table][col][/table]")
          end

          should("parse with attributes") do
            assert_parse_dtext(%(<table class="striped"><col align="left" span="2"></table>), "[table][col align=left span=2][/table]")
          end
        end

        context("[thead]") do
          should("parse") do
            assert_parse_dtext(%(<table class="striped"><thead></thead></table>), "[table][thead][/thead][/table]")
          end

          should("parse with attributes") do
            assert_parse_dtext(%(<table class="striped"><thead align="left"></thead></table>), "[table][thead align=left][/thead][/table]")
          end
        end

        context("[tbody]") do
          should("parse") do
            assert_parse_dtext(%(<table class="striped"><tbody></tbody></table>), "[table][tbody][/tbody][/table]")
          end

          should("parse with attributes") do
            assert_parse_dtext(%(<table class="striped"><tbody align="left"></tbody></table>), "[table][tbody align=left][/tbody][/table]")
          end
        end

        context("[tr]") do
          should("parse") do
            assert_parse_dtext(%(<table class="striped"><tr></tr></table>), "[table][tr][/tr][/table]")
          end

          should("parse with attributes") do
            assert_parse_dtext(%(<table class="striped"><tr align="left"></tr></table>), "[table][tr align=left][/tr][/table]")
          end
        end

        context("[th]") do
          should("parse") do
            assert_parse_dtext(%(<table class="striped"><th></th></table>), "[table][th][/th][/table]")
          end

          should("parse with attributes") do
            assert_parse_dtext(%(<table class="striped"><th align="left" colspan="2" rowspan="3"></th></table>), "[table][th align=left colspan=2 rowspan=3][/th][/table]")
          end
        end

        context("[td]") do
          should("parse") do
            assert_parse_dtext(%(<table class="striped"><td></td></table>), "[table][td][/td][/table]")
          end

          should("parse with attributes") do
            assert_parse_dtext(%(<table class="striped"><td align="left" colspan="2" rowspan="3"></td></table>), "[table][td align=left colspan=2 rowspan=3][/td][/table]")
          end
        end
      end

      context("[br]") do
        should("parse") do
          assert_parse_dtext(%(<p>test<br>test</p>), "test[br]test")
        end
      end

      context("[color]") do
        should("parse") do
          assert_parse_dtext(%(<p><span class="dtext-color" style="color: red">test</span></p>), "[color=red]test[/color]", allow_color: true)
        end

        should("not parse if allow_color is not enabled") do
          assert_parse_dtext(%(<p>test</p>), "[color=red]test[/color]")
        end

        context("named") do
          [*TagCategory.mapping.keys.map { |k| k.tr("_", "-") }, *Post::Ratings.map.keys, *Post::Ratings.map.values].each do |name|
            should("parse #{name}") do
              assert_parse_dtext(%(<p><span class="dtext-color-#{name}">test</span></p>), "[color=#{name}]test[/color]", allow_color: true)
            end
          end
        end
      end

      context("[note]") do
        should("parse") do
          assert_parse_dtext(%(<p class="dtext-note">test</p>), "[note]test[/note]")
        end
      end

      context("[b]") do
        should("parse") do
          assert_parse_dtext(%(<p><strong>test</strong></p>), "[b]test[/b]")
        end
      end

      context("[i]") do
        should("parse") do
          assert_parse_dtext(%(<p><em>test</em></p>), "[i]test[/i]")
        end
      end

      context("[s]") do
        should("parse") do
          assert_parse_dtext(%(<p><s>test</s></p>), "[s]test[/s]")
        end
      end

      context("[u]") do
        should("parse") do
          assert_parse_dtext(%(<p><u>test</u></p>), "[u]test[/u]")
        end
      end

      context("[sup]") do
        should("parse") do
          assert_parse_dtext(%(<p><sup>test</sup></p>), "[sup]test[/sup]")
        end
      end

      context("[sub]") do
        should("parse") do
          assert_parse_dtext(%(<p><sub>test</sub></p>), "[sub]test[/sub]")
        end
      end
    end

    context("mentions") do
      should("parse") do
        assert_parse_dtext(%(<p><a class="dtext-link dtext-user-mention-link" data-user-name="test" href="/users?name=test">@test</a></p>), "@test")
        assert_equal(["test"], DText.parse("@test")[:mentions])
      end

      should("parse within dtext element") do
        assert_parse_dtext(%(<blockquote><p><a class="dtext-link dtext-user-mention-link" data-user-name="test" href="/users?name=test">@test</a>:</p></blockquote>), "[quote]@test:\n[/quote]")
        assert_equal(["test"], DText.parse("[quote]@test:\n[/quote]")[:mentions])
      end

      should("not parse if mentions are disabled") do
        assert_parse_dtext(%(<p>@test</p>), "@test", disable_mentions: true)
        assert_equal([], DText.parse("@test", disable_mentions: true)[:mentions])
      end
    end

    context("lists") do
      should("parse") do
        assert_parse_dtext(%(<ul><li>test</li></ul>), "* test")
      end

      should("parse with multiple items") do
        assert_parse_dtext(%(<ul><li>test</li><li>test</li></ul>), "* test\n* test")
      end

      should("parse with nested items") do
        assert_parse_dtext(%(<ul><li>test</li><ul><li>test</li></ul></ul>), "* test\n** test")
      end

      should("parse with multi-nested items") do
        assert_parse_dtext(%(<ul><li>test</li><ul><li>test</li><ul><li>test</li></ul></ul></ul>), "* test\n** test\n*** test")
      end
    end

    context("links") do
      should("parse") do
        assert_parse_dtext(%(<p><a class="dtext-link" href="/test">test</a></p>), "\"test\":/test")
      end

      should("parse with respects to []") do
        assert_parse_dtext(%(<p><a class="dtext-link" href="/test">test</a>ing</p>), "\"test\":[/test]ing")
      end

      should("parse external") do
        assert_parse_dtext(%(<p><a rel="external nofollow noreferrer" class="dtext-link dtext-external-link" href="https://www.example.com">https://www.example.com</a></p>), "https://www.example.com")
      end

      should("parse external with respects to <>") do
        assert_parse_dtext(%(<p><a rel="external nofollow noreferrer" class="dtext-link dtext-external-link" href="https://www.example.com">https://www.example.com</a>hi</p>), "<https://www.example.com>hi")
      end

      should("parse external with name") do
        assert_parse_dtext(%(<p><a rel="external nofollow noreferrer" class="dtext-link dtext-external-link dtext-named-external-link" href="https://www.example.com">test</a></p>), "\"test\":https://www.example.com")
      end

      should("parse external with name with respects to []") do
        assert_parse_dtext(%(<p><a rel="external nofollow noreferrer" class="dtext-link dtext-external-link dtext-named-external-link" href="https://www.example.com">test</a>hi</p>), "\"test\":[https://www.example.com]hi")
      end
    end
  end
end

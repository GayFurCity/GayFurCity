#include "dtext.h"

#include <ruby.h>
#include <ruby/encoding.h>

static VALUE cDText = Qnil;
static VALUE cDTextError = Qnil;

static void validate_dtext(VALUE string) {
  // if input.encoding != Encoding::UTF_8 || input.encoding != Encoding::USASCII
  int encoding = rb_enc_get_index(string);
  if (encoding != rb_usascii_encindex() && encoding != rb_utf8_encindex()) {
    rb_raise(cDTextError, "input must be US-ASCII or UTF-8");
  }

  // if !input.valid_encoding?
  // https://github.com/ruby/ruby/blob/2d9812713171097eb4a3f38e49d9be39d90da2f6/string.c#L10847
  if (rb_enc_str_coderange(string) == ENC_CODERANGE_BROKEN) {
    rb_raise(cDTextError, "input contains invalid UTF-8");
  }

  if (memchr(RSTRING_PTR(string), 0, RSTRING_LEN(string))) {
    rb_raise(cDTextError, "input contains null byte");
  }
}

static auto parse_dtext(VALUE input, DTextOptions options = {}) {
  try  {
    StringValue(input);
    validate_dtext(input);

    std::string_view dtext(RSTRING_PTR(input), RSTRING_LEN(input));
    return StateMachine::parse_dtext(dtext, options);
  } catch (std::exception& e) {
    rb_raise(cDTextError, "%s", e.what());
  }
}

static VALUE c_parse(VALUE self, VALUE input, VALUE base_url, VALUE domain, VALUE internal_domains, VALUE github_url, VALUE f_inline, VALUE f_disable_mentions, VALUE f_allow_color, VALUE f_qtags, VALUE max_thumbs) {
  if (NIL_P(input)) {
    return Qnil;
  }

  DTextOptions options;
  options.f_inline = RTEST(f_inline);
  options.f_mentions = !RTEST(f_disable_mentions);
  options.f_allow_color = RTEST(f_allow_color);
  options.f_qtags = RTEST(f_qtags);
  options.max_thumbs = FIX2LONG(max_thumbs);

  if (!NIL_P(base_url)) {
    options.base_url = StringValueCStr(base_url); // base_url.to_str # raises ArgumentError if base_url contains null bytes.
  }

  if (!NIL_P(domain)) {
    options.domain = StringValueCStr(domain); // domain.to_str # raises ArgumentError if domain contains null bytes.
  }

  if (!NIL_P(github_url)) {
    options.github_url = StringValueCStr(github_url); // github_url.to_str # raises ArgumentError if github_url contains null bytes.
  }

  Check_Type(internal_domains, T_ARRAY); // raises TypeError if the argument isn't an array.

  for (int i = 0; i < RARRAY_LEN(internal_domains); i++) {
    VALUE rb_domain = rb_ary_entry(internal_domains, i);
    std::string domain = StringValueCStr(rb_domain); // raise ArgumentError if the domain contains null bytes.
    options.internal_domains.insert(domain);
  }

  auto [dtext, wiki_pages, posts, mentions, qtags] = parse_dtext(input, options);
  VALUE retStr = rb_utf8_str_new(dtext.c_str(), dtext.size());
  VALUE retWikiPages = rb_ary_new_capa(wiki_pages.size());
  VALUE retPostIds = rb_ary_new_capa(posts.size());
  VALUE retMentions = rb_ary_new_capa(mentions.size());
  VALUE retQtags = rb_ary_new_capa(qtags.size());

  VALUE ret = rb_hash_new();
  rb_hash_aset(ret, ID2SYM(rb_intern("dtext")), retStr);
  rb_hash_aset(ret, ID2SYM(rb_intern("wiki_pages")), retWikiPages);
  rb_hash_aset(ret, ID2SYM(rb_intern("post_ids")), retPostIds);
  rb_hash_aset(ret, ID2SYM(rb_intern("mentions")), retMentions);
  rb_hash_aset(ret, ID2SYM(rb_intern("qtags")), retQtags);

  for (auto wiki_page : wiki_pages) {
    rb_ary_push(retWikiPages, rb_str_new(wiki_page.data(), wiki_page.size()));
  }

  for (long post_id : posts) {
    rb_ary_push(retPostIds, LONG2FIX(post_id));
  }

  for (std::string mention : mentions) {
    rb_ary_push(retMentions, rb_utf8_str_new(mention.c_str(), mention.size()));
  }

  for (std::string qtag : qtags) {
    rb_ary_push(retQtags, rb_utf8_str_new(qtag.c_str(), qtag.size()));
  }

  return ret;
}

extern "C" void Init_dtext() {
  cDText = rb_define_class("DText", rb_cObject);
  cDTextError = rb_define_class_under(cDText, "Error", rb_eStandardError);
  rb_define_singleton_method(cDText, "c_parse", c_parse, 10);
}

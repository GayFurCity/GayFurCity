# DText Grammar Reference

DText is a lightweight markup language parsed by a Ragel-based state machine. This document describes all recognized syntax, restrictions, and output behavior.

---

## Table of Contents

1. [Parser Modes & Options](#parser-modes--options)
2. [Block Elements](#block-elements)
3. [Inline Elements](#inline-elements)
4. [Links](#links)
5. [ID Links (Auto-links)](#id-links-auto-links)
6. [Wiki Links](#wiki-links)
7. [Post Search Links](#post-search-links)
8. [Internal Anchor Targets and Links](#internal-anchor-targets-and-links)
9. [Mentions](#mentions)
10. [Qtags](#qtags)
11. [HTML Entities](#html-entities)
12. [Tables](#tables)
13. [Nesting & Error Recovery](#nesting--error-recovery)

---

## Parser Modes & Options

The parser accepts options that change behavior:

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `inline` | bool | false | Strip all block-level elements; newlines become spaces |
| `disable_mentions` (f_mentions=false) | bool | false | Ignore `@username` and `<@username>` |
| `allow_color` (f_allow_color) | bool | false | Enable `[color=...]` tags |
| `qtags` (f_qtags) | bool | false | Enable `#tag` qtag links |
| `base_url` | string | "" | Prefix prepended to relative URLs in output |
| `domain` | string | "" | Domain treated as "internal" (no `rel="external nofollow noreferrer"`) |
| `internal_domains` | string[] | [] | Domains whose URLs are converted to shortlinks (e.g. `post #1234`) |
| `max_thumbs` | int | 0 | Maximum number of `thumb #N` thumbnails to render as `thumb-placeholder-link` |

**Inline mode**: All block tags (`[quote]`, `[section]`, `[code]`, headers, tables, lists) are ignored or collapsed. Paragraph breaks become a single space.

---

## Block Elements

Block elements must appear at the start of a line (or after another block closer). When encountered mid-inline-context, they close any open inline elements first.

### Paragraphs

Plain text is wrapped in `<p>...</p>`. A single newline produces `<br>`. Two or more newlines (with optional whitespace-only lines in between) end one paragraph and begin another.

```
hello world         → <p>hello world</p>
line one            → <p>line one<br>line two</p>
line two

para one            → <p>para one</p><p>para two</p>
para two
```

### Headers

```
h1. Title           → <h1>Title</h1>
h2. Title           → <h2>Title</h2>
h3. Title           → ...
h4. Title
h5. Title
h6. Title
```

Headers with explicit IDs:

```
h1#my-anchor. Title → <h1 id="dtext-my-anchor">Title</h1>
h2#See_Also. Title  → <h2 id="dtext-see-also">Title</h2>
```

**ID rules**: Characters after `#` and before `.` may be `[alnum _/#!:&-]`. Non-alphanumeric characters are normalized to `-` in the output `id` attribute. The `dtext-` prefix is always prepended to prevent conflicts with native anchors.

Header IDs must not contain spaces — `h1#See Also. Title` is **not** recognized as a header with an ID.

Headers consume the rest of the line; inline tags inside a header are parsed normally except that `<br>` is escaped as literal `&lt;br&gt;`.

### Horizontal Rule

```
[hr]    → <hr>
[HR]    → <hr>
<hr>    → <hr>
```

Optional leading/trailing whitespace is consumed. `[hr]` is only recognized when it occupies the entire line (or with only whitespace neighbors). Mid-line `x[hr]` is **not** recognized.

### Quote Block

```
[quote]
content
[/quote]
```

Also accepted: `<quote>...</quote>`, `<blockquote>...</blockquote>`. Mix-and-match open/close variants are allowed.

- Opens a `<blockquote>` container block.
- All block and inline content is allowed inside.
- Nested `[quote]` blocks are supported.
- The `[/quote]` close tag is only active when a `[quote]` is open on the stack.
- Unclosed quotes are closed at EOF.

### Spoiler Block

```
[spoiler]
hidden content
[/spoiler]
```

Also accepted: `[spoilers]`, `<spoiler>`, `<spoilers>` (open); `[/spoilers]`, `</spoiler>`, `</spoilers>` (close).

- Inline variant: `[spoiler]text[/spoiler]` → `<span class="spoiler">text</span>`
- Block variant (newline before content or two newlines before `[spoiler]`) → `<div class="spoiler">...</div>`
- Nested spoilers are supported.
- The `[/spoiler]` close is only active when a spoiler is open. Otherwise it renders literally.

### Section (Details/Summary)

Anonymous (collapsed by default):
```
[section]
content
[/section]
```

Named (with summary text):
```
[section=Title]content[/section]
[section Title]content[/section]
[section = Title]content[/section]
```

Expanded (open by default):
```
[section,expanded]content[/section]
[section,expanded=Title]content[/section]
[section,expanded Title]content[/section]
```

Also accepted with `<section>...</section>` HTML-like syntax:
```
<section>content</section>
<section=Title>content</section>
<section,expanded=Title>content</section>
```

Output structure:
```html
<details><summary>Title</summary><div>content</div></details>
<!-- with ,expanded: -->
<details open><summary>Title</summary><div>content</div></details>
```

**Restrictions**:
- Section tags must be on their own line to act as a block; mid-inline `[section=...]` is rendered literally.
- The title may not contain newlines.
- `[sectionhello]` (no space/equals separator) is **not** recognized.

### Code Block

```
[code]
preformatted content
[/code]
```

With language hint:
```
[code=ruby]
x = 1
[/code]
```

Also accepted: `<code>...</code>`, `<code=lang>...</code>`.

- Renders as `<pre>content</pre>` or `<pre class="language-LANG">content</pre>`.
- All DText markup inside is treated as literal text (HTML-escaped).
- An optional blank line immediately after the opening tag is consumed.
- A leading `\n` before the close tag is consumed.

Inline variant (when code does not start on its own line):
```
[code]text[/code]     → <code>text</code>
[code=ruby]text[/code] → <code class="language-ruby">text</code>
```

Language values must match `[alnum]+`; otherwise the tag is rendered literally.

Backtick inline code:
```
`code here`    → <span class="inline-code">code here</span>
\`             → literal backtick (escape)
```

### Nodtext

Disables DText parsing for enclosed content:
```
[nodtext]**not bold**[/nodtext]    → **not bold** (literal)
<nodtext>...</nodtext>
```

- Content is HTML-escaped but not otherwise parsed.
- Works inline or block.

### Note

```
[note]content[/note]
<note>content</note>
```

- Block variant (on own line): `<p class="dtext-note">content</p>`
- Inline variant: `<span class="dtext-note">content</span>`

### Unordered Lists

```
* item one
* item two
** nested item
*** doubly nested
```

- Each `*` line must have at least one space after the asterisk(s) and non-whitespace content.
- Nesting level is determined by the number of leading `*` characters.
- A blank line ends the list.
- Inline tags are supported within list items.
- `[hr]` and block-level tags on a list item line are treated literally.

Output:
```html
<ul>
  <li>item one</li>
  <li>item two
    <ul><li>nested item</li></ul>
  </li>
</ul>
```

### Line Break Tag

```
[br]    → <br>
[BR]    → <br>
<br>    → <br>
<BR>    → <br>
```

Inside headers, `<br>` is HTML-escaped to `&lt;br&gt;`.

---

## Inline Elements

Inline elements can appear anywhere within paragraph, list, header, quote, spoiler, section, note, and table cell contexts.

All tags are **case-insensitive** (`[B]`, `[b]`, `[B]` all work).

### Bold

```
[b]text[/b]         → <strong>text</strong>
<b>text</b>
<strong>text</strong>
```

### Italic

```
[i]text[/i]         → <em>text</em>
<i>text</i>
<em>text</em>
```

### Strikethrough

```
[s]text[/s]         → <s>text</s>
<s>text</s>
```

### Underline

```
[u]text[/u]         → <u>text</u>
<u>text</u>
```

### Superscript

```
[sup]text[/sup]     → <sup>text</sup>
<sup>text</sup>
```

### Subscript

```
[sub]text[/sub]     → <sub>text</sub>
<sub>text</sub>
```

### Inline Spoiler

```
[spoiler]text[/spoiler]   → <span class="spoiler">text</span>
```

When `[spoiler]` appears after a newline followed by end-of-line, it switches to block mode (see [Spoiler Block](#spoiler-block)).

### Inline Color (requires `allow_color: true`)

Named CSS color or hex:
```
[color=red]text[/color]       → <span class="dtext-color" style="color: red">text</span>
[color=#FF0000]text[/color]   → <span class="dtext-color" style="color: #FF0000">text</span>
```

Typed/semantic color categories:
```
[color=gen]text[/color]         → <span class="dtext-color-gen">text</span>
[color=general]text[/color]     → <span class="dtext-color-general">text</span>
```

Accepted typed color keywords (case-insensitive):
`gen`, `general`, `art`, `artist`, `cont`, `contributor`, `oc`, `ch`, `char`, `character`, `co`, `copy`, `copyright`, `spec`, `species`, `inv`, `invalid`, `meta`, `lor`, `lore`, `gender`, `imp`, `important`, `s`, `safe`, `q`, `questionable`, `e`, `explicit`

If `allow_color` is false, `[color=...]` tags are silently ignored (content is still rendered).

### Topic Tag

```
[topic=1234]Title Text[/topic]   → <a class="dtext-link dtext-forum-topic-link" href="/forums/topics/1234">Topic: Title Text</a>
```

---

## Links

### Bare Absolute URLs

Any URL beginning with `http://` or `https://` (case-insensitive) followed by a valid domain is auto-linked.

```
http://example.com        → linked
https://example.com/path  → linked
Http://example.com        → linked (case-insensitive scheme)
```

**Trailing boundary characters** are excluded from the URL: `"`, `'`, `;`, `,`, `.`, `?`. Closing `)` is trimmed if unbalanced. Unicode boundary chars (CJK brackets, etc.) are also excluded.

URLs must start at a word boundary (not preceded by alphanumeric text like `blahhttp://`).

### Delimited Absolute URL

```
<http://example.com>      → linked (unnamed)
<https://example.com>     → linked (unnamed)
```

### Textile-Style Named Links

```
"Title":http://example.com          → named link
"Title":https://example.com/path
"Title":/relative/path              → internal link (no rel="external")
"Title":#fragment                   → fragment link
"Title"://example.com               → treated as http://example.com
```

Bracketed variant (allows parentheses and special chars in URL):
```
"Title":[http://example.com/(path)]
"Title":[/relative/path]
"Title":[#fragment]
```

### BBCode URL Links

Unnamed (URL is the display text):
```
[url]http://example.com[/url]       → unnamed link
[url]/relative/path[/url]           → internal link
```

Named:
```
[url=http://example.com]Title[/url]
[url="http://example.com"]Title[/url]
[url='http://example.com']Title[/url]
[url = http://example.com]Title[/url]
```

The URL must be an absolute URL (`http(s)://...`) or a relative URL (`/path` or `#fragment`). Non-URL values are rendered literally.

### Markdown-Style Links

Standard (text then URL):
```
[text](http://example.com)     → named link
[text](/relative/path)         → internal link
[text](#fragment)              → fragment link
```

Backwards (URL then text):
```
[http://example.com](text)     → named link
[/relative/path](text)         → internal link
```

**Restrictions for markdown links**:
- The URL in `(...)` must start with `http://`, `https://`, `/`, or `#`.
- The URL may not contain spaces.
- `[b]`, `[i]`, `[/b]`, and other DText tag names in the bracket position are **not** treated as link text.
- `[nodtext]` in the bracket disables the link entirely.

### HTML-Style Links

```
<a href="http://example.com">text</a>
<a href="/relative">text</a>
<a href="#fragment">text</a>
```

Only `href` attribute is used; all other attributes are ignored. The link text may contain inline DText markup.

### Internal vs External Links

- Links to the configured `domain` get class `dtext-link` (no `rel` attribute).
- All other absolute links get `rel="external nofollow noreferrer"` and class `dtext-link dtext-external-link`.
- Named external links additionally get class `dtext-named-external-link`.
- Relative links (`/path`, `#fragment`) always get class `dtext-link`.

---

## ID Links (Auto-links)

The following text patterns are automatically converted to links. ID must be one or more digits.

| Input Pattern | Link Text | URL |
|---|---|---|
| `post #N` | `post #N` | `/posts/N` |
| `thumb #N` | `post #N` | `/posts/N` (with `thumb-placeholder-link` class up to `max_thumbs`) |
| `post changes #N` | `post changes #N` | `/posts/versions?search[post_id]=N` |
| `post changes #N:V` | `post changes #N` | `/posts/versions?search[post_id]=N&search[version]=V` |
| `flag #N` | `flag #N` | `/posts/flags/N` |
| `note #N` | `note #N` | `/notes/N` |
| `forum #N` | `forum #N` | `/forums/posts/N` |
| `forum post #N` | `forum #N` | `/forums/posts/N` |
| `topic #N` | `topic #N` | `/forums/topics/N` |
| `forum topic #N` | `topic #N` | `/forums/topics/N` |
| `topic #N/pP` | `topic #N (page P)` | `/forums/topics/N?page=P` |
| `forum topic #N/pP` | `topic #N (page P)` | `/forums/topics/N?page=P` |
| `category #N` | `category #N` | `/forums/categories/N` |
| `forum category #N` | `category #N` | `/forums/categories/N` |
| `comment #N` | `comment #N` | `/comments/N` |
| `dmail #N` | `dmail #N` | `/dmails/N` |
| `dmail #N/KEY` | `dmail #N` | `/dmails/N?key=KEY` |
| `pool #N` | `pool #N` | `/pools/N` |
| `user #N` | `user #N` | `/users/N` |
| `artist #N` | `artist #N` | `/artists/N` |
| `artist changes #N` | `artist changes #N` | `/artists/versions?search[artist_id]=N` |
| `ban #N` | `ban #N` | `/bans/N` |
| `bur #N` | `BUR #N` | `/bulk_update_requests/N` |
| `alias #N` | `alias #N` | `/tags/aliases/N` |
| `implication #N` | `implication #N` | `/tags/implications/N` |
| `mod action #N` | `mod action #N` | `/mod_actions/N` |
| `record #N` | `record #N` | `/users/feedbacks/N` |
| `wiki #N` | `wiki #N` | `/wiki_pages/N` |
| `wiki page #N` | `wiki #N` | `/wiki_pages/N` |
| `wiki page changes #N` | `wiki changes #N` | `/wiki_pages/versions?search[wiki_page_id]=N` |
| `set #N` | `set #N` | `/post_sets/N` |
| `ticket #N` | `ticket #N` | `/tickets/N` |
| `takedown #N` | `takedown #N` | `/takedowns/N` |
| `take down request #N` | `takedown #N` | `/takedowns/N` |
| `dnp #N` | `avoid posting #N` | `/avoid_postings/N` |
| `avoid posting #N` | `avoid posting #N` | `/avoid_postings/N` |
| `issue #N` | `issue #N` | `https://github.com/GayFurCity/GayFurCity/issues/N` |
| `pull #N` | `pull #N` | `https://github.com/GayFurCity/GayFurCity/pull/N` |
| `commit #N` | `commit #N` | `https://github.com/GayFurCity/GayFurCity/commit/N` |

**Notes**:
- Patterns are case-insensitive.
- The word before `#` must exactly match (e.g. `shitpost #24` is **not** recognized).
- `dmail #N/KEY` — KEY may contain alphanumerics, `=`, and `-`.
- `forum` prefix is optional for `forum topic`, `forum post`, `forum category`.
- `wiki page` — "page" is optional; `wiki #N` and `wiki page #N` both work.

### Internal Domain URL to Shortlink Conversion

When `internal_domains` is set, absolute URLs to those domains are converted to the equivalent shortlink:

```
https://example.com/posts/1234      → post #1234
https://example.com/pools/1234      → pool #1234
https://example.com/comments/1234   → comment #1234
https://example.com/users/1234      → user #1234
https://example.com/artists/1234    → artist #1234
https://example.com/notes/1234      → note #1234
https://example.com/post_sets/1234  → set #1234
https://example.com/wiki_pages/1234 → wiki #1234
https://example.com/wiki_pages/tag  → [[tag]] wiki link
https://example.com/forums/posts/N  → forum #N
https://example.com/forums/topics/N → topic #N
https://example.com/forums/categories/N → category #N
```

Exceptions (not converted, kept as full links):
- `/posts/N#fragment` (has fragment)
- `/pools/N?page=...` (has query)
- `/post_sets/N?page=...` (has query)
- `/forums/topics/N?page=...` (has query)
- `/forums/topics/N#fragment` (has fragment)
- `/wiki_pages/N#fragment` (has fragment)

---

## Wiki Links

```
[[tag]]                     → link to wiki page for "tag"
[[tag|Display Title]]       → link with custom title
[[tag#Section Header]]      → link with anchor
[[tag#Section Header|Title]] → link with anchor and custom title
```

**Prefix/suffix expansion**:
```
19[[60s]]       → link target: "60s", display text: "1960s"
[[cat]]s        → link target: "cat", display text: "cats"
a[[b|c]]d       → link target: "b", display text: "acd"
```

**Pipe trick** (empty title strips qualifier):
```
[[foo (bar)|]]       → display text: "foo" (strips trailing qualifier)
[[Kaga (Kantai Collection)|]] → display text: "Kaga"
```

**Anchor normalization**: Non-alphanumeric characters in anchor text are replaced with `-` and lowercased.
```
[[touhou#See Also]]  → href ends with #see-also
[[touhou#See_Also]]  → href ends with #see-also
[[touhou#See-Also]]  → href ends with #see-also
```

**Internal anchor links**:
```
[[#anchor]]          → <a class="dtext-link dtext-internal-anchor-link" href="#anchor">anchor</a>
[[#anchor|Title]]    → custom display title
```

**Tag normalization**: Spaces become underscores, characters are lowercased in the URL:
```
[[Kantai Collection]] → href: /wiki_pages/show_or_new?title=kantai_collection
```

Numeric-only tags link directly to `/wiki_pages/N`.

**Special emoticon tags** that contain `|` are supported as wiki targets:
`|3`, `:|`, `|_|`, `||_||`, `\||/`, `<|>_<|>`, `>:|`, `>|3`, `|w|`

Output:
```html
<a rel="nofollow" class="dtext-link dtext-wiki-link" href="/wiki_pages/show_or_new?title=tag">display</a>
```

---

## Post Search Links

```
{{tag}}                      → search link for tag
{{tag1 tag2}}                → multi-tag search
{{tag|Display Title}}        → named search link
{{tag|}}                     → pipe trick (strips qualifier from display)
```

**Prefix/suffix expansion** (same rules as wiki links):
```
19{{60s}}        → link target: "60s", display: "1960s"
{{cat}}s         → link target: "cat", display: "cats"
b{{c|d}}e        → link target: "c", display: "bde"
```

**Pipe trick**:
```
{{bb_(fate)|}}   → display: "bb" (qualifier stripped)
```

Tags may contain spaces (for multi-tag searches). Tags may include emoticon patterns.

Output:
```html
<a class="dtext-link dtext-post-search-link" href="/posts?tags=ENCODED_TAGS">display</a>
```

**Non-working cases** (render literally):
- `{{}}` — empty
- `{{ }}` — whitespace only
- `{{tag\nmore}}` — newlines inside

---

## Internal Anchor Targets and Links

Place a named anchor (target):
```
[#anchor-name]    → <a id="anchor-name"></a>
```

Anchor names may contain `[alnum _-]`. The name is lowercased in the output `id`.

Link to an anchor on the current page:
```
[[#anchor-name]]             → <a href="#anchor-name">anchor-name</a>
[[#anchor-name|Title]]       → <a href="#anchor-name">Title</a>
```

---

## Mentions

Requires `f_mentions` option (enabled by default, disable with `disable_mentions: true`).

### Bare Mention

```
@username
```

Must appear after a boundary character: start of string, `\n`, `\r`, ` `, `/`, `"`, `'`, `(`, `)`, `[`, `]`, `{`, `}`.

**Username rules**:
- Minimum 2 characters.
- May not start or end with punctuation (exception: may start with `_` or `.` if the next character is non-punctuation).
- The second character may not be `@`.
- Allowed internal characters: letters, digits, `.`, `_`, `/`, `'`, `-`, `+`, `!`
- May not end in `'s` or `'d`.
- Trailing punctuation (`.`, `,`, `?`, `!`, `:`, `;`) is excluded from the username.

```
@evazion          → valid
@_cf              → valid (starts with _)
@.dank            → valid (starts with .)
@kia'ra           → valid
@T34/38           → valid
@F/A-18F          → valid
@.k1.38+23        → valid
@T!ramisu         → valid

@N                → invalid (too short)
@@                → invalid (second char is @)
@.@               → invalid (ends with boundary char)
@-like            → invalid (starts with -)
@'d               → invalid (ends with 'd)
@user's           → parses as @user (strips 's)
```

Output:
```html
<a class="dtext-link dtext-user-mention-link" data-user-name="username" href="/users?name=username">@username</a>
```

### Delimited Mention

```
<@username>       → mention (spaces/special chars allowed in name)
<@NWF Renim>      → valid
```

No boundary restriction. The name runs until `>`.

---

## Qtags

Requires `f_qtags` option (`qtags: true`).

```
#tagname
```

Same boundary rules as bare mentions. Links to `/q/tagname`.

Output:
```html
<a class="dtext-link dtext-qtag-link" data-qtag-name="tagname" href="/q/tagname">#tagname</a>
```

---

## HTML Entities

The following HTML entities are recognized and passed through or decoded:

| Entity | Output |
|--------|--------|
| `&amp;` | `&amp;` (kept as-is) |
| `&lt;` | `&lt;` (kept as-is) |
| `&gt;` | `&gt;` (kept as-is) |
| `&quot;` | `&quot;` (kept as-is) |
| `&#39;` | `'` (apostrophe) |
| `&apos;` | `'` (apostrophe) |
| `&lbrace;` | `{` |
| `&lbrack;` | `[` |
| `&ast;` | `*` |
| `&colon;` | `:` |
| `&commat;` | `@` |
| `&grave;` | `` ` `` |
| `&num;` | `#` |
| `&period;` | `.` |

These can be used to prevent DText from parsing the resulting character. For example:
- `&ast; list item` → literal `* list item` (not a list)
- `&num;tag` → literal `#tag` (not a qtag)
- `&commat;user` → literal `@user` (not a mention)
- `h4&period; header` → literal `h4. header` (not a heading)

All other `<`, `>`, `&`, `"` in input are HTML-escaped in output.

---

## Tables

```
[table]
  [thead]
    [tr]
      [th]Header[/th]
    [/tr]
  [/thead]
  [tbody]
    [tr]
      [td]Cell[/td]
    [/tr]
  [/tbody]
[/table]
```

Also accepted with `<table>`, `<thead>`, etc. HTML-like syntax.

**Structure tags**: `table`, `colgroup`, `col`, `thead`, `tbody`, `tr`, `th`, `td`

**Permitted attributes per tag**:

| Tag | Permitted Attributes |
|-----|---------------------|
| `thead` | `align` |
| `tbody` | `align` |
| `tr` | `align` |
| `td` | `align`, `colspan`, `rowspan` |
| `th` | `align`, `colspan`, `rowspan` |
| `col` | `align`, `span` |
| `colgroup` | *(none)* |

**Attribute value restrictions**:
- `align`: must be one of `left`, `center`, `right`, `justify`
- `colspan`, `rowspan`, `span`: must be digits only

Invalid or unrecognized attributes are silently dropped.

**Attribute syntax**:
```
[td colspan=2]             → unquoted
[td colspan="2"]           → double-quoted
[td colspan='2']           → single-quoted
[td colspan = "2"]         → spaces around =
[td colspan=2 rowspan=3]   → multiple attributes (space-separated)
```

Attributes must be separated by at least one space. No newlines allowed inside tag attributes.

**Cell content**: `[td]` and `[th]` cells invoke the inline parser. All inline markup is supported inside cells.

**Table must be on its own line**: A `[table]` encountered mid-inline does not start a table block.

Output: `<table class="striped">...</table>`

---

## Nesting & Error Recovery

### Container vs Leaf Blocks

- **Container blocks** (can contain other blocks): `[quote]`, `[spoiler]`, `[section]`, `[note]`
- **Leaf blocks** (cannot contain other blocks): `[code]`, `[nodtext]`, `[table]`, `<h1>`–`<h6>`, `<p>`, `<li>`, `<ul>`

### Stack-Based Parsing

The parser maintains a stack of open elements (`dstack`). Maximum stack depth is 512.

### Out-of-Order Closing Tags

- Inline close tags that don't match the innermost open inline tag will close the innermost open inline element instead (graceful recovery).
- Block close tags that don't match an open block element are rendered as literal text.

### Unclosed Tags

All open tags are auto-closed at EOF or when a conflicting block-level element is encountered.

### Block-Level Interruption

Starting a new block element (header, `[code]`, `[table]`, `[section]`, `[hr]`) while inside inline content closes the current paragraph/inline context first.

### `[/quote]`, `[/section]`, `[/spoiler]` Outside Their Blocks

Close tags for container blocks render as literal text when no corresponding open tag is on the stack:
```
[/quote] → [/quote] (literal, inside a <p>)
</quote> → &lt;/quote&gt; (HTML-escaped)
```

### CRLF Normalization

All `\r\n` sequences are normalized to `\n` before parsing. Lone `\r` becomes a space.

### Null Bytes

Null bytes (`\0`) in input cause a `DText::Error` to be raised.

### Invalid Encodings

Input must be valid UTF-8 or US-ASCII. Invalid byte sequences cause a `DText::Error`.

---

## Output CSS Classes Reference

| Class | Element | Meaning |
|-------|---------|---------|
| `dtext-link` | `<a>` | Any DText-generated link |
| `dtext-external-link` | `<a>` | Link to an external domain |
| `dtext-named-external-link` | `<a>` | Named link to external domain (title ≠ URL) |
| `dtext-wiki-link` | `<a>` | Wiki page link (`[[...]]`) |
| `dtext-post-search-link` | `<a>` | Post search link (`{{...}}`) |
| `dtext-internal-anchor-link` | `<a>` | Link to internal anchor (`[[#...]]`) |
| `dtext-id-link` | `<a>` | Auto-generated ID link |
| `dtext-post-id-link` | `<a>` | `post #N` link |
| `dtext-pool-id-link` | `<a>` | `pool #N` link |
| `dtext-comment-id-link` | `<a>` | `comment #N` link |
| `dtext-note-id-link` | `<a>` | `note #N` link |
| `dtext-forum-post-id-link` | `<a>` | `forum #N` link |
| `dtext-forum-topic-id-link` | `<a>` | `topic #N` link |
| `dtext-forum-category-id-link` | `<a>` | `category #N` link |
| `dtext-forum-topic-link` | `<a>` | `[topic=N]` link |
| `dtext-user-id-link` | `<a>` | `user #N` link |
| `dtext-artist-id-link` | `<a>` | `artist #N` link |
| `dtext-ban-id-link` | `<a>` | `ban #N` link |
| `dtext-bulk-update-request-id-link` | `<a>` | `bur #N` link |
| `dtext-tag-alias-id-link` | `<a>` | `alias #N` link |
| `dtext-tag-implication-id-link` | `<a>` | `implication #N` link |
| `dtext-mod-action-id-link` | `<a>` | `mod action #N` link |
| `dtext-user-feedback-id-link` | `<a>` | `record #N` link |
| `dtext-wiki-page-id-link` | `<a>` | `wiki #N` link |
| `dtext-dmail-id-link` | `<a>` | `dmail #N` link |
| `dtext-set-id-link` | `<a>` | `set #N` link |
| `dtext-ticket-id-link` | `<a>` | `ticket #N` link |
| `dtext-avoid-posting-id-link` | `<a>` | `avoid posting #N` / `dnp #N` link |
| `dtext-takedown-id-link` | `<a>` | `takedown #N` link |
| `dtext-post-changes-for-id-link` | `<a>` | `post changes #N` link |
| `dtext-post-changes-for-id-version-link` | `<a>` | `post changes #N:V` link |
| `dtext-github-id-link` | `<a>` | `issue #N` link |
| `dtext-github-pull-id-link` | `<a>` | `pull #N` link |
| `dtext-github-commit-id-link` | `<a>` | `commit #N` link |
| `dtext-user-mention-link` | `<a>` | `@username` mention |
| `dtext-qtag-link` | `<a>` | `#tag` qtag |
| `thumb-placeholder-link` | `<a>` | `thumb #N` within `max_thumbs` limit |
| `spoiler` | `<span>` / `<div>` | Spoiler content |
| `dtext-note` | `<span>` / `<p>` | Note content |
| `dtext-color` | `<span>` | `[color=hex/name]` with `style` attribute |
| `dtext-color-CATEGORY` | `<span>` | `[color=CATEGORY]` typed color |
| `inline-code` | `<span>` | Backtick inline code |
| `striped` | `<table>` | All DText tables |
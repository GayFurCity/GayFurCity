# frozen_string_literal: true

# rdoc
#   A tag set represents a set of tags that are displayed together.
#   This class makes it easy to fetch the categories for all the
#   tags in one call instead of fetching them sequentially.

class TagSetPresenter < ApplicationPresenter
  attr_reader(:tag_names)

  # @param [Array<String>] tag_names a list of tags to present. Tags will be presented in
  # the order given. The list should not contain duplicates. The list may
  # contain tags that do not exist in the tags table, such as metatags.
  # @param [Array<Hash>] character_groups optional, as returned by Post#character_groups_for_api
  # ({ characters: [...], tags: [...] }) - only used by post_show_sidebar_tag_list_html, when the
  # viewer has character tag grouping enabled.
  def initialize(tag_names, character_groups: [], helper: nil, view: nil)
    super(helper, view)
    @tag_names = tag_names
    @character_groups = character_groups
  end

  def post_index_sidebar_tag_list_html(followed_tags:, current_query: "")
    html = []
    if ordered_tags.present?
      ordered_tags.each do |tag|
        html << build_list_item(tag, current_query: current_query, followed: followed_tags.include?(tag.name))
      end
    end

    h.tag.ul(safe_join(html))
  end

  def post_show_sidebar_tag_list_html(highlighted_tags:, followed_tags:, current_query: "")
    if @character_groups.present? && !CurrentUser.user.disable_character_tag_grouping?
      return post_show_sidebar_grouped_tag_list_html(highlighted_tags: highlighted_tags, followed_tags: followed_tags, current_query: current_query)
    end

    category_sections_html(ordered_tags, highlighted_tags: highlighted_tags, followed_tags: followed_tags, current_query: current_query)
  end

  # Same tags, but split into one section per character (further split by category within
  # each), followed by a General section (also split by category) for everything not
  # attributed to a character.
  def post_show_sidebar_grouped_tag_list_html(highlighted_tags:, followed_tags:, current_query: "")
    html = []
    tags_by_name = ordered_tags.index_by(&:name)
    unnamed_index = 0
    grouped_names = []

    @character_groups.each do |group|
      character_names = Array(group[:characters])
      attribute_tags = Array(group[:tags]).filter_map { |name| tags_by_name[name] }
      grouped_names.concat(character_names, group[:tags])

      label =
        if character_names.any?
          safe_join(character_names.map { |name| character_group_name_html(name) }, ", ")
        else
          unnamed_index += 1
          "Unnamed Character ##{unnamed_index}"
        end

      section_html = category_sections_html(attribute_tags, highlighted_tags: highlighted_tags, followed_tags: followed_tags, current_query: current_query)
      html << character_group_section_html(label, section_html)
    end

    ungrouped = ordered_tags.reject { |tag| grouped_names.include?(tag.name) }
    if ungrouped.any?
      section_html = category_sections_html(ungrouped, highlighted_tags: highlighted_tags, followed_tags: followed_tags, current_query: current_query)
      section_html = character_group_section_html("Ungrouped", section_html, header_class: "character-group-header general-character-group-header") if @character_groups.any?
      html << section_html
    end

    safe_join(html)
  end

  # compact (horizontal) list, as seen in the /comments index.
  def inline_tag_list_html(link_type = :tag)
    tags = safe_join(TagCategory::CATEGORIZED_LIST.map do |category|
      tags_for_category(category).map do |tag|
        category = tag.antecedent_alias&.consequent_tag&.category || category
        h.tag.li(tag_link(tag, tag.name, link_type), class: "category-#{tag.category}")
      end
    end)
    h.tag.ul(tags, class: "inline-tag-list")
  end

  # the list of tags inside the tag box in the post edit form.
  def split_tag_list_text
    TagCategory::CATEGORIZED_LIST.map do |category|
      tags_for_category(category).map(&:name).join(" ")
    end.compact_blank.join(" \n")
  end

  def humanized_essential_tag_string(category_list: TagCategory::HUMANIZED_LIST, default: "")
    @humanized_essential_tag_string ||= begin
      strings = category_list.map do |category|
        mapping = TagCategory.get(category)
        max_tags = mapping.limit || 0
        regexmap = mapping.regex || //
        formatstr = mapping.formatstr || "%s"
        excluded_tags = mapping.exclusion || []

        type_tags = tags_for_category(category).map(&:name) - excluded_tags
        next if type_tags.empty?

        if max_tags > 0 && type_tags.length > max_tags
          type_tags = type_tags.sort_by { |x| -x.size }.take(max_tags) + ["etc"]
        end

        if regexmap != //
          type_tags = type_tags.map { |tag| tag.match(regexmap)[1] }
        end

        if category == "copyright" && tags_for_category("character").blank?
          type_tags.to_sentence
        else
          formatstr % type_tags.to_sentence
        end
      end

      strings = strings.compact.join(" ").tr("_", " ")
      output = strings.presence || default
      output
    end
  end

  private

  # Wraps one character group's header + tag sections in a collapsible container - see
  # .character-group-header's click handler in posts.js. The wrapper is what makes the
  # collapse scoped to just this group instead of every same-named category section on the
  # page (category_sections_html reuses shared classes like "general-tag-list" per group).
  # A character's plain display name, plus a small icon linking to their character page -
  # the icon is excluded from the header's click-to-collapse toggle (see posts.js).
  def character_group_name_html(name)
    icon = h.tag.i(class: "fa-solid fa-arrow-up-right-from-square")
    link = link_to(icon, r.show_or_new_characters_path(name: name), class: "character-group-link", title: "View character page")
    safe_join([name.tr("_", " "), " ", link])
  end

  def character_group_section_html(label, content_html, header_class: "character-group-header")
    h.tag.div(safe_join([
      h.tag.h2(label, class: header_class),
      h.tag.div(content_html, class: "character-group-content"),
    ]), class: "character-group")
  end

  # The header+list markup for post_show_sidebar_tag_list_html, scoped to an explicit set of
  # tags rather than always the full @tag_names - shared between the plain and
  # character-grouped renderings.
  def category_sections_html(tags, highlighted_tags:, followed_tags:, current_query:)
    html = []
    by_category = tags.group_by(&:category)

    TagCategory::SPLIT_HEADER_LIST.each do |category|
      typetags = by_category[TagCategory.mapping[category.downcase]] || []
      next unless typetags.any?

      html << h.tag.h2(TagCategory.get(category).header, class: "#{category}-tag-list-header tag-list-header", data: { category: category })
      list_items = typetags.map { |tag| build_list_item(tag, current_query: current_query, highlight: highlighted_tags.include?(tag.name), followed: followed_tags.include?(tag.name)) }
      html << h.tag.ul(safe_join(list_items), class: "#{category}-tag-list")
    end

    safe_join(html)
  end

  def tags
    @tags ||= Tag.where(name: tag_names).includes(antecedent_alias: :consequent_tag).select(:name, :post_count, :category, :is_deprecated)
  end

  def tags_by_category
    @tags_by_category ||= ordered_tags.group_by(&:category)
  end

  def tags_for_category(category_name)
    category = TagCategory.mapping[category_name.downcase]
    tags_by_category[category] || []
  end

  def ordered_tags
    @ordered_tags ||= begin
      names_to_tags = tags.index_by(&:name)

      ordered = tag_names.map do |name|
        names_to_tags[name] || Tag.new(name: name).freeze
      end
      ordered
    end
  end

  def build_list_item(tag, current_query: "", highlight: false, followed: false)
    html = safe_join([
      build_list_item_category(tag),
      build_list_item_tag_type(tag, current_query: current_query, highlight: highlight),
      build_list_item_actions(tag, followed: followed),
    ])
    h.tag.li(html, class: "category-#{tag.category}")
  end

  def build_list_item_tag_type(tag, current_query: "", highlight: false)
    name = tag.name
    count = tag.post_count
    category = tag.category
    parts = []

    if current_query.present?
      parts += [link_to("+", r.posts_path(tags: "#{current_query} #{name}"), class: "search-inc-tag"), " "]
      parts += [link_to("-", r.posts_path(tags: "#{current_query} -#{name}"), class: "search-exl-tag"), " "]
    end

    parts << tag_link(tag, name.tr("_", " "))
    parts << h.svg_icon(:chexagon, class: "highlight chexagon", title: "Uploaded by the artist") if highlight

    if count >= 10_000
      post_count = "#{count / 1_000}k"
    elsif count >= 1_000
      post_count = format("%.1fk", count / 1_000.0)
    else
      post_count = count
    end

    is_underused_tag = count <= 1 && category == TagCategory.general
    klass = "color-muted post-count#{' low-post-count' if is_underused_tag}"
    title = is_underused_tag ? { title: "New general tag detected. Check the spelling or populate it now." } : {}

    parts << h.tag.span(post_count, class: klass, data: { count: count }, **title)
    h.tag.span(safe_join(parts), class: "tag-type")
  end

  def build_list_item_category(tag)
    name = tag.name
    category = tag.category
    marker = tag.is_deprecated? ? h.deprecated_tag_icon : "?"

    if category == TagCategory.artist
      safe_join([link_to(marker, r.show_or_new_artists_path(name: name), class: "wiki-link", rel: "nofollow"), " "])
    else
      safe_join([link_to(marker, r.show_or_new_wiki_pages_path(title: name), class: "wiki-link", rel: "nofollow"), " "])
    end
  end

  def build_list_item_actions(tag, followed: false)
    parts = []
    if CurrentUser.user.is_member?
      parts << h.tag.span(link_to(h.tag.i(class: "fas fa-times"), "#", class: "blacklist-tag-toggle", title: "Blacklist Tag"), class: "tag-action-blacklist")
      parts << h.tag.span(link_to("", "#", class: "follow-button-minor", title: "Follow Tag", data: { followed: followed }), class: "tag-action-follow")
    end
    h.tag.div(safe_join(parts), class: "tag-actions", data: { tag: tag.name })
  end

  def tag_link(tag, link_text = tag.name, link_type = :tag)
    link = link_type == :wiki_page ? r.show_or_new_wiki_pages_path(title: tag.name) : r.posts_path(tags: tag.name)
    itemprop = tag.artist? ? { itemprop: "author" } : {}
    klass = tag.is_deprecated? ? "search-tag deprecated-tag" : "search-tag"

    safe_join([link_to(link_text, link, rel: "nofollow", class: klass, **itemprop), " "])
  end
end

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
  def initialize(tag_names, helper: nil, view: nil)
    super(helper, view)
    @tag_names = tag_names
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
    html = []

    TagCategory::SPLIT_HEADER_LIST.each do |category|
      typetags = tags_for_category(category)

      next unless typetags.any?
      html << h.tag.h2(TagCategory.get(category).header, class: "#{category}-tag-list-header tag-list-header", data: { category: category })
      tags = []
      typetags.each do |tag|
        tags << build_list_item(tag, current_query: current_query, highlight: highlighted_tags.include?(tag.name), followed: followed_tags.include?(tag.name))
      end
      html << h.tag.ul(safe_join(tags), class: "#{category}-tag-list")
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

  def tags
    @tags ||= Tag.where(name: tag_names).includes(antecedent_alias: :consequent_tag).select(:name, :post_count, :category)
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

    if category == TagCategory.artist
      safe_join([link_to("?", r.show_or_new_artists_path(name: name), class: "wiki-link", rel: "nofollow"), " "])
    else
      safe_join([link_to("?", r.show_or_new_wiki_pages_path(title: name), class: "wiki-link", rel: "nofollow"), " "])
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
    safe_join([link_to(link_text, link, rel: "nofollow", class: "search-tag", **itemprop), " "])
  end
end

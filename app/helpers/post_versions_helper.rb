# frozen_string_literal: true

module PostVersionsHelper
  def post_source_diff(post_version)
    diff = post_version.diff_sources(post_version.previous)
    changes = []

    diff[:added_sources].each do |source|
      classes = diff[:obsolete_added_sources].include?(source) ? "obsolete" : ""
      changes << tag.div(tag.ins(wordbreak_source("+#{source}"), class: classes))
    end
    diff[:removed_sources].each do |source|
      classes = diff[:obsolete_removed_sources].include?(source) ? "obsolete" : ""
      changes << tag.div(tag.del(wordbreak_source("-#{source}"), class: classes))
    end
    diff[:unchanged_sources].each do |source|
      changes << tag.div(wordbreak_source(source))
    end

    tag.span(safe_join(changes, " "), class: "diff-list")
  end

  def wordbreak_source(string)
    lines = string.scan(/.{1,10}/)
    safe_join(lines, tag.wbr)
  end

  def post_version_diff(post_version)
    rows = post_version.tag_rows(post_version.previous)

    safe_join(rows.map { |row| post_version_tag_row(row) })
  end

  def post_version_tag_row(row)
    label_classes = ["pv-tag-row-label"]
    label_classes << row[:row_status].to_s if row[:row_status]
    label_text =
      case row[:row_status]
      when :added then "+#{row[:label]}"
      when :removed then "-#{row[:label]}"
      else row[:label]
      end

    tag.div(class: "pv-tag-row") do
      safe_join([
        tag.div(label_text, class: label_classes.join(" ")),
        tag.div(post_version_tag_row_tags(row), class: "pv-tag-row-tags diff-list"),
      ])
    end
  end

  def post_version_tag_row_tags(row)
    changes = []
    row[:added].each do |t|
      changes << tag.ins(link_to_wiki_or_new("+#{t[:name]}", t[:name]), class: t[:obsolete] ? "obsolete" : "")
    end
    row[:removed].each do |t|
      changes << tag.del(link_to_wiki_or_new("-#{t[:name]}", t[:name]), class: t[:obsolete] ? "obsolete" : "")
    end
    row[:unchanged].each do |tag_name|
      changes << tag.span(link_to_wiki_or_new(tag_name))
    end

    safe_join(changes, " ")
  end

  def post_version_locked_diff(post_version)
    diff = post_version.diff(post_version.previous)
    changes = []

    diff[:added_locked_tags].each do |tag_name|
      changes << tag.ins(link_to_wiki_or_new("+#{tag_name}", tag_name))
    end
    diff[:removed_locked_tags].each do |tag_name|
      changes << tag.del(link_to_wiki_or_new("-#{tag_name}", tag_name))
    end
    diff[:unchanged_locked_tags].each do |tag_name|
      changes << tag.span(link_to_wiki_or_new(tag_name))
    end

    tag.span(safe_join(changes, " "), class: "diff-list")
  end
end

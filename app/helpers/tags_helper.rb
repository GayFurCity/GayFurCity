# frozen_string_literal: true

module TagsHelper
  def format_transitive_item(transitive)
    html = [tag.b(transitive[0].to_s.titlecase, class: "text-error"), " "]
    if transitive[0] == :alias
      html << "#{transitive[2]} -> #{transitive[3]} will become #{transitive[2]} -> #{transitive[4]}"
    else
      html << "#{transitive[2]} +> #{transitive[3]} will become #{transitive[4]} +> #{transitive[5]}"
    end
    safe_join(html)
  end

  def tag_class(tag)
    return nil if tag.blank?
    "tag-type-#{tag.category}"
  end

  def deprecated_tag_icon
    svg_icon(:octagon_alert, class: "deprecated-tag-icon", title: "This tag is deprecated")
  end
end

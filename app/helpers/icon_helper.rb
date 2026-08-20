# frozen_string_literal: true

module IconHelper
  # https://lucide.dev/
  # Ported from e621ng's IconHelper - only the icons post_replacements/_card.html.erb uses.
  PATHS = {
    chevron_down:       %(<path d="m6 9 6 6 6-6"/>),
    octagon_x:          %(<path d="m15 9-6 6"/><path d="M2.586 16.726A2 2 0 0 1 2 15.312V8.688a2 2 0 0 1 .586-1.414l4.688-4.688A2 2 0 0 1 8.688 2h6.624a2 2 0 0 1 1.414.586l4.688 4.688A2 2 0 0 1 22 8.688v6.624a2 2 0 0 1-.586 1.414l-4.688 4.688a2 2 0 0 1-1.414.586H8.688a2 2 0 0 1-1.414-.586z"/><path d="m9 9 6 6"/>),
    octagon_alert:      %(<path d="M12 16h.01"/><path d="M12 8v4"/><path d="M15.312 2a2 2 0 0 1 1.414.586l4.688 4.688A2 2 0 0 1 22 8.688v6.624a2 2 0 0 1-.586 1.414l-4.688 4.688a2 2 0 0 1-1.414.586H8.688a2 2 0 0 1-1.414-.586l-4.688-4.688A2 2 0 0 1 2 15.312V8.688a2 2 0 0 1 .586-1.414l4.688-4.688A2 2 0 0 1 8.688 2z"/>),
    diamond_plus:       %(<path d="M12 8v8"/><path d="M2.7 10.3a2.41 2.41 0 0 0 0 3.41l7.59 7.59a2.41 2.41 0 0 0 3.41 0l7.59-7.59a2.41 2.41 0 0 0 0-3.41L13.7 2.71a2.41 2.41 0 0 0-3.41 0z"/><path d="M8 12h8"/>),
    circle_check_small: %(<path d="M21.801 10A10 10 0 1 1 17 3.335"/><path d="m9 11 3 3L22 4"/>),
    chexagon:           %(<path d="M7.6 21.4h8.8a2.2 2.1 0 0 0 1.9-1l4.3-7.4a2.2 2.1 0 0 0 0-2l-4.3-7.4a2.2 2.1 0 0 0-2-1H7.7a2.2 2.1 0 0 0-1.9 1L1.4 11a2.2 2.1 0 0 0 0 2l4.3 7.4a2.2 2.1 0 0 0 2 1z"/><path d="m17.3 9.2-6.6 6.6-3-3.1" class="check"/>),
  }.freeze

  def svg_icon(name, *args)
    options = args.extract_options!
    width = options[:width] || 24
    height = options[:height] || 24
    klass = options[:class]
    id = options[:id]
    title = options[:title]
    stroke_width = options[:stroke_width] || 2

    tag.svg(
      "xmlns":           "http://www.w3.org/2000/svg",
      "width":           width,
      "height":          height,
      "viewbox":         "0 0 24 24",
      "fill":            "none",
      "stroke":          "currentColor",
      "stroke-width":    stroke_width,
      "stroke-linecap":  "round",
      "stroke-linejoin": "round",
      "class":           klass,
      "id":              id,
      "name":            name.to_s,
    ) do
      concat(tag.title(title)) if title.present?
      concat(raw(PATHS[name])) # rubocop:disable Rails/OutputSafety
    end
  end
end

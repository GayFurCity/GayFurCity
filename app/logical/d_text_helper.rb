# frozen_string_literal: true

module DTextHelper
  module_function

  def parse(text, **)
    return nil if text.nil?
    *data, topics = preprocess([text])
    text = replace_topics(text, topics)
    hash = DText.parse(text, **)
    hash[:dtext] = postprocess(hash[:dtext], *data)
    hash
  end

  def bulk_parse(texts, **)
    return [] if texts.blank?
    *data, topics = preprocess(texts)
    texts.to_h do |text|
      text = replace_topics(text, topics)
      hash = DText.parse(text, **)
      hash[:dtext] = postprocess(hash[:dtext], *data)
      [text, hash]
    end
  end

  def format_text(text, **)
    parse(text, **).fetch(:dtext)
  end

  def preprocess(dtext_messages)
    names = dtext_messages.map { |message| parse_wiki_titles(message) }.flatten.uniq
    wiki_pages = WikiPage.where(title: names)
    tags = Tag.where(name: names)
    artists = Artist.where(name: names)
    topics = dtext_messages.map { |message| parse_forum_topics(message) }.flatten.uniq

    [wiki_pages, tags, artists, topics]
  end

  def replace_topics(text, topics)
    names = {}
    uncached = topics.reject { |topic_id| (names[topic_id.to_i] = Cache.fetch("topic_name:#{topic_id}")).present? }
    values = ForumTopic.where(id: uncached).pluck(:id, :title).to_h
    values.each { |topic_id, title| Cache.write("topic_name:#{topic_id}", title, expires_in: 1.hour) }
    names.merge!(values)
    text.gsub(/\[topic:(\d+)\]/) do
      topic_id = $1.to_i
      if names[topic_id].present?
        name = names[topic_id]
        "[topic=#{topic_id}]#{name}[/topic]"
      else
        "topic ##{topic_id}"
      end
    end
  end

  def postprocess(html, wiki_pages, tags, artists)
    fragment = parse_html(html)

    fragment.css("a.dtext-wiki-link").each do |node|
      parsed = Addressable::URI.parse(node["href"])
      path = parsed.path
      if path.include?("show_or_new")
        name = parsed.query_values["title"]
      else
        name = path[%r{\A/wiki/((?:(?!show_or_new).)*)\z}i, 1]
      end
      name = CGI.unescape(name)
      name = WikiPage.normalize_title(name)
      wiki = wiki_pages.find { |w| w.title == name }
      tag = tags.find { |t| t.name == name }
      artist = artists.find { |a| a.name == name }

      if tag.present?
        node["class"] += " tag-type-#{tag.category}"
      end

      if tag.present? && tag.artist?
        node["href"] = "/artists/show_or_new?name=#{CGI.escape(name)}"

        if artist.blank?
          node["class"] += " dtext-artist-does-not-exist"
          node["title"] = "This artist page does not exist"
        end
      else
        if wiki.blank?
          node["class"] += " dtext-wiki-does-not-exist"
          node["title"] = "This wiki page does not exist"
        end

        if WikiPage.is_meta_wiki?(name)
          # skip (meta wikis aren't expected to have a tag)
        elsif tag.blank?
          node["class"] += " dtext-tag-does-not-exist"
          node["title"] = "This wiki page does not have a tag"
        elsif tag.empty?
          node["class"] += " dtext-tag-empty"
          node["title"] = "This wiki page does not have a tag"
        end
      end
    end
    fragment.to_s
  end

  def parse_forum_topics(text)
    return [] if text.blank?
    text.scan(/\[topic:(\d+)\]/).flatten
  end

  def parse_wiki_titles(text)
    return [] if text.blank?
    DText.parse(text) => { dtext: html }
    fragment = parse_html(html)

    titles = fragment.css("a.dtext-wiki-link").map do |node|
      if node["href"].include?("show_or_new")
        title = node["href"][%r{\A/wiki/show_or_new\?title=(.*)\z}i, 1]
      else
        title = node["href"][%r{\A/wiki/(.*)\z}i, 1]
      end
      title = CGI.unescape(title)
      title = WikiPage.normalize_title(title)
      title
    end

    titles.uniq
  end

  def parse_external_links(text)
    return [] if text.blank?
    DText.parse(text) => { dtext: html }
    fragment = parse_html(html)

    links = fragment.css("a.dtext-external-link").pluck("href")
    links.uniq
  end

  def dtext_links_differ?(old, new)
    parse_wiki_titles(old).sort != parse_wiki_titles(new).sort ||
      parse_external_links(old).sort != parse_external_links(new).sort
  end

  def parse_html(html)
    Nokogiri::HTML5.fragment(html, max_tree_depth: -1)
  end

  # Rewrite wiki links to [[old_name]] with [[new_name]]. We attempt to match
  # the capitalization of the old tag when rewriting it to the new tag, but if
  # we can't determine how the new tag should be capitalized based on some
  # simple heuristics, then we skip rewriting the tag.
  # @param dtext [String] the DText input
  # @param old_name [String] the old wiki name
  # @param new_name [String] the new wiki name
  # @return [String] the DText output
  def rewrite_wiki_links(dtext, old_name, new_name)
    old_name = old_name.downcase.squeeze("_").tr("_", " ").strip
    new_name = new_name.downcase.squeeze("_").tr("_", " ").strip

    # Match `[[name]]` or `[[name|title]]`
    dtext.gsub(/\[\[(.*?)(?:\|(.*?))?\]\]/) do |match|
      name = $1
      title = $2

      # Skip this link if it isn't the tag we're trying to replace.
      normalized_name = name.downcase.tr("_", " ").squeeze(" ").strip
      next match if normalized_name != old_name

      # Strip qualifiers, e.g. `atago (midsummer march) (azur lane)` => `atago`
      unqualified_name = name.tr("_", " ").squeeze(" ").strip.gsub(/( \(.*\))+\z/, "")

      # If old tag was lowercase, e.g. [[ink tank (Splatoon)]], then keep new tag in lowercase.
      if unqualified_name == unqualified_name.downcase
        final_name = new_name
        # If old tag was capitalized, e.g. [[Colored pencil (medium)]], then capitialize new tag.
      elsif unqualified_name == unqualified_name.downcase.capitalize
        final_name = new_name.capitalize
        # If old tag was in titlecase, e.g. [[Hatsune Miku (cosplay)]], then titlecase new tag.
      elsif unqualified_name == unqualified_name.split.map(&:capitalize).join(" ")
        final_name = new_name.split.map(&:capitalize).join(" ")
        # If we can't determine how to capitalize the new tag, then keep the old tag.
        # e.g. [[Suzumiya Haruhi no Yuuutsu]] -> [[The Melancholy of Haruhi Suzumiya]]
      else
        next match
      end

      if title.present?
        "[[#{final_name}|#{title}]]"
        # If the new name has a qualifier, then hide the qualifier in the link.
      elsif final_name.match?(/( \(.*\))+\z/)
        "[[#{final_name}|]]"
      else
        "[[#{final_name}]]"
      end
    end
  end
end

# frozen_string_literal: true

class HelpPage < ApplicationRecord
  normalizes(:name, with: ->(name) { name.downcase.strip.tr(" ", "_") })
  after_destroy(:invalidate_cache)
  after_save(:invalidate_cache)
  belongs_to(:wiki_page)
  delegate(:title, to: :wiki_page, prefix: true, allow_nil: true)
  belongs_to_user(:creator, ip: true, clones: :updater)
  belongs_to_user(:updater, ip: true)
  resolvable(:destroyer)

  def wiki_page_title=(name)
    self.wiki_page = WikiPage.titled(name)
  end

  def invalidate_cache
    Cache.delete("help_index")
    true
  end

  def pretty_title
    title.presence || name.titleize
  end

  def related_array
    related.split(",").map(&:strip)
  end

  def self.pretty_related_title(related, help_pages)
    related_help_page = help_pages.find { |help_page| help_page.name == related }

    return related_help_page.pretty_title if related_help_page

    related.titleize
  end

  def self.help_index
    Cache.fetch("help_index", expires_in: 12.hours) { HelpPage.all.sort_by(&:pretty_title) }
  end

  modactions(:help)
    .add(:create, :creator, on: :create) { { name: name, wiki_page_title: wiki_page_title, wiki_page_id: wiki_page_id } }
    .add(:update, :updater, on: :update) { { name: name, wiki_page_title: wiki_page_title, wiki_page_id: wiki_page_id } }
    .add(:delete, :destroyer, on: :destroy) { { name: name, wiki_page_title: wiki_page_title, wiki_page_id: wiki_page_id } }

  def self.available_includes
    %i[wiki_page]
  end
end

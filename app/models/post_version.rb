# frozen_string_literal: true

class PostVersion < ApplicationRecord
  class UndoError < StandardError; end
  class MergeError < StandardError; end
  belongs_to(:post)
  belongs_to_user(:updater, ip: true, counter_cache: "post_update_count")

  before_validation(:fill_version, on: :create)
  before_validation(:fill_changes, on: :create)

  module SearchMethods
    def search(params, user)
      ElasticPostVersionQueryBuilder.new(params, user).search
    end
  end

  extend(SearchMethods)
  include(DocumentStore::Model)
  include(PostVersionIndex)

  def self.queue(post, updater)
    create({
      post_id:          post.id,
      rating:           post.rating,
      parent_id:        post.parent_id,
      source:           post.source,
      updater:          updater,
      tags:             post.tag_string,
      character_groups: post.character_groups,
      original_tags:    post.tag_string_before_parse || "",
      locked_tags:      post.locked_tags,
      description:      post.description,
      reason:           post.edit_reason,
    })
  end

  def self.merge(version, post, updater)
    raise(MergeError, "Attempted to merge post ##{post.id} into its first version (#{version.id})") if version.first?
    raise(MergeError, "Attempted to merge post ##{post.id} into non-basic post version ##{version.id}") unless version.basic?
    raise(MergeError, "Attempted to merge post ##{post.id} into post version ##{version.id} created by different updater (#{version.updater_id}/#{updater.id})") unless version.updater_id == updater.id
    version.source = post.source
    version.tags = post.tag_string
    version.character_groups = post.character_groups
    version.locked_tags = post.locked_tags
    # Don't even bother merging, just toss it out entirely. We should only be merging system edits, which
    # won't have an original tag string either way
    version.original_tags = ""
    version.fill_changes
    if version.empty?
      version.destroy
    else
      version.save
    end
  end

  def self.calculate_version(post_id)
    where(post_id: post_id).maximum(:version).to_i + 1
  end

  def fill_version
    self.version = PostVersion.calculate_version(post_id)
  end

  def fill_changes(prev = nil)
    prev ||= previous

    if prev
      self.added_tags = tag_array - prev.tag_array
      self.removed_tags = prev.tag_array - tag_array
      self.added_locked_tags = locked_tag_array - prev.locked_tag_array
      self.removed_locked_tags = prev.locked_tag_array - locked_tag_array
    else
      self.added_tags = tag_array
      self.removed_tags = []
      self.added_locked_tags = locked_tag_array
      self.removed_locked_tags = []
    end

    self.rating_changed = prev.nil? || rating != prev.try(:rating)
    self.parent_changed = prev.nil? || parent_id != prev.try(:parent_id)
    self.source_changed = prev.nil? || source != prev.try(:source)
    self.description_changed = prev.nil? || description != prev.try(:description)
  end

  def first?
    version == 1
  end

  def basic?
    !rating_changed && !parent_changed && !description_changed
  end

  def empty?
    added_tags.empty? && removed_tags.empty? && added_locked_tags.empty? && removed_locked_tags.empty? && !source_changed && !description_changed && !parent_changed && !rating_changed
  end

  def tag_array
    @tag_array ||= tags.split
  end

  def locked_tag_array
    (locked_tags || "").split
  end

  def presenter
    PostVersionPresenter.new(self)
  end

  def previous
    # The first version cannot have a previous record, so skip the lookup.
    return nil if version <= 1

    return @previous if defined?(@previous)

    # Use the loaded association when possible to avoid a query while rendering version lists.
    if association(:post).loaded? && post&.association(:versions)&.loaded?
      @previous = post.versions.sort_by(&:version).rfind { |v| v.version < version }
    else
      @previous = PostVersion.where(post_id: post_id).where.lt(version: version).order(version: :desc).first
    end
  end

  def visible?(user)
    post.try(:visible?, user) || false
  end

  def diff_sources(version = nil)
    latest_sources = post.source&.split("\n") || []
    new_sources = source&.split("\n") || []
    old_sources = version&.source&.split("\n") || []

    added_sources = new_sources - old_sources
    removed_sources = old_sources - new_sources

    {
      added_sources:            added_sources,
      unchanged_sources:        new_sources & old_sources,
      removed_sources:          removed_sources,
      obsolete_added_sources:   added_sources - latest_sources,
      obsolete_removed_sources: removed_sources & latest_sources,
    }
  end

  def diff(version = nil)
    latest_tags = post.tag_array + parent_rating_tags(post)

    new_tags = tag_array + parent_rating_tags(self)

    old_tags = version.present? ? version.tag_array + parent_rating_tags(version) : []

    added_tags = new_tags - old_tags
    removed_tags = old_tags - new_tags

    new_locked = locked_tag_array
    old_locked = version.present? ? version.locked_tag_array : []

    added_locked = new_locked - old_locked
    removed_locked = old_locked - new_locked

    {
      added_tags:            added_tags,
      removed_tags:          removed_tags,
      obsolete_added_tags:   added_tags - latest_tags,
      obsolete_removed_tags: removed_tags & latest_tags,
      unchanged_tags:        new_tags & old_tags,
      added_locked_tags:     added_locked,
      removed_locked_tags:   removed_locked,
      unchanged_locked_tags: new_locked & old_locked,
    }
  end

  # tag_name => character_label, for every tag (including the character tag itself) in a
  # named group - i.e. a group with at least one character-category tag in it.
  def group_label_map
    return {} if character_groups.blank?
    categories = Tag.categories_for(character_groups.flat_map { |g| Array(g["tags"]) })
    character_groups.each_with_object({}) do |g, map|
      tags = Array(g["tags"])
      characters = tags.select { |t| categories[t] == TagCategory::CHARACTER.id }.sort
      next if characters.empty?
      label = characters.join(" ")
      tags.each { |t| map[t] = label }
    end
  end

  # One tag array per group with no character-category tag in it - these have no stable
  # identity across versions, so they can only be labeled by position ("Unnamed #1").
  def anonymous_group_tag_sets
    return [] if character_groups.blank?
    categories = Tag.categories_for(character_groups.flat_map { |g| Array(g["tags"]) })
    character_groups.filter_map do |g|
      tags = Array(g["tags"])
      tags.any? { |t| categories[t] == TagCategory::CHARACTER.id } ? nil : tags
    end
  end

  # Tags bucketed into rows for the version-list display: one row per named character
  # (sorted alphabetically), one per current anonymous group ("Unnamed #N", by position),
  # a trailing row for tags that belonged to an anonymous group but are now gone entirely
  # (their specific group can't be identified once it's gone), and one row (nil label,
  # rendered as an empty first column) for tags with no character attribution at all.
  #
  # Each row is { label:, row_status: :added/:removed/nil, added:, removed:, unchanged: }.
  # row_status is set when *every* tag in the row is added (the row/character is new) or
  # removed (the row/character is gone) - never set for the nil-label (general) row.
  def tag_rows(version = nil)
    latest_tags = post.tag_array + parent_rating_tags(post)
    new_tags = tag_array + parent_rating_tags(self)
    old_tags = version.present? ? version.tag_array + parent_rating_tags(version) : []

    new_named = group_label_map
    old_named = version.present? ? version.group_label_map : {}
    new_anon = anonymous_group_tag_sets
    new_anon_flat = new_anon.flatten
    old_anon_flat = version.present? ? version.anonymous_group_tag_sets.flatten : []

    buckets = Hash.new { |h, k| h[k] = { added: [], removed: [], unchanged: [] } }

    new_tags.each do |t|
      next if new_anon_flat.include?(t)
      buckets[new_named[t]][old_tags.include?(t) ? :unchanged : :added] << t
    end

    old_tags.each do |t|
      next if new_tags.include?(t) || old_anon_flat.include?(t)
      buckets[old_named[t]][:removed] << t
    end

    rows = []
    rows << finalize_tag_row(nil, buckets.delete(nil), latest_tags) if buckets.key?(nil)
    buckets.keys.sort.each { |label| rows << finalize_tag_row(label, buckets[label], latest_tags) }

    new_anon.each_with_index do |tags, i|
      bucket = { added: [], removed: [], unchanged: [] }
      tags.each { |t| bucket[old_tags.include?(t) ? :unchanged : :added] << t }
      rows << finalize_tag_row("Unnamed ##{i + 1}", bucket, latest_tags)
    end

    removed_anon = old_anon_flat - new_tags - new_anon_flat
    rows << finalize_tag_row("Unnamed (removed)", { added: [], removed: removed_anon, unchanged: [] }, latest_tags) if removed_anon.any?

    rows
  end

  def finalize_tag_row(label, bucket, latest_tags)
    status =
      if label.present? && bucket[:unchanged].empty? && bucket[:removed].empty? && bucket[:added].any?
        :added
      elsif label.present? && bucket[:unchanged].empty? && bucket[:added].empty? && bucket[:removed].any?
        :removed
      end

    {
      label:      label,
      row_status: status,
      added:      bucket[:added].map { |t| { name: t, obsolete: latest_tags.exclude?(t) } },
      removed:    bucket[:removed].map { |t| { name: t, obsolete: latest_tags.include?(t) } },
      unchanged:  bucket[:unchanged],
    }
  end

  def parent_rating_tags(post)
    result = ["rating:#{post.rating}"]
    result << "parent:#{post.parent_id}" unless post.parent_id.nil?
    result
  end

  def changes
    return @changes if defined?(@changes)

    new_sources = source&.split("\n") || []
    old_sources = previous&.source&.split("\n") || []

    delta = {
      added_tags:               added_tags,
      removed_tags:             removed_tags,
      obsolete_removed_tags:    [],
      obsolete_added_tags:      [],
      unchanged_tags:           [],
      added_sources:            new_sources - old_sources,
      removed_sources:          old_sources - new_sources,
      obsolete_added_sources:   [],
      obsolete_removed_sources: [],
      unchanged_sources:        new_sources & old_sources,
    }

    latest_sources = post.source&.split("\n") || []
    latest_tags = post.tag_array
    latest_tags << "rating:#{post.rating}" if post.rating.present?
    latest_tags << "parent:#{post.parent_id}" if post.parent_id.present?
    latest_tags << "source:#{post.source}" if post.source.present?
    delta[:obsolete_added_sources] = delta[:added_sources] - latest_sources
    delta[:obsolete_removed_sources] = delta[:removed_sources] & latest_sources

    if parent_changed
      if parent_id.present?
        delta[:added_tags] << "parent:#{parent_id}"
      end

      if previous
        delta[:removed_tags] << "parent:#{previous.parent_id}"
      end
    end

    if rating_changed
      delta[:added_tags] << "rating:#{rating}"

      if previous
        delta[:removed_tags] << "rating:#{previous.rating}"
      end
    end

    delta[:obsolete_added_tags] = delta[:added_tags] - latest_tags
    delta[:obsolete_removed_tags] = delta[:removed_tags] & latest_tags

    if previous
      delta[:unchanged_tags] = tag_array & previous.tag_array
    else
      delta[:unchanged_tags] = []
    end

    @changes = delta
  end

  def undo(user)
    raise(UndoError, "Version 1 is not undoable") unless undoable?

    post.updater = user

    if description_changed
      post.description = previous.description
    end

    if rating_changed && !post.is_rating_locked?
      post.rating = previous.rating
    end

    if parent_changed
      post.parent_id = previous.parent_id
    end

    if source_changed
      post.source = previous.source
    end

    added = changes[:added_tags] - changes[:obsolete_added_tags]
    removed = changes[:removed_tags] - changes[:obsolete_removed_tags]

    added.each do |tag|
      next if tag =~ /^parent:/ || tag =~ /^source:(.+)$/
      escaped_tag = Regexp.escape(tag)
      post.tag_string = post.tag_string.sub(/(?:\A| )#{escaped_tag}(?:\Z| )/, " ").strip
    end
    removed.each do |tag|
      next if tag =~ /^parent:/ || tag =~ /^source:(.+)$/
      post.tag_string = "#{post.tag_string} #{tag}".strip
    end

    post.edit_reason = "Undo of version #{version}"
  end

  def undo!(user)
    undo(user)
    post.save!
  end

  def undoable?
    version > 1
  end

  def original_tags_array
    @original_tags_array ||= original_tags.split
  end

  def serializable_hash(*)
    hash = super
    # noinspection RubyModifiedFrozenObject
    changes.each { |key, value| key.to_s.include?("tags") && value.is_a?(Array) ? hash[key] = value.join(" ") : hash[key] = value }
    hash
  end

  def self.available_includes
    %i[post updater]
  end
end

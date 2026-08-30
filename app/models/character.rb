# frozen_string_literal: true

class Character < ApplicationRecord
  attr_accessor(:url_string_changed)

  belongs_to_user(:creator, ip: true, clone: :updater)
  belongs_to_user(:owner_user, optional: true)
  belongs_to_user(:updater, ip: true)
  resolvable(:destroyer)
  revertible do |version|
    self.name = version.name
    self.url_string = version.urls.join("\n")
  end

  before_validation(:normalize_name, unless: :destroyed?)
  before_validation(:blank_out_nonexistent_cover_post, unless: :destroyed?)
  validate(:validate_user_can_edit)
  validate(:wiki_page_not_locked)
  validate(:user_not_limited)
  validate(:validate_cover_post_has_tag)
  validate(:validate_custom_attributes)
  validates(:name, tag_name: true, uniqueness: true, if: :name_changed?)
  validates(:name, length: { maximum: 100 })
  validates(:cover_caption, length: { maximum: 255 })
  after_save(:create_version)
  after_save(:categorize_tag)
  after_save(:update_wiki)
  after_save(:propagate_locked, if: :should_propagate_locked)
  after_save(:clear_url_string_changed)

  has_many(:urls, class_name: "CharacterUrl", autosave: true, dependent: :destroy)
  has_many(:versions, -> { order("character_versions.id ASC") }, class_name: "CharacterVersion", dependent: :destroy)
  belongs_to(:cover_post, class_name: "Post", optional: true)
  has_one(:wiki_page, foreign_key: "title", primary_key: "name")
  has_one(:tag_alias, foreign_key: "antecedent_name", primary_key: "name")
  has_one(:tag, foreign_key: "name", primary_key: "name")
  attribute(:notes, :string)
  delegate(:post_count, to: :tag)

  modactions(:character)
    .add(:rename, :updater, on: :save, if: -> { saved_change_to_name? && !previously_new_record? }) { { new_name: name, old_name: name_before_last_save } }
    .add(:lock, :updater, on: :save, if: -> { saved_change_to_is_locked? && is_locked? })
    .add(:unlock, :updater, on: :save, if: -> { saved_change_to_is_locked? && !is_locked? })
    .add(:owner_link, :updater, on: :save, if: -> { saved_change_to_owner_user_id? && owner_user_id.present? }) { { user_id: owner_user_id } }
    .add(:owner_unlink, :updater, on: :save, if: -> { saved_change_to_owner_user_id? && owner_user_id.blank? }) { { user_id: owner_user_id_before_last_save } }
    .add(:delete, :destroyer, on: :before_destroy) { { name: name } }

  # FIXME: This is a hack on top of the hack below for setting url_string to ensure name is set first for validations
  def assign_attributes(new_attributes)
    assign_first = new_attributes.extract!(:name)
    super(assign_first) unless assign_first.empty?
    super
  end

  module UrlMethods
    extend(ActiveSupport::Concern)

    MAX_URLS_PER_CHARACTER = 25

    def sorted_urls
      urls.sort { |a, b| b.priority <=> a.priority }
    end

    def url_array
      urls.map(&:to_s).sort
    end

    def url_string
      url_array.join("\n")
    end

    def url_string=(string)
      # FIXME: This is a hack. Setting an association directly immediately updates without regard for the parents validity.
      # As a consequence, removing urls always works. This does not create a new CharacterVersion.
      # This fix isn't great but it's the best I came up with without rather large changes.
      return unless valid?

      url_string_was = url_string

      self.urls = string.to_s.scan(/[^[:space:]]+/).map do |url|
        is_active, url = CharacterUrl.parse_prefix(url)
        urls.find_or_initialize_by(url: url, is_active: is_active)
      end.uniq(&:url).first(MAX_URLS_PER_CHARACTER)

      self.url_string_changed = (url_string_was != url_string)
    end

    def clear_url_string_changed
      self.url_string_changed = false
    end
  end

  module NameMethods
    extend(ActiveSupport::Concern)

    module ClassMethods
      def normalize_name(name)
        name.to_s.downcase.strip.gsub(/ /, "_").to_s
      end
    end

    def normalize_name
      self.name = Character.normalize_name(name)
    end

    def pretty_name
      name.tr("_", " ")
    end
  end

  module VersionMethods
    def create_version(force: false)
      if saved_change_to_name? || url_string_changed || saved_change_to_notes? || saved_change_to_cover_post_id? || saved_change_to_cover_caption? || saved_change_to_custom_attributes? || force
        create_new_version
      end
    end

    def create_new_version
      CharacterVersion.create(
        character_id:              id,
        name:                      name,
        updater:                   updater,
        urls:                      url_array,
        notes_changed:             saved_change_to_notes?,
        cover_post_changed:        saved_change_to_cover_post_id?,
        cover_caption_changed:     saved_change_to_cover_caption?,
        custom_attributes:         custom_attributes,
        custom_attributes_changed: saved_change_to_custom_attributes?,
        owner_user_id:             owner_user_id,
      )
    end
  end

  module NoteMethods
    extend(ActiveSupport::Concern)

    def notes
      @notes || wiki_page.try(:body)
    end

    def notes=(text)
      return if wiki_page.blank? && text.empty?
      return if notes == text

      notes_will_change!
      @notes = text
    end

    def reload(options = nil)
      if instance_variable_defined?(:@notes)
        remove_instance_variable(:@notes)
      end

      super
    end

    def notes_changed?
      attribute_changed?("notes")
    end

    def notes_will_change!
      attribute_will_change!("notes")
    end

    def update_wiki
      if persisted? && saved_change_to_name? && attribute_before_last_save("name").present? && WikiPage.titled(attribute_before_last_save("name"))
        # we're renaming the character, so rename the corresponding wiki page
        old_page = WikiPage.titled(name_before_last_save)
        if wiki_page.nil?
          # a wiki page doesn't already exist for the new name, so rename the old one
          old_page.update_with(updater, title: name, body: @notes || old_page.body)
        end
      elsif wiki_page.nil?
        # if there are any notes, we need to create a new wiki page
        if @notes.present?
          create_wiki_page(body: @notes, title: name, creator: updater)
        end
      elsif (!@notes.nil? && (wiki_page.body != @notes)) || wiki_page.title != name
        # if anything changed, we need to update the wiki page
        wiki_page.body = @notes unless @notes.nil?
        wiki_page.title = name
        wiki_page.updater = updater
        wiki_page.save
      end
    end
  end

  module CoverMethods
    extend(ActiveSupport::Concern)

    def blank_out_nonexistent_cover_post
      if cover_post_id.present? && cover_post.nil?
        self.cover_post_id = nil
      end
    end

    def validate_cover_post_has_tag
      return if cover_post.nil?
      unless cover_post.tag_array.include?(name)
        errors.add(:cover_post, "must be tagged with this character")
      end
    end
  end

  module AttributeMethods
    extend(ActiveSupport::Concern)

    MAX_CUSTOM_ATTRIBUTES = 25
    RESERVED_ATTRIBUTE_NAMES = %w[owner user].freeze

    # Virtual assignment: a real form submits character[custom_attributes][][name]=...
    # etc, which Rack parses as a Hash keyed by index ({"0" => {...}, "1" => {...}}),
    # not a literal Array - only .values() unwraps that correctly.
    def custom_attributes=(params)
      return if params.nil?
      entries = params.respond_to?(:values) ? params.values : Array(params)
      parsed = entries.filter_map do |e|
        name = (e[:name] || e["name"]).to_s.strip
        value = (e[:value] || e["value"]).to_s.strip
        { "name" => name, "value" => value } if name.present?
      end
      write_attribute(:custom_attributes, parsed.first(MAX_CUSTOM_ATTRIBUTES))
    end

    def validate_custom_attributes
      seen = Set.new
      custom_attributes.each do |attr|
        name = attr["name"].to_s
        downcased = name.downcase
        if RESERVED_ATTRIBUTE_NAMES.include?(downcased)
          errors.add(:custom_attributes, "cannot use the reserved name \"#{name}\"")
        elsif seen.include?(downcased)
          errors.add(:custom_attributes, "must have unique names (\"#{name}\" is used more than once)")
        end
        seen << downcased
      end
    end
  end

  module TagMethods
    def category_id
      Tag.category_for(name)
    end

    def categorize_tag
      if new_record? || saved_change_to_name?
        Tag.find_or_create_by_name("character:#{name}", reason: "character creation", user: updater, artist: true)
      end
    end
  end

  module LockMethods
    def propagate_locked
      if wiki_page.present? && (wiki_page.protection_level.blank? || wiki_page.protection_level < User::Levels.min_staff_level)
        wiki_page.update_column(:protection_level, User::Levels.min_staff_level)
      end
    end

    def should_propagate_locked
      saved_change_to_is_locked?
    end

    def validate_user_can_edit
      return if updater.is_janitor?

      if is_locked?
        errors.add(:base, "Character is locked")
        throw(:abort)
      end
    end

    def wiki_page_not_locked
      if @notes.present? && is_note_locked?(updater) && wiki_page&.body != @notes
        errors.add(:base, "Wiki page is locked")
        throw(:abort)
      end
    end
  end

  module SearchMethods
    def named(name)
      find_by(name: normalize_name(name))
    end

    def any_name_matches(value)
      return all if value.nil?
      normalized_name = normalize_name(value)
      normalized_name = "*#{normalized_name}*" unless normalized_name.include?("*")
      where.like(name: normalized_name)
    end

    def url_matches(query)
      return all if query.nil?
      joins(:urls).text_attribute_matches(:"character_urls.url", query, convert_to_wildcard: true)
    end

    def any_name_or_url_matches(query)
      return all if query.nil?
      if query =~ %r{\Ahttps?://}i
        url_matches(query)
      else
        any_name_matches(query)
      end
    end

    def apply_order(params)
      order_with({
        name:            { "characters.name": :asc },
        post_count:      -> { left_outer_joins(:tag).order(Tag.arel(:post_count).desc.nulls_last, name: :asc) },
        post_count_asc:  -> { left_outer_joins(:tag).order(Tag.arel(:post_count).asc.nulls_last, name: :asc) },
        post_count_desc: -> { left_outer_joins(:tag).order(Tag.arel(:post_count).desc.nulls_last, name: :asc) },
      }, params[:order])
    end

    def query_dsl
      super
        .field(:name)
        .field(:ip_addr, :creator_ip_addr)
        .custom(:any_name_matches, ->(q, v) { q.any_name_matches(v) })
        .custom(:any_name_or_url_matches, ->(q, v) { q.any_name_or_url_matches(v) })
        .custom(:url_matches, ->(q, v) { q.url_matches(v) })
        .present(:is_owned, :owner_user_id)
        .custom(:has_tag, ->(q, v) { q.if(v, -> { q.joins(:tag).where.gt("tags.post_count": 0) }).else(-> { q.left_outer_joins(:tag).where("tags.name": nil).or(q.where.lteq("tags.post_count": 0)) }) })
        .association(:creator)
        .association(:owner_user)
    end
  end

  include(UrlMethods)
  include(NameMethods)
  include(VersionMethods)
  include(NoteMethods)
  include(CoverMethods)
  include(AttributeMethods)
  include(TagMethods)
  include(LockMethods)
  extend(SearchMethods)

  def deletable_by?(user)
    user.is_admin?
  end

  def editable_by?(user)
    user.is_janitor? || !is_locked?
  end

  def user_not_limited
    allowed = updater.can_character_edit_with_reason
    if allowed != true
      errors.add(:base, "User #{User.throttle_reason(allowed)}.")
      false
    end
    true
  end

  def is_note_locked?(user)
    wiki_page.try(:is_restricted?, user) || false
  end

  def self.available_includes
    %i[creator urls wiki_page tag_alias tag owner_user cover_post]
  end
end

# frozen_string_literal: true

class WikiPage < ApplicationRecord
  class MergeError < StandardError; end

  INTERNAL_PREFIXES = %w[internal: help:].freeze
  META_PREFIXES = %w[internal: help: howto: tag_group:].freeze

  belongs_to_user(:creator, ip: true, clones: :updater)
  belongs_to_user(:updater, ip: true)
  resolvable(:destroyer)
  has_dtext_links(:body)
  revertible do |version|
    self.title = version.title
    self.body = version.body
    self.parent = version.parent
  end

  has_one(:help_page)
  has_one(:tag, foreign_key: "name", primary_key: "title")
  has_one(:artist, foreign_key: "name", primary_key: "title")
  has_many(:versions, -> { order("wiki_page_versions.id": :asc) }, class_name: "WikiPageVersion", dependent: :destroy)

  after_initialize(:set_parent_props)
  before_validation(:normalize_title, unless: :destroyed?)
  before_validation(:normalize_parent, unless: :destroyed?)
  before_validation(:normalize_protection_level, unless: :destroyed?)
  before_validation(:ensure_internal_protected, unless: :destroyed?)
  before_destroy(:validate_not_used_as_help_page)
  after_save(:create_version)
  normalizes(:body, with: ->(body) { body.gsub("\r\n", "\n") })
  validates(:title, uniqueness: { case_sensitive: false })
  validates(:title, presence: true)
  validates(:title, tag_name: true, if: :title_changed?)
  validates(:body, presence: { unless: -> { parent.present? } })
  validates(:title, length: { minimum: 1, maximum: 100 })
  validates(:body, length: { maximum: -> { Config.instance.wiki_page_max_size } })
  validates(:protection_level, inclusion: { in: User::Levels.hash.values }, if: -> { protection_level.present? })
  validate(:validate_name_not_restricted, on: :create)
  validate(:user_not_limited)
  validate(:validate_rename)
  validate(:validate_redirect)
  validate(:validate_not_restricted)

  after_save(:update_help_page, if: :saved_change_to_title?)

  attr_accessor(:edit_reason, :parent_name, :parent_anchor, :target_wiki_page_id, :target_wiki_page_title)

  modactions(:wiki_page)
    .add(:rename, :updater, on: :update, if: -> { saved_change_to_title? }) { { old_title: title_before_last_save, wiki_page_title: title } }
    .add(:protect, :updater, on: :save, if: -> { saved_change_to_protection_level? && protection_level.present? }) { { wiki_page_title: title, protection_level: protection_level } }
    .add(:unprotect, :updater, on: :save, if: -> { saved_change_to_protection_level? && protection_level.blank? }) { { wiki_page_title: title, protection_level: protection_level } }
    .add(:delete, :destroyer, on: :destroy) { { wiki_page_title: title } }

  module SearchMethods
    def titled(title)
      find_by(title: WikiPage.normalize_name(title))
    end

    def recent
      default_order.limit(25)
    end

    def default_order
      order(updated_at: :desc)
    end

    def query_dsl
      super
        .field(:title, like: true, normalize: ->(value) { value.downcase.strip.tr(" ", "_") })
        .field(:title_matches, :title)
        .field(:body_matches, :body)
        .field(:protection_level)
        .field(:parent, normalize: ->(value) { value.tr(" ", "_") })
        .field(:ip_addr, :creator_ip_addr)
        .field(:updater_ip_addr)
        .custom(:linked_to, ->(q, v) { q.linked_to(v) })
        .custom(:not_linked_to, ->(q, v) { q.not_linked_to(v) })
        .association(:creator)
        .association(:updater)
    end

    def apply_order(params)
      order_with({
        title:           { "wiki_pages.title": :asc },
        post_count:      -> { includes(:tag).order(Tag.arel(:post_count).desc.nulls_last).references(:tags) },
        post_count_asc:  -> { includes(:tag).order(Tag.arel(:post_count).asc.nulls_last).references(:tags) },
        post_count_desc: -> { includes(:tag).order(Tag.arel(:post_count).desc.nulls_last).references(:tags) },
      }, params[:order])
    end
  end

  module HelpPageMethods
    def validate_not_used_as_help_page
      if help_page.present?
        errors.add(:wiki_page, "is used by a help page")
        throw(:abort)
      end
    end

    def update_help_page
      HelpPage.find_by(wiki_page: title_before_last_save)&.update(wiki_page: title)
    end
  end

  module RestrictionMethods
    def is_restricted?(user)
      protection_level.present? && protection_level > user.level
    end
  end

  module MergeMethods
    def merge_into!(wiki_page, user)
      theircount = wiki_page.versions.count
      ourcount = versions.count
      transaction do
        versions.each do |version|
          version.wiki_page = wiki_page
          version.save!
        end
        reload
        if (theircount + ourcount) != wiki_page.versions.count
          raise(MergeError, "Expected version count did not match")
        end
        ModAction.log!(user, :wiki_page_merge, self, wiki_page_title: title, target_wiki_page_id: wiki_page.id, target_wiki_page_title: wiki_page.title)
        self.destroyer = user
        destroy!
        wiki_page.update(updater: user)
        wiki_page.create_new_version(merged_from_id: id, merged_from_title: title, reason: "Merge from #{title}")
      end
    end
  end

  include(HelpPageMethods)
  include(RestrictionMethods)
  include(MergeMethods)
  extend(SearchMethods)

  def user_not_limited
    allowed = updater.can_wiki_edit_with_reason
    if allowed != true
      errors.add(:base, "User #{User.throttle_reason(allowed)}.")
      false
    end
    true
  end

  def validate_not_restricted
    if is_restricted?(updater)
      errors.add(:base, "Is protected and cannot be updated")
      false
    end
  end

  def validate_rename
    return unless will_save_change_to_title?
    if !updater.is_admin? && help_page.present?
      errors.add(:title, "is used as a help page and cannot be changed")
      return
    end

    tag_was = Tag.find_by(name: Tag.normalize_name(title_was))
    if tag_was.present? && !tag_was.empty?
      warnings.add(:base, %(Warning: {{#{title_was}}} still has #{tag_was.post_count} #{'post'.pluralize(tag_was.post_count)}. Be sure to move the posts))
    end

    broken_wikis = WikiPage.linked_to(title_was)
    if broken_wikis.any?
      broken_wiki_search = Routes.wiki_pages_path(search: { linked_to: title_was })
      warnings.add(:base, %(Warning: [[#{title_was}]] is still linked from "#{broken_wikis.count} #{'other wiki page'.pluralize(broken_wikis.count)}":[#{broken_wiki_search}]. Update #{broken_wikis.many? ? 'these wikis' : 'this wiki'} to link to [[#{title}]] instead))
    end
  end

  def post_count_rename_error?
    errors[:title].present? && errors[:title].any? { |e| e.include?("Move the posts and update any wikis linking to this page first.") }
  end

  def validate_name_not_restricted
    if INTERNAL_PREFIXES.any? { |prefix| title.starts_with?(prefix) } && !updater.is_janitor?
      errors.add(:title, "cannot start with '#{title.split(':')[0]}:'")
      throw(:abort)
    end
  end

  def ensure_internal_protected
    if INTERNAL_PREFIXES.any? { |prefix| title.starts_with?(prefix) } && (protection_level.blank? || protection_level < User::Levels.min_staff_level)
      self.protection_level = User::Levels.min_staff_level
    end
  end

  def validate_redirect
    return unless will_save_change_to_parent? && parent.present?
    if WikiPage.find_by(title: parent).blank?
      errors.add(:parent, "does not exist")
      return
    end

    if HelpPage.find_by(wiki_page: title).present?
      errors.add(:title, "is used as a help page and cannot be redirected")
    end
  end

  def normalize_title
    self.title = WikiPage.normalize_title(title)
  end

  def self.normalize_title(title)
    return "" if title.blank?
    title.downcase.tr(" ", "_")
  end

  def self.normalize_other_name(name)
    name.unicode_normalize(:nfkc).gsub(/[[:space:]]+/, " ").strip.tr(" ", "_")
  end

  def normalize_parent
    self.parent = nil if parent == ""
    set_parent_props
  end

  def normalize_protection_level
    self.protection_level = nil if protection_level.present? && protection_level <= User::Levels::MEMBER
  end

  def set_parent_props
    return if parent.blank?
    if parent.include?("#")
      name, anchor = parent.split("#")
      self.parent_name = name
      self.parent_anchor = anchor
    else
      self.parent_name = parent
    end
  end

  def self.normalize_name(name)
    name&.downcase&.tr(" ", "_")
  end

  def skip_secondary_validations=(value)
    @skip_secondary_validations = value.to_s.truthy?
  end

  def category_id
    Tag.category_for(title)
  end

  def pretty_title
    title&.tr("_", " ") || ""
  end

  def pretty_title_with_category
    return pretty_title if category_id == 0
    "#{Tag.category_for_value(category_id)}: #{pretty_title}"
  end

  def wiki_page_changed?
    saved_change_to_title? || saved_change_to_body? || saved_change_to_protection_level? || saved_change_to_parent?
  end

  def create_new_version(extra = {})
    versions.create(
      updater:          updater,
      title:            title,
      body:             body,
      protection_level: protection_level,
      parent:           parent,
      reason:           edit_reason,
      **extra,
    )
  end

  def create_version
    if wiki_page_changed?
      create_new_version
    end
  end

  def post_set(user)
    @post_set ||= PostSets::Post.new(title, 1, limit: 4, current_user: user)
  end

  def tags
    body.scan(/\[\[(.+?)\]\]/).flatten.map do |match|
      if match =~ /^(.+?)\|(.+)/
        $1
      else
        match
      end
    end.map { |x| x.downcase.tr(" ", "_").to_s }.uniq
  end

  def self.is_meta_wiki?(title)
    title.present? && META_PREFIXES.any? { |prefix| title.starts_with?(prefix) }
  end

  def is_meta_wiki?
    WikiPage.is_meta_wiki?(title)
  end

  def can_edit?(user)
    persisted? && (protection_level.blank? || user.level >= protection_level)
  end

  def self.safe_wiki(title)
    titled(title) || new(body: "The wiki page \"#{title}\" was not found.")
  end

  def self.rewrite_wiki_links!(old_name, new_name)
    WikiPage.linked_to(old_name).each do |wiki|
      wiki.with_lock do
        wiki.update!(description: DTextHelper.rewrite_wiki_links(wiki.description, old_name, new_name))
      end
    end
  end

  def self.available_includes
    %i[artist dtext_links help_page tag]
  end
end

# frozen_string_literal: true

class Tag < ApplicationRecord
  has_one(:wiki_page, foreign_key: "title", primary_key: "name")
  has_one(:artist, foreign_key: "name", primary_key: "name")
  has_one(:antecedent_alias, -> { active }, class_name: "TagAlias", foreign_key: "antecedent_name", primary_key: "name")
  has_many(:consequent_aliases, -> { active }, class_name: "TagAlias", foreign_key: "consequent_name", primary_key: "name")
  has_many(:antecedent_implications, -> { active }, class_name: "TagImplication", foreign_key: "antecedent_name", primary_key: "name")
  has_many(:consequent_implications, -> { active }, class_name: "TagImplication", foreign_key: "consequent_name", primary_key: "name")
  has_many(:versions, class_name: "TagVersion")
  has_many(:followers, class_name: "TagFollower")

  validates(:name, uniqueness: true, tag_name: true, on: :create)
  validates(:name, length: { minimum: 1, maximum: 100 })
  validates(:category, inclusion: { in: TagCategory.ids })
  validate(:user_can_create_tag?, on: :create)
  validate(:user_can_change_category?, if: :category_changed?)

  before_save(:update_category, if: :category_changed?)
  after_create(:create_version)
  after_update(:create_version, if: ->(rec) { rec.saved_change_to_category? || rec.saved_change_to_is_locked? })
  belongs_to_user(:creator, ip: true, clones: :updater)
  resolvable(:updater)

  attr_accessor(:reason)

  TagCategory.categories.each do |category|
    scope(category.name, -> { where(category: category.id) })
    next unless category != TagCategory::INVALID # We can't this because we would override the internal "invalid?" method
    define_singleton_method("#{category.name}?") do |record|
      record.category == category.id
    end
  end

  scope(:invalid, -> { where(category: TagCategory::INVALID) })
  scope(:empty, -> { where.lteq(post_count: 0) })
  scope(:nonempty, -> { where.gt(post_count: 0) })

  module CountMethods
    extend(ActiveSupport::Concern)

    module ClassMethods
      def increment_post_counts(tag_names)
        return if tag_names.empty?

        Tag.where(name: tag_names).order(:name).lock("FOR UPDATE").pluck(1)
        Tag.where(name: tag_names).update_all("post_count = post_count + 1")
      end

      def decrement_post_counts(tag_names)
        return if tag_names.empty?

        Tag.where(name: tag_names).order(:name).lock("FOR UPDATE").pluck(1)
        Tag.where(name: tag_names).update_all("post_count = post_count - 1")
      end

      def clean_up_negative_post_counts!
        Tag.where.lt(post_count: 0).find_each do |tag|
          tag_alias = TagAlias.where(status: %w[active processing], antecedent_name: tag.name).first
          tag.fix_post_count
          tag_alias&.consequent_tag&.fix_post_count
        end
      end
    end

    def real_post_count
      @real_post_count ||= Post.tag_match_system(name, resolve_aliases: false).count_only
    end

    def fix_post_count
      update_column(:post_count, real_post_count)
    end
  end

  module CategoryMethods
    module ClassMethods
      def category_for(tag_name)
        Cache.fetch("tc:#{tag_name}") do
          Tag.where(name: tag_name).pick(:category).to_i
        end
      end

      def categories_for(tag_names, disable_cache: false)
        if disable_cache
          tag_cats = {}
          Tag.where(name: Array(tag_names)).select(%i[id name category]).find_each do |tag|
            tag_cats[tag.name] = tag.category
          end
          tag_cats
        else
          found = Cache.read_multi(Array(tag_names), "tc")
          not_found = tag_names - found.keys
          if not_found.any?
            # Is multi_write worth it here? Normal usage of this will be short put lists and then never touched.
            Tag.where(name: not_found).select(%i[id name category]).find_each do |tag|
              Cache.write("tc:#{tag.name}", tag.category)
              found[tag.name] = tag.category
            end
          end
          found
        end
      end

      def category_for_value(value)
        TagCategory.reverse_mapping.fetch(value, "unknown category").capitalize
      end
    end

    def self.included(mod)
      mod.extend(ClassMethods)
    end

    def category_name
      TagCategory.get(category).title
    end

    def update_category_post_counts!
      Post.with_timeout(30_000, nil) do
        Post.sql_raw_tag_match(name).find_each do |post|
          post.update_typed_tags # does not save
          post.save!
          post.update_pool_artists
          post.update_index
        end
      end
    end

    def update_category_post_counts
      UpdateTagCategoryJob.perform_later(id)
    end

    def update_category_cache
      Cache.write("tc:#{name}", category, expires_in: 3.hours)
    end

    def user_can_change_category?
      cat = TagCategory.get(category)
      return false unless cat
      unless cat.can_use?(updater)
        errors.add(:category, "can only used by admins")
        return false
      end
      if cat.suffixes&.none? { |s| name&.ends_with?("_(#{s})") }
        errors.add(:category, "can only be applied to tags that end with #{cat.suffixes.map { |s| "'_(#{s})'" }.join(', ')}")
        false
      end
    end

    def update_category
      update_category_cache
      update_category_post_counts unless new_record?
    end

    def create_version
      TagVersion.create(tag_id:          id,
                        updater:         updater,
                        updater_ip_addr: updater_ip_addr,
                        category:        category.to_i,
                        is_locked:       is_locked?,
                        is_deprecated:   is_deprecated?,
                        reason:          reason || "")
    end

    TagCategory.categories.map(&:name).each do |category|
      define_method("#{category}?") do
        self.category == TagCategory.value_for(category)
      end
    end
  end

  module NameMethods
    def normalize_name(name)
      name.to_s.unicode_normalize(:nfc).downcase.strip.tr(" ", "_").to_s
    end

    def find_by_normalized_name(name)
      find_by(name: normalize_name(name))
    end

    def find_by_name_list(names)
      names = names.to_h { |x| [normalize_name(x), nil] }
      existing = Tag.where(name: names.keys).to_a
      existing.each do |x|
        names[x.name] = x
      end
      names
    end

    def find_or_create_by_name_list(names, user:, reason: nil, artist: false)
      names = names.map { |x| normalize_name(x) }
      names = names.to_h do |x|
        if x =~ /\A(#{TagCategory.regexp}):(.+)\Z/
          [$2, $1]
        else
          [x, nil]
        end
      end

      existing = Tag.where(name: names.keys).to_a
      existing.each do |tag|
        cat = names[tag.name]
        category_id = TagCategory.value_for(cat)
        if cat && category_id != tag.category
          if tag.category_editable_by_implicit?(user, artist: artist)
            tag.update(category: category_id, reason: reason, updater: user)
          else
            tag.errors.add(:category, "cannot be changed implicitly through a tag prefix")
          end
        end
        names.delete(tag.name)
      end

      names.each do |name, cat|
        existing << Tag.new.tap do |t|
          t.name = name
          t.category = TagCategory.value_for(cat)
          t.reason = reason
          t.creator = user
          t.save
        end
      end
      existing
    end

    def find_or_create_by_name(name, user:, reason: nil, artist: false)
      name = normalize_name(name)
      category = nil

      if name =~ /\A(#{TagCategory.regexp}):(.+)\Z/
        category = $1
        name = $2
      end

      tag = find_by(name: name)
      if tag
        if category
          category_id = TagCategory.value_for(category)
          # in case a category change hasn't propagated to this server yet,
          # force an update the local cache. This may get overwritten in the
          # next few lines if the category is changed.
          tag.update_category_cache

          unless category_id == tag.category
            if tag.category_editable_by_implicit?(user, artist: artist)
              tag.update(category: category_id, reason: reason, updater: user)
            else
              tag.errors.add(:category, "cannot be changed implicitly through a tag prefix")
            end
          end
        end

        tag
      else
        Tag.new.tap do |t|
          t.name = name
          t.category = TagCategory.value_for(category)
          t.reason = reason
          t.creator = user
          t.save
        end
      end
    end
  end

  module RelationMethods
    def update_related
      return unless should_update_related?

      self.related_tags = RelatedTagCalculator.calculate_from_sample_to_array(name).join(" ")
      self.related_tags_updated_at = Time.now
      fix_post_count if post_count > 20 && rand(post_count) <= 1
      save
    rescue ActiveRecord::StatementInvalid
      # Ignored
    end

    def update_related_if_outdated
      if Cache.fetch("urt:#{name}").nil? && should_update_related?
        TagUpdateRelatedJob.perform_later(id)
        Cache.write("urt:#{name}", true, expires_in: 10.minutes) # mutex to prevent redundant updates
      end
    end

    def related_cache_expiry
      base = Math.sqrt([post_count, 0].max)
      base.clamp(24, 24 * 30)
    end

    def should_update_related?
      related_tags.blank? || related_tags_updated_at.blank? || related_tags_updated_at < related_cache_expiry.hours.ago
    end

    def related_tag_array
      update_related_if_outdated
      related_tags.to_s.split(/ /).in_groups_of(2)
    end
  end

  module SearchMethods
    def query_dsl
      super
        .field(:is_locked)
        .field(:category, multi: true)
        .field(:ip_addr, :creator_ip_addr)
        .field(:name, normalize: Tag.method(:normalize_name))
        .field(:name_matches, :name, normalize: Tag.method(:normalize_name))
        # ref: https://www.postgresql.org/docs/current/static/pgtrgm.html#idm46428634524336
        .custom(:fuzzy_name_matches, ->(q, v) { q.where("tags.name % ?", v) })
        .present(:has_wiki, "wiki_pages.id") { |q| q.left_outer_joins(:wiki_page) }
        .present(:has_artist, "artists.id") { |q| q.left_outer_joins(:artist) }
        .association(:creator)
    end

    # ref: https://www.postgresql.org/docs/current/static/pgtrgm.html#idm46428634524336
    def order_similarity(name)
      # trunc(3 * sim) reduces the similarity score from a range of 0.0 -> 1.0 to just 0, 1, or 2.
      # This groups tags first by approximate similarity, then by largest tags within groups of similar tags.
      order(Arel.sql("trunc(3 * similarity(name, #{connection.quote(name)})) DESC"), "post_count DESC", "name DESC")
    end

    def name_matches(name)
      where.like(name: normalize_name(name))
    end

    def search(params, user)
      q = super
      q = q.nonempty if params[:hide_empty].blank? || params[:hide_empty].to_s.truthy?
      q
    end

    def apply_order(params)
      order_with({
        name:       { "tags.name": :asc },
        count:      { "tags.post_count": :desc },
        similarity: -> { order_similarity(params[:fuzzy_name_matches]) if params[:fuzzy_name_matches].present? },
      }, params[:order])
    end
  end

  module FollowerMethods
    def follow!(user)
      return if followers.exists?(user: user)
      raise(TagFollower::AliasedTagError) if antecedent_alias.present?
      last_post = Post.sql_raw_tag_match(name).order(id: :asc).last
      followers.create(user: user, last_post: last_post)
    end

    def unfollow!(user)
      return unless followers.exists?(user: user)
      followers.find_by(user: user).destroy
    end
  end

  def category_editable_by_implicit?(user, artist: false)
    return false unless user.is_janitor? || artist
    return false if is_locked?
    return false if post_count >= AdminConfig.get_user(:tag_type_edit_implicit_limit, user)
    true
  end

  def category_editable_by?(user)
    return false if is_locked? && !user.is_admin?
    return false unless TagCategory.get(category).can_use?(user)
    return true if post_count < AdminConfig.get_user(:tag_type_edit_limit, user)
    false
  end

  def user_can_create_tag?
    if name =~ /\A.*_\((lore)\)\z/ && !creator.is_admin?
      errors.add(:base, "Can not create #{$1} tags unless admin")
      errors.add(:name, "is invalid")
      return false
    end
    true
  end

  include(CountMethods)
  include(CategoryMethods)
  include(RelationMethods)
  include(FollowerMethods)
  extend(NameMethods)
  extend(SearchMethods)

  def serializable_hash(*)
    super.merge(related_tags: related_tag_array.map { |r| { tag: r[0], count: r[1].to_i } })
  end

  def empty?
    post_count <= 0
  end

  def self.available_includes
    %i[artist antecedent_alias wiki_page]
  end
end

# frozen_string_literal: true

module TagCategory
  module_function

  Category = Struct.new(:id, :name, :aliases) do
    KWARGS = %i[header suffixes limit exclusion regex formatstr display].freeze # rubocop:disable Lint/ConstantDefinitionInBlock
    attr_accessor(*KWARGS)

    def initialize(*, **kwargs)
      super(*)
      KWARGS.each do |key|
        send("#{key}=", kwargs[key])
      end
      self.aliases ||= []
      self.header ||= name.titlecase
      self.display ||= name.titlecase
    end

    def values
      [name, *aliases]
    end

    def title
      name.titleize
    end

    def admin_only?
      is_a?(AdminCategory)
    end

    def can_use?(user)
      !admin_only? || (user.is_system? || user.is_admin?)
    end

    KWARGS.each do |name|
      define_method(name) do
        value = instance_variable_get(:"@#{name}")
        return value.call if value.is_a?(Proc)
        value
      end
    end
  end
  class AdminCategory < Category; end

  GENERAL = Category.new(0, "general", %w[gen])
  ARTIST = Category.new(1, "artist", %w[art], header: "Artists", exclusion: -> { AdminConfig.instance.ary(:artist_exclusion_tags) }, formatstr: "created by %s")
  CONTRIBUTOR = Category.new(2, "contributor", %w[cont], header: "Contributors", suffixes: -> { AdminConfig.instance.ary(:contributor_suffixes) })
  COPYRIGHT = Category.new(3, "copyright", %w[copy co], header: "Copyrights", limit: 1, formatstr: "(%s)")
  CHARACTER = Category.new(4, "character", %w[char ch oc], header: "Characters", limit: 5, regex: /^(.+?)(?:_\(.+\))?$/)
  SPECIES = Category.new(5, "species", %w[spec])
  INVALID = AdminCategory.new(6, "invalid", %w[inv])
  META = AdminCategory.new(7, "meta")
  LORE = AdminCategory.new(8, "lore", %w[lor], suffixes: -> { AdminConfig.instance.ary(:lore_suffixes) })
  GENDER = AdminCategory.new(9, "gender")
  IMPORTANT = AdminCategory.new(10, "important", %w[imp])

  def categories
    @categories ||= constants.map { |c| const_get(c) }.grep(Category)
  end

  def get(value)
    value = reverse_mapping[value] if value.is_a?(Integer)
    categories.find { |c| c.name == value.to_s.downcase }
  end

  def ids
    @ids ||= categories.map(&:id)
  end

  def mapping
    @mapping ||= categories.flat_map { |c| c.values.map { |v| [v, c.id] } }.to_h
  end

  def reverse_mapping
    @reverse_mapping ||= categories.to_h { |c| [c.id, c.name] }
  end

  def for_select
    categories.map { |c| [c.display, c.id] }
  end

  def regexp
    @regexp ||= Regexp.compile(mapping.keys.sort_by { |x| -x.length }.join("|"))
  end

  def value_for(string)
    mapping[string.to_s.downcase] || 0
  end

  def short_name_mapping
    @short_name_mapping ||= categories.flat_map { |c| c.aliases.empty? ? [[c.name, c.name]] : c.aliases.map { |a| [a, c.name] } }.to_h
  end

  def short_name_list
    @short_name_list ||= short_name_mapping.keys
  end

  def short_name_regex
    @short_name_regex ||= short_name_mapping.keys.join("|")
  end

  def category_names
    @category_names ||= categories.map(&:name)
  end

  categories.each do |cat|
    define_method(cat.name) do
      cat.id
    end
  end

  SPLIT_HEADER_LIST = %w[important invalid artist contributor copyright character species gender general meta lore].freeze
  CATEGORIZED_LIST = %w[important invalid artist contributor copyright character species gender meta general lore].freeze
  HUMANIZED_LIST = %w[character copyright artist].freeze
end

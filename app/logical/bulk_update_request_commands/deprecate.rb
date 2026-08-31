# frozen_string_literal: true

module BulkUpdateRequestCommands
  class Deprecate < Base
    set_command(:deprecate)
    set_arguments(:tag_name, :comment)
    set_regex(/\Adeprecate (\S+)(?: # ?(.*))?\z/i, %i[tag pass])
    set_untokenize { |tag_name, comment| "deprecate #{tag_name}#{" # #{comment}" if comment}" }
    set_to_dtext { |tag, comment| "deprecate [[#{tag.name}]] (#{tag.post_count})#{" # #{comment}" if comment}" }

    validate(:tag_exists)
    validate(:wiki_exists)
    validate(:not_deprecated)

    def tag_exists
      comments.add(:base, "missing") if tag.blank?
    end

    def wiki_exists
      comments.add(:base, "must have wiki page") if tag.present? && tag.wiki_page.blank?
    end

    def not_deprecated
      comments.add(:base, "already deprecated") if tag.present? && tag.is_deprecated?
    end

    def estimate_update_count
      tag.try(:post_count) || 0
    end

    def tags
      [tag_name]
    end

    def approved?
      Tag.exists?(name: tag_name, is_deprecated: true)
    end

    def category_changes
      t = tag || Tag.new(name: tag_name)
      return [] unless t.general?
      [[t, TagCategory.invalid]]
    end

    def process(_processor, approver)
      ensure_valid!
      t = tag
      t.category = TagCategory.invalid if t.general?
      t.is_deprecated = true
      t.updater = approver
      t.save!
      t.consequent_aliases.find_each { |ta| ta.reject!(approver) }
      t.consequent_implications.find_each { |ti| ti.reject!(approver) }
      t.antecedent_implications.find_each { |ti| ti.reject!(approver) }
    end
  end
end

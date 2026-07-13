# frozen_string_literal: true

module BulkUpdateRequestCommands
  class Rename < Base
    POST_LIMIT = 200

    set_command(:rename)
    set_arguments(:antecedent_name, :consequent_name, :comment)
    set_regex(/\Arename (\S+) -> (\S+)(?: # ?(.*))?\z/i, %i[tag tag pass])
    set_untokenize { |antecedent_name, consequent_name, comment| "rename #{antecedent_name} -> #{consequent_name}#{" # #{comment}" if comment}" }
    set_to_dtext { |antecedent_tag, consequent_tag, comment| "rename [[#{antecedent_tag.name}]] (#{antecedent_tag.post_count}) -> [[#{consequent_tag.name}]] (#{consequent_tag.post_count})#{" # #{comment}" if comment}" }

    validate(:validate_antecedent)
    validate(:validate_consequent)

    def validate_antecedent
      return comments.add(:base, "antecedent tag missing") if antecedent_tag.blank?
      errors.add(:base, "antecedent tag is not an artist tag") unless antecedent_tag.artist?
      errors.add(:base, "antecedent tag has too many posts") if antecedent_tag.post_count > POST_LIMIT
    end

    def validate_consequent
      # empty is defined on Tag
      return if consequent_tag.nil? || consequent_tag.empty? # rubocop:disable Rails/Blank
      errors.add(:base, "consequent tag is not an artist tag") unless consequent_tag.artist?
      errors.add(:base, "consequent tag has too many posts") if consequent_tag.post_count > POST_LIMIT
    end

    def tags
      [antecedent_name, consequent_name]
    end

    def estimate_update_count
      return 0 unless valid?
      Post.system_count(antecedent_name, enable_safe_mode: false, include_deleted: true)
    end

    def category_changes
      return [] if consequent_tag&.artist?
      [[consequent_tag || Tag.new(name: consequent_name), TagCategory.artist]]
    end

    def process(_processor, approver)
      ensure_valid!
      mover = TagMover.new(antecedent_name, consequent_name, user: approver, request: self)
      mover.move!
      self.undo_data = mover.undos
    end
  end
end

# frozen_string_literal: true

class Rule < ApplicationRecord
  belongs_to_user(:creator, ip: true, clones: :updater)
  belongs_to_user(:updater, ip: true)
  resolvable(:destroyer)
  belongs_to(:category, class_name: "RuleCategory")
  validates(:name, presence: true, uniqueness: { case_sensitive: false }, length: { min: 3, maximum: 100 })
  validates(:description, presence: true, length: { maximum: 50_000 })
  validates(:order, uniqueness: { scope: :category_id }, numericality: { only_integer: true, greater_than: 0 })
  has_many(:quick_rules, -> { order(:order) }, dependent: :destroy)

  before_validation(on: :create) do
    self.order = (Rule.where(category: category).maximum(:order) || 0) + 1 if order.blank?
    self.anchor = name.parameterize if anchor.blank?
  end
  before_destroy(:set_quick_rules_destroyer, prepend: true)

  def set_quick_rules_destroyer
    return if quick_rules.blank? || destroyer.blank?
    quick_rules.each { |quick_rule| quick_rule.destroyer = destroyer }
  end

  modactions(:rule)
    .add(:create, :creator, on: :create) { { name: name, description: description, category_name: category.name } }
    .add(:update, :updater, on: :update) do
      {
        name:              name,
        old_name:          name_before_last_save,
        description:       description,
        old_description:   description_before_last_save,
        category_name:     category.name,
        old_category_name: RuleCategory.find_by(id: category_id_before_last_save)&.name || "Unknown: #{category_id_before_last_save}",
      }
    end
    .add(:delete, :destroyer, on: :destroy) { { name: name, description: description, category_name: category.name } }

  def self.log_reorder(changes, user)
    ModAction.log!(user, :rules_reorder, nil, total: changes)
  end

  def self.available_includes
    %i[category creator updater]
  end
end

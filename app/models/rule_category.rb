# frozen_string_literal: true

class RuleCategory < ApplicationRecord
  belongs_to_user(:creator, ip: true, clones: :updater)
  belongs_to_user(:updater, ip: true)
  resolvable(:destroyer)

  validates(:name, presence: true, length: { min: 3, maximum: 100 }, uniqueness: { case_sensitive: false })
  validates(:anchor, length: { maximum: 100 })
  validates(:order, uniqueness: true, numericality: { only_integer: true, greater_than: 0 })
  has_many(:rules, -> { order(:order) }, dependent: :destroy, foreign_key: :category_id)
  before_destroy(:set_rules_destroyer, prepend: true)

  modactions(:rule_category)
    .add(:create, :creator, on: :create) { { name: name } }
    .add(:update, :updater, on: :update) { { name: name, old_name: name_before_last_save } }
    .add(:delete, :destroyer, on: :destroy) { { name: name } }

  def set_rules_destroyer
    return if rules.blank? || destroyer.blank?
    rules.each { |rule| rule.destroyer = destroyer }
  end

  before_validation(on: :create) do
    self.order = (RuleCategory.maximum(:order) || 0) + 1 if order.blank?
    self.anchor = name.parameterize if name && anchor.blank?
  end

  def format_rules(category)
    rules = category.rules.map do |rule|
      "#{category.order}.#{rule.order} [[##{rule.anchor}|#{rule.title}]]"
    end
    rules.join("\n")
  end

  def self.log_reorder(changes, user)
    ModAction.log!(user, :rule_categories_reorder, nil, total: changes)
  end

  def self.available_includes
    %i[creator updater]
  end
end

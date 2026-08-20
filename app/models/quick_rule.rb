# frozen_string_literal: true

class QuickRule < ApplicationRecord
  validates(:order, uniqueness: true, numericality: { only_integer: true, greater_than: 0 })
  validates(:reason, length: { minimum: 3, maximum: 500 })
  validates(:header, length: { maximum: 30 })
  belongs_to(:rule)
  belongs_to_user(:creator, ip: true, clones: :updater)
  belongs_to_user(:updater, ip: true)
  resolvable(:destroyer)

  before_validation(on: :create) do
    self.order = (QuickRule.maximum(:order) || 0) + 1 if order.blank?
  end

  modactions(:quick_rule)
    .add(:create, :creator, on: :create) { { reason: reason, header: header } }
    .add(:update, :updater, on: :update, if: -> { saved_change_to_reason? || saved_change_to_header? }) { { reason: reason, old_reason: reason_before_last_save, header: header, old_header: header_before_last_save } }
    .add(:delete, :destroyer, on: :destroy) { { reason: reason, header: header } }

  def self.log_reorder(total, user)
    ModAction.log!(user, :quick_rules_reorder, nil, total: total)
  end

  def self.available_includes
    %i[rule]
  end
end

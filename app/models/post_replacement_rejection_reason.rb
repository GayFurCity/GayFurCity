# frozen_string_literal: true

class PostReplacementRejectionReason < ApplicationRecord
  belongs_to_user(:creator, ip: true, clones: :updater)
  belongs_to_user(:updater, ip: true)
  resolvable(:destroyer)
  validates(:reason, presence: true, length: { maximum: 100 }, uniqueness: { case_sensitive: false })
  validates(:order, uniqueness: true, numericality: { only_numeric: true })

  before_validation(on: :create) do
    self.order = (PostReplacementRejectionReason.maximum(:order) || 0) + 1 if order.blank?
  end

  modactions(:post_replacement_rejection_reason)
    .add(:create, :creator, on: :create) { { reason: reason } }
    .add(:update, :updater, on: :update) { { reason: reason, old_reason: reason_before_last_save } }
    .add(:delete, :destroyer, on: :destroy) { { reason: reason, user_id: creator_id } }

  module SearchMethods
    def quick_access
      where.not(title: nil, prompt: nil).order(id: :desc)
    end
  end

  extend(SearchMethods)

  def self.log_reorder(changes, user)
    ModAction.log!(user, :post_replacement_rejection_reasons_reorder, nil, total: changes)
  end

  def self.available_includes
    %i[creator]
  end

  def visible?(user)
    user.is_approver?
  end
end

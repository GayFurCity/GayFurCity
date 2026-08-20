# frozen_string_literal: true

class PostDeletionReason < ApplicationRecord
  belongs_to_user(:creator, ip: true, clones: :updater)
  belongs_to_user(:updater, ip: true)
  resolvable(:destroyer)
  validates(:reason, presence: true, length: { maximum: 100 }, uniqueness: { case_sensitive: false })
  validates(:title, allow_blank: true, length: { maximum: 100 }, uniqueness: { case_sensitive: false })
  validates(:prompt, allow_blank: true, length: { maximum: 100 }, uniqueness: { case_sensitive: false })
  validates(:order, uniqueness: true, numericality: { only_numeric: true })
  validate(:validate_prompt_and_title)

  before_validation(on: :create) do
    self.order = (PostDeletionReason.maximum(:order) || 0) + 1 if order.blank?
  end

  def validate_prompt_and_title
    errors.add(:prompt, "is required") if prompt.blank? && title.present?
    errors.add(:title, "is required") if title.blank? && prompt.present?
  end

  modactions(:post_deletion_reason)
    .add(:create, :creator, on: :create) { { reason: reason, title: title, prompt: prompt } }
    .add(:update, :updater, on: :update) do
      {
        reason: reason, old_reason: reason_before_last_save,
        title:  title,  old_title:  title_before_last_save,
        prompt: prompt, old_prompt: prompt_before_last_save,
      }
    end
    .add(:delete, :destroyer, on: :destroy) { { reason: reason, title: title, prompt: prompt, user_id: creator_id } }

  module SearchMethods
    def quick_access
      where.not(title: nil, prompt: nil).order(id: :desc)
    end
  end

  extend(SearchMethods)

  def self.log_reorder(changes, user)
    ModAction.log!(user, :post_deletion_reasons_reorder, nil, total: changes)
  end

  def self.available_includes
    %i[creator]
  end

  def visible?(user)
    user.is_approver?
  end
end

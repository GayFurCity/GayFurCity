# frozen_string_literal: true

class UserFeedback < ApplicationRecord
  belongs_to_user(:user)
  belongs_to_user(:creator, ip: true, clones: :updater)
  belongs_to_user(:updater, ip: true)
  resolvable(:destroyer)
  soft_deletable
  normalizes(:body, with: ->(body) { body.gsub("\r\n", "\n") })
  validates(:body, :category, presence: true)
  validates(:body, length: { minimum: 1, maximum: -> { AdminConfig.instance.user_feedback_max_size } })
  validate(:creator_is_moderator, on: :create)
  validate(:user_is_not_creator)
  after_destroy(:create_staff_note_on_destroy)
  after_destroy(:send_notifications)
  after_save(:send_notifications)
  enum(:category, %w[positive negative neutral].index_with(&:to_s))

  attr_accessor(:send_update_notification)

  scope(:active, -> { where(is_deleted: false) })
  scope(:deleted, -> { where(is_deleted: true) })

  modactions(:user_feedback)
    .add(:create, :creator, on: :create) { { user_id: user_id, reason: body, type: category } }
    .add(:delete, :updater, on: :update, if: -> { saved_change_to_is_deleted? && is_deleted? }) { { user_id: user_id, reason: body, type: category, record_id: id } }
    .add(:undelete, :updater, on: :update, if: -> { saved_change_to_is_deleted? && !is_deleted? }) { { user_id: user_id, reason: body, type: category, record_id: id } }
    .add(:update, :updater, on: :update, unless: -> { saved_change_to_is_deleted? }) do
      { user_id: user_id, reason: body, old_reason: body_before_last_save, type: category, old_type: category_before_last_save, record_id: id }
    end
    .add(:destroy, :destroyer, on: :destroy) { { user_id: user_id, reason: body, type: category, record_id: id } }

  def create_staff_note_on_destroy
    deletion_user = "\"#{destroyer_name}\":/users/#{destroyer_id}"
    creator_user = "\"#{creator_name}\":/users/#{creator_id}"
    StaffNote.create(body: "#{deletion_user} destroyed #{category} feedback, created #{created_at.to_date} by #{creator_user}: #{body}", user_id: user_id, creator: User.system)
  end

  def send_notifications
    if previously_new_record?
      user.notifications.create!(category: "feedback_create", data: { user_id: updater_id, record_id: id, record_type: category })
    elsif destroyed?
      user.notifications.create!(category: "feedback_destroy", data: { user_id: destroyer_id, record_id: id, record_type: category })
    else
      if saved_change_to_is_deleted?
        user.notifications.create!(category: is_deleted? ? :feedback_delete : :feedback_undelete, data: { user_id: updater_id, record_id: id, record_type: category })
      end

      if send_update_notification.to_s.truthy? && saved_change_to_body?
        user.notifications.create!(category: "feedback_update", data: { user_id: updater_id, record_id: id, record_type: category })
      end
    end
  end

  module SearchMethods
    def default_order
      order(created_at: :desc)
    end

    def query_dsl
      super
        .field(:body_matches, :body)
        .field(:category)
        .field(:ip_addr, :creator_ip_addr)
        .field(:updater_ip_addr)
        .association(:user)
        .association(:creator)
        .association(:updater)
    end

    def search(params, user)
      q = super

      deleted = (params[:deleted].presence || "excluded").downcase
      q = q.active if deleted == "excluded"
      q = q.deleted if deleted == "only"
      q
    end
  end

  extend(SearchMethods)

  def user_name
    User.id_to_name(user_id)
  end

  def user_name=(name)
    self.user_id = User.name_to_id(name)
  end

  def creator_is_moderator
    errors.add(:creator, "must be moderator") unless creator.is_moderator?
  end

  def user_is_not_creator
    errors.add(:creator, "cannot submit feedback for yourself") if user_id == creator_id
  end

  def editable_by?(editor)
    editor.is_moderator? && editor != user
  end

  def deletable_by?(deleter)
    deleter.is_moderator? && deleter != user
  end

  def destroyable_by?(destroyer)
    deletable_by?(destroyer) && (destroyer.is_admin? || destroyer == creator)
  end

  def self.available_includes
    %i[creator updater user]
  end

  def visible?(user)
    user.is_moderator? || !is_deleted?
  end
end

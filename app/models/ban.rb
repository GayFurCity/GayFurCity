# frozen_string_literal: true

class Ban < ApplicationRecord
  attr_accessor(:is_permaban)

  before_validation(:initialize_permaban, on: %i[update create])
  before_create(:create_feedback)
  after_create(:update_user_on_create)
  belongs_to_user(:user)
  belongs_to_user(:banner, ip: true, clone: :updater, aliases: :creator) # TODO: convert to creator
  belongs_to_user(:updater, ip: true)
  resolvable(:destroyer)
  validate(:user_is_inferior)
  validates(:reason, :duration, presence: true)
  validates(:reason, length: { minimum: 1, maximum: -> { Config.instance.user_feedback_max_size } })

  scope(:unexpired, -> { where(expires_at: nil).or(where.gt(expires_at: Time.now)) })
  scope(:expired, -> { where.not(expires_at: nil).or(where.lte(expires_at: Time.now)) })

  modactions(:ban)
    .add(:create, :creator, on: :create) { { duration: duration, reason: reason, user_id: user_id } }
    .add(:update, :updater, on: :update) do
      { user_id: user_id }
        .tap { |h| h.merge!({ expires_at: expires_at&.iso8601, old_expires_at: expires_at_before_last_save&.iso8601 }) if saved_change_to_expires_at? }
        .tap { |h| h.merge!({ reason: reason, old_reason: reason_before_last_save }) if saved_change_to_reason? }
    end
    .add(:delete, :destroyer, on: :destroy) { { user_id: user_id } }

  def self.is_banned?(user)
    unexpired.for_user(user).exists?
  end

  module SearchMethods
    def search(params, user, visible: true)
      super.if(params[:expired], -> { expired }).else(-> { unexpired })
    end

    def query_dsl
      super
        .field(:reason_matches, :reason)
        .field(:ip_addr, :banner_ip_addr)
        .association(:banner)
        .association(:user)
    end

    def apply_order(params)
      order_with({
        expires_at:      -> { order(arel(:expires_at).desc.nulls_last) },
        expires_at_asc:  -> { order(arel(:expires_at).asc.nulls_last) },
        expires_at_desc: -> { order(arel(:expires_at).desc.nulls_last) },
      }, params[:order])
    end
  end

  extend(SearchMethods)

  def initialize_permaban
    if is_permaban.to_s.truthy?
      self.duration = -1
    end
  end

  def user_is_inferior
    if user
      if user.is_admin?
        errors.add(:base, "You can never ban an admin.")
        false
      elsif user.is_moderator? && banner.is_admin?
        true
      elsif user.is_moderator?
        errors.add(:base, "Only admins can ban moderators.")
        false
      elsif banner.is_admin? || banner.is_moderator? # rubocop:disable Lint/DuplicateBranch
        true
      else
        errors.add(:base, "No one else can ban.")
        false
      end
    end
  end

  def update_user_on_create
    user.ban!(banner)
  end

  def user_name
    return if user_id.blank?
    if association(:user).loaded?
      user.name
    end
    User.id_to_name(user_id)
  end

  def user_name=(username)
    self.user_id = User.name_to_id(username)
  end

  def duration=(dur)
    dur = dur.to_i
    if dur < 0
      self.expires_at = nil
    else
      self.expires_at = dur.days.from_now
    end
    @duration = dur if dur != 0
  end

  attr_reader(:duration)

  def humanized_duration
    return "permanent" if expires_at.nil?
    ApplicationController.helpers.distance_of_time_in_words(created_at, expires_at)
  end

  def humanized_expiration
    return "never" if expires_at.nil?
    ApplicationController.helpers.compact_time(expires_at)
  end

  def expire_days
    return "never" if expires_at.nil?
    Helpers.time_ago_in_words(expires_at)
  end

  def expire_days_tagged
    return Helpers.tag.em(Helpers.tag.time("never")) if expires_at.nil?
    Helpers.time_ago_in_words_tagged(expires_at)
  end

  def expired?
    !expires_at.nil? && expires_at < Time.now
  end

  def create_feedback
    time = expires_at.nil? ? "permanently" : "for #{humanized_duration}"
    user.feedback.create!(category: "negative", body: "Banned #{time}: #{reason}", creator: banner)
  end

  def self.available_includes
    %i[banner user]
  end
end

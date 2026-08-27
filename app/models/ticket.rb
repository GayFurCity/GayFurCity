# frozen_string_literal: true

class Ticket < ApplicationRecord
  belongs_to_user(:creator, ip: true, clones: :updater, counter_cache: "ticket_count")
  belongs_to_user(:claimant, optional: true)
  belongs_to_user(:handler, ip: true, optional: true)
  belongs_to_user(:accused, optional: true)
  resolvable(:updater)
  belongs_to(:model, polymorphic: true)
  before_validation(:initialize_accused, on: :create)
  normalizes(:reason, with: ->(reason) { reason.gsub("\r\n", "\n") })
  validates(:reason, presence: true)
  validates(:reason, length: { minimum: 2, maximum: -> { AdminConfig.instance.ticket_max_size } })
  validates(:response, length: { minimum: 2, maximum: -> { AdminConfig.instance.ticket_max_size } }, on: :update)
  validates(:report_type, presence: true)
  validate(:validate_model_type)
  validate(:validate_report_type)
  enum(:status, %i[pending partial approved rejected].index_with(&:to_s))
  after_create(:autoban_accused_user)
  after_update(:create_dmail)
  validate(:validate_model_exists, on: :create)
  validate(:validate_creator_is_not_limited, on: :create)

  scope(:automated, -> { for_creator(User.system) })
  scope(:spam, -> { automated.where(reason: "Spam.") })
  scope(:for_model, ->(type) { where(model_type: Array(type).map(&:to_s)) })
  scope(:active, -> { pending.or(partial) })
  scope(:claimed, -> { where.not(claimant_id: nil) })
  scope(:unclaimed, -> { where(claimant_id: nil) })

  attr_accessor(:record_type, :send_update_dmail)

  modactions(:ticket)
    .add(:update, :updater, on: :update, if: :saved_change_to_watched_attributes?)
    .add(:claim, :updater, on: :update, if: -> { saved_change_to_claimant_id? && claimant_id.present? }) { { user_id: claimant_id } }
    .add(:unclaim, :updater, on: :update, if: -> { saved_change_to_claimant_id? && claimant_id.blank? })

  def saved_change_to_watched_attributes?
    saved_change_to_response? || saved_change_to_status?
  end

  # Permissions Table
  #
  # |    Type    |      Can Create     |    Details Visible   |
  # |:----------:|:-------------------:|:--------------------:|
  # |   Artist   |         Any         |  Janitor+ / Creator  |
  # |   Comment  |       Visible       | Moderator+ / Creator |
  # |    Dmail   | Visible & Recipient | Moderator+ / Creator |
  # | Forum Post |       Visible       | Moderator+ / Creator |
  # |    Pool    |         Any         |  Janitor+ / Creator  |
  # |    Post    |         Any         |  Janitor+ / Creator  |
  # |  Post Set  |       Visible       | Moderator+ / Creator |
  # |     Tag    |         Any         |  Janitor+ / Creator  |
  # |    User    |         Any         |  *Janitor+ / Creator |
  # |  Wiki Page |         Any         |  Janitor+ / Creator  |
  # |    Other   |         None        | Moderator+ / Creator |
  #
  # * Janitor+ can see details if the creator is Janitor+ or the ticket is a commendation, else Moderator+

  # All procs are executed in context
  MODELS = {
    types:        %w[Artist Comment Dmail ForumPost Pool Post PostReplacement PostSet Tag User WikiPage],
    # If the ticket can be viewed
    view:         {
      Artist          => ->(user) { user.is_janitor? || user.is?(creator_id) },
      Comment         => ->(user) { user.is_moderator? || user.is?(creator_id) },
      Dmail           => ->(user) { user.is_moderator? || user.is?(creator_id) },
      ForumPost       => ->(user) { user.is_moderator? || user.is?(creator_id) },
      Pool            => ->(user) { user.is_janitor?  || user.is?(creator_id) },
      Post            => ->(user) { user.is_janitor?  || user.is?(creator_id) },
      PostReplacement => ->(user) { user.is_janitor?  || user.is?(creator_id) },
      PostSet         => ->(user) { user.is_moderator? || user.is?(creator_id) },
      Tag             => ->(user) { user.is_janitor? || user.is?(creator_id) },
      User            => ->(user) { user.is_moderator? || user.is?(creator_id) || (user.is_janitor? && (report_type == "commendation" || creator.is_janitor?)) },
      WikiPage        => ->(user) { user.is_janitor? || user.is?(creator_id) },
      :default        => ->(user) { user.is_moderator? || user.is?(creator_id) },
    },
    # If the ticket's reporter can be seen
    see_reporter: {
      default: ->(user) { user.is_moderator? || user.is?(creator_id) },
    },
    # If a ticket can be created for the model
    create:       {
      Dmail    => ->(user) { model&.visible?(user) && model.to_id == user.id },
      :default => ->(user) { model&.visible?(user) },
    },
    # The target name sent to the bot
    target:       {
      Artist          => -> { model&.name },
      Dmail           => -> { model&.from&.name },
      Pool            => -> { model&.name },
      Post            => -> { model&.uploader&.name },
      PostReplacement => -> { model&.creator&.name },
      PostSet         => -> { model&.name },
      Tag             => -> { model&.name },
      User            => -> { model&.name },
      WikiPage        => -> { model&.title },
      :default        => -> {},
    },
    accused:      {
      Comment         => -> { model.creator_id },
      Dmail           => -> { model.from_id },
      ForumPost       => -> { model.creator_id },
      PostReplacement => -> { model.creator_id },
      User            => -> { model_id },
      :default        => -> {},
    },
  }.freeze

  module ValidationMethods
    def validate_model_type
      return if MODELS[:types].include?(model_type)
      errors.add(:model_type, "is not valid")
    end

    def validate_report_type
      return if report_type == "report"
      return if report_type == "commendation" && model_type == "User"
      errors.add(:report_type, "is not valid")
    end

    def validate_creator_is_not_limited
      return if creator == User.system
      allowed = creator.can_ticket_with_reason
      if allowed != true
        errors.add(:creator, User.throttle_reason(allowed))
        return false
      end
      true
    end

    def validate_model_exists
      errors.add(:model, "does not exist") if model.nil?
    end

    def initialize_accused
      proc = MODELS[:accused].fetch(model.class, nil) || MODELS[:accused][:default]
      self.accused_id = instance_exec(&proc)
    end
  end

  module SearchMethods
    def creator_id_query(q, value, user)
      return none if !user.is_moderator? && value.to_i != user.id
      q.for_creator_id(value)
    end

    def creator_name_query(q, value, user)
      return none if !user.is_moderator? && value.downcase != user.name.downcase
      q.for_creator_name(value)
    end

    def status_query(q, value)
      case value
      when "pending_claimed"
        q.pending.claimed
      when "pending_unclaimed"
        q.pending.unclaimed
      else
        q.where(status: value)
      end
    end

    def default_order
      order(case_order(:status, ["pending", "partial", nil])).order(id: :desc)
    end

    def query_dsl
      super
        .field(:model_type)
        .field(:model_id)
        .field(:reason)
        .field(:ip_addr, :creator_ip_addr)
        .field(:handler_ip_addr)
        .custom(:status, method(:status_query).to_proc)
        .custom(:creator_id, method(:creator_id_query).to_proc)
        .custom(:creator_name, method(:creator_name_query).to_proc)
        # TODO: We need access control/blocks for associations
        .association(:creator)
        .association(:handler)
        .association(:claimant)
        .association(:accused)
    end
  end

  def report_type_pretty
    case report_type
    when "report"
      "reporting"
    when "commendation"
      "commending"
    else
      report_type
    end
  end

  def bot_target_name
    case model
    when Dmail
      model&.from_name
    when WikiPage
      model&.title
    when Pool, User
      model&.name
    when Post
      model&.uploader_name
    else
      model&.creator_name
    end
  end

  def can_see_reporter?(user)
    proc = MODELS[:see_reporter].fetch(model.class, nil) || MODELS[:see_reporter][:default]
    instance_exec(user, &proc)
  end

  def can_view?(user)
    proc = MODELS[:view].fetch(model.class, nil) || MODELS[:view][:default]
    instance_exec(user, &proc)
  end

  def can_create_for?(user)
    proc = MODELS[:create].fetch(model.class, nil) || MODELS[:create][:default]
    instance_exec(user, &proc)
  end

  def visible?(user)
    can_view?(user)
  end

  def type_title
    "#{model_type.titlecase} #{report_type.titlecase}"
  end

  def subject
    if reason.length > 40
      "#{reason[0, 38]}..."
    else
      reason
    end
  end

  def autoban_accused_user
    return if accused.blank?
    if SpamDetector.is_spammer?(accused)
      SpamDetector.ban_spammer!(accused)
    end
  end

  def open_duplicates
    Ticket.where(model: model, status: "pending")
  end

  def warnable?
    model.respond_to?(:user_warned!) && !model.was_warned? && pending?
  end

  def pretty_status
    if status == "partial"
      "Under Investigation"
    else
      status.titleize
    end
  end

  module ClaimMethods
    def claim!(user)
      transaction do
        update!(claimant: user, updater: user)
        push_pubsub("claim")
      end
    end

    def unclaim!(user)
      transaction do
        update!(claimant: nil, updater: user)
        push_pubsub("unclaim")
      end
    end
  end

  module NotificationMethods
    def create_dmail
      return if creator == User.system
      should_send = saved_change_to_status? || (send_update_dmail.to_s.truthy? && saved_change_to_response?)
      return unless should_send

      msg = <<~MSG.chomp
        "Your ticket":#{Rails.application.routes.url_helpers.ticket_path(self)} has been updated by #{handler.pretty_name}.
        Ticket Status: #{status}

        Response: #{response}
      MSG
      title = "Your ticket has been updated"
      if saved_change_to_status?
        if %w[approved rejected].include?(status)
          title = "Your ticket has been #{pretty_status.downcase}"
        else
          title += " to #{pretty_status.downcase}"
        end
      end
      Dmail.create_split!(
        from:          handler,
        to:            creator,
        title:         title,
        body:          msg,
        bypass_limits: true,
      )
    end
  end

  module PubSubMethods
    def pubsub_hash(action)
      {
        action: action,
        ticket: {
          id:          id,
          user_id:     creator_id,
          user_name:   creator_id ? User.id_to_name(creator_id) : nil,
          claimant:    claimant_id ? User.id_to_name(claimant_id) : nil,
          target:      bot_target_name,
          status:      status,
          model_id:    model_id,
          model_type:  model_type,
          report_type: report_type,
          reason:      reason,
        },
      }
    end

    def push_pubsub(action)
      # learned the hard way via receiving 25 pings during testing
      return if Rails.env.test?
      Cache.redis.publish("ticket_updates", pubsub_hash(action).to_json)
    end
  end

  include(ValidationMethods)
  include(ClaimMethods)
  include(NotificationMethods)
  include(PubSubMethods)
  extend(SearchMethods)
end

# frozen_string_literal: true

class TicketPolicy < ApplicationPolicy
  def index?
    member?
  end

  def show?
    member? && (!record.is_a?(Ticket) || record.can_view?(user))
  end

  def create?
    return false unless member?
    if record.is_a?(Ticket)
      record.can_create_for?(user)
    elsif record.is_a?(ApplicationRecord)
      Ticket.new(model: record).can_create_for?(user)
    else
      true
    end
  end

  def update?
    user.is_moderator?
  end

  def claim?
    user.is_moderator?
  end

  def unclaim?
    user.is_moderator?
  end

  def permitted_attributes_for_new
    %i[model_id model_type report_type]
  end

  def permitted_attributes_for_create
    %i[model_id model_type reason report_type]
  end

  def permitted_attributes_for_update
    %i[response status record_type send_update_dmail]
  end

  def permitted_search_params
    params = super + %i[model_id model_type status creator_id creator_name]
    params += %i[accused_name accused_id claimant_id claimant_name handler_id handler_name reason] + nested_search_params(creator: User, claimant: User, accused: User, handler: User) if user.is_moderator?
    params += %i[ip_addr handler_ip_addr] if can_search_ip_addr?
    params
  end

  def api_attributes
    attr = super
    attr -= %i[claimant_id] unless user.is_moderator?
    attr -= %i[creator_id] unless record.can_see_reporter?(user)
    attr
  end

  def html_data_attributes
    super + %i[status]
  end

  def visible_for_search(relation)
    q = super
    return q if user.is_moderator?
    qq = q.for_creator(user)
    qq = qq.or(q.for_model([Post, PostReplacement])) if user.is_janitor?
    qq
  end
end

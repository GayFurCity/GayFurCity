# frozen_string_literal: true

class TicketMessagePolicy < ApplicationPolicy
  def index?
    return false unless member?
    record.visible?(user)
  end

  def create?
    return false unless member?
    ticket = record.ticket
    ticket.visible?(user) && (user.is_moderator? || user.is?(ticket.creator_id))
  end

  def destroy?
    user.is_admin?
  end

  def permitted_attributes_for_create
    %i[body]
  end
end

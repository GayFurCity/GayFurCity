# frozen_string_literal: true

class LinkedAccountPolicy < ApplicationPolicy
  def edit?
    unbanned?
  end

  def destroy?
    record.user_id == user.id
  end
end

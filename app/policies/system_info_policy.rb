# frozen_string_literal: true

class SystemInfoPolicy < ApplicationPolicy
  def show?
    user.is_owner?
  end

  def dbsize?
    user.is_owner?
  end
end

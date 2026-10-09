# frozen_string_literal: true

class SiteAssetPolicy < ApplicationPolicy
  def index?
    user.is_owner?
  end

  def update?
    user.is_owner?
  end

  def destroy?
    user.is_owner?
  end

  def permitted_attributes
    %i[file]
  end
end

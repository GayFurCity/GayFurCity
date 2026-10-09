# frozen_string_literal: true

class DomainIconPolicy < ApplicationPolicy
  def create?
    user.is_admin?
  end

  def update?
    user.is_admin?
  end

  def destroy?
    user.is_admin?
  end

  def permitted_attributes
    %i[file domain aliases_string]
  end

  def permitted_search_params
    super + %i[domain domain_matches creator_id creator_name updater_id updater_name] + nested_search_params(creator: User, updater: User)
  end
end

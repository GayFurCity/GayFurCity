# frozen_string_literal: true

class CharacterVersionPolicy < ApplicationPolicy
  def permitted_search_params
    params = super + %i[updater_name updater_id character_name character_id order] + nested_search_params(updater: User)
    params += %i[ip_addr] if can_search_ip_addr?
    params
  end
end

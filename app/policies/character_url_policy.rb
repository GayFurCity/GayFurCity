# frozen_string_literal: true

class CharacterUrlPolicy < ApplicationPolicy
  def permitted_search_params
    super + %i[character_id character_name url url_matches normalized_url normalized_url_matches is_active order] + nested_search_params(character: Character)
  end
end

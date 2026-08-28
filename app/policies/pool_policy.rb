# frozen_string_literal: true

class PoolPolicy < ApplicationPolicy
  def gallery?
    index?
  end

  def destroy?
    user.is_janitor?
  end

  def revert?
    update?
  end

  def clear_indexing?
    user.is_admin?
  end

  def permitted_attributes
    [:name, :description, :is_ongoing, :category, :post_ids_string, { post_ids: [] }]
  end

  def permitted_search_params
    params = super + %i[name_matches description_matches any_artist_name_like any_artist_name_matches creator_id creator_name category is_ongoing is_indexing linked_to not_linked_to] + nested_search_params(creator: User)
    params << :ip_addr if can_search_ip_addr?
    params
  end

  def api_attributes
    super + %i[artist_names creator_name post_count]
  end
end

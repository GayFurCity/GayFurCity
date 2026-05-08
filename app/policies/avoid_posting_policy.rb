# frozen_string_literal: true

class AvoidPostingPolicy < ApplicationPolicy
  def create?
    user.can_edit_avoid_posting_entries?
  end

  def update?
    user.can_edit_avoid_posting_entries?
  end

  def destroy?
    user.can_edit_avoid_posting_entries?
  end

  def delete?
    user.can_edit_avoid_posting_entries?
  end

  def undelete?
    user.can_edit_avoid_posting_entries?
  end

  def permitted_attributes
    %i[details staff_notes is_active] + [{ artist_attributes: [:id, :name, :other_names_string, :linked_user_id, { other_names: [] }] }]
  end

  def permitted_search_params
    params = super + %i[creator_name creator_id updater_id updater_name any_name_matches artist_id artist_name any_other_name_matches details is_active] + nested_search_params(creator: User, updater: User, artist: Artist)
    params += %i[staff_notes] if user.is_staff?
    params += %i[ip_addr updater_ip_addr] if can_search_ip_addr?
    params
  end

  def api_attributes
    attr = super
    attr -= %i[staff_notes] unless user.is_janitor?
    attr
  end
end

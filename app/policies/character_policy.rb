# frozen_string_literal: true

class CharacterPolicy < ApplicationPolicy
  def show_or_new?
    show?
  end

  def update?
    member? && (!record.is_a?(Character) || !record.is_locked? || user.is_janitor?)
  end

  def destroy?
    user.is_admin?
  end

  def revert?
    member? && (!record.is_a?(Character) || !record.is_locked? || user.is_janitor?)
  end

  def permitted_attributes
    attr = %i[url_string notes cover_post_id cover_caption]
    attr << { custom_attributes: %i[name value] }
    attr += %i[owner_user_id is_locked] if user.is_janitor?
    attr
  end

  def permitted_attributes_for_create
    super + %i[name]
  end

  def permitted_attributes_for_update
    attr = super
    attr += %i[name] if user.is_janitor?
    attr
  end

  def permitted_search_params
    params = super + %i[name any_name_matches any_name_or_url_matches url_matches creator_id creator_name owner_user_id owner_user_name cover_post_id has_tag is_owned order] + nested_search_params(creator: User, owner_user: User)
    params << :ip_addr if can_search_ip_addr?
    params
  end
end

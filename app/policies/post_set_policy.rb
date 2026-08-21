# frozen_string_literal: true

class PostSetPolicy < ApplicationPolicy
  def create?
    unbanned?
  end

  def show?
    return true unless record.is_a?(PostSet)
    view_access?(record)
  end

  def edit?
    return unbanned? unless record.is_a?(PostSet)
    post_edit_access?(record)
  end

  def update?
    return unbanned? unless record.is_a?(PostSet)
    settings_edit_access?(record)
  end

  def maintainers?
    return unbanned? unless record.is_a?(PostSet)
    unbanned? && view_access?(record)
  end

  def post_list?
    return unbanned? unless record.is_a?(PostSet)
    post_edit_access?(record)
  end

  def update_posts?
    return unbanned? unless record.is_a?(PostSet)
    post_edit_access?(record)
  end

  def destroy?
    return true unless record.is_a?(PostSet)
    settings_edit_access?(record)
  end

  def for_select?
    unbanned?
  end

  def add_posts?
    return unbanned? unless record.is_a?(PostSet)
    post_edit_access?(record)
  end

  def remove_posts?
    return unbanned? unless record.is_a?(PostSet)
    post_edit_access?(record)
  end

  def add_maintainer?
    settings_edit_access?(record)
  end

  def permitted_attributes
    %i[name shortname description is_public transfer_on_delete]
  end

  def permitted_search_params
    params = super + %i[name shortname creator_id creator_name post_id maintainer_id] + nested_search_params(creator: User, updater: User)
    params << :is_public if user.is_moderator?
    params
  end

  private

  def settings_edit_access?(set)
    unbanned? && set.can_edit_settings?(user)
  end

  def post_edit_access?(set)
    unbanned? && set.can_edit_posts?(user)
  end

  def view_access?(set)
    set.can_view?(user)
  end
end

# frozen_string_literal: true

class DmailPolicy < ApplicationPolicy
  def index?
    unbanned?
  end

  def create?
    unbanned?
  end

  def show?
    unbanned? && (!record.is_a?(Dmail) || record.visible_to?(user))
  end

  def respond?
    unbanned? && (!record.is_a?(Dmail) || (record.visible_to?(user) && record.to_id == user.id))
  end

  def destroy?
    unbanned? && (!record.is_a?(Dmail) || record.involves?(user))
  end

  def mark_spam?
    user.is_moderator? && (!record.is_a?(Dmail) || record.visible_to?(user))
  end

  def mark_not_spam?
    user.is_moderator? && (!record.is_a?(Dmail) || record.visible_to?(user))
  end

  def mark_as_read?
    unbanned? && (!record.is_a?(Dmail) || record.to_id == user.id)
  end

  def mark_as_unread?
    unbanned? && (!record.is_a?(Dmail) || record.to_id == user.id)
  end

  def mark_all_as_read?
    unbanned?
  end

  def permitted_attributes
    %i[title body to_name to_id]
  end

  def permitted_search_params
    params = (super - %i[order]) + %i[title_matches message_matches to_name to_id from_name from_id is_read read] + nested_search_params(to: User, from: User)
    params << :is_spam if user.is_moderator?
    params << :ip_addr if can_search_ip_addr?
    params
  end

  # is_deleted_by_sender/is_deleted_by_recipient are per-party columns - see
  # Dmail#apionly_is_deleted? - so they're swapped out for a single computed is_deleted field
  # whenever the viewer is actually one of the two parties. A viewer who's neither (staff looking
  # in) gets both raw columns as-is, since there's no single "is_deleted" that would mean anything
  # to them.
  def api_attributes
    attr = super - %i[key] + %i[to_name from_name]
    if record.is_a?(Dmail) && (record.from_id == user.id || record.to_id == user.id)
      attr = attr - %i[is_deleted_by_sender is_deleted_by_recipient] + %i[apionly_is_deleted?]
    end
    attr
  end

  def html_data_attributes
    super + %i[apionly_is_recipient?]
  end

  def visible_for_search(relation)
    q = super
    return q if user.is_owner?
    q.involving(user)
  end
end

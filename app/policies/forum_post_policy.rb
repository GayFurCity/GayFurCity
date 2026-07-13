# frozen_string_literal: true

class ForumPostPolicy < ApplicationPolicy
  def show?
    min_level?
  end

  def new?
    unbanned? && min_level? && (!record.is_a?(ForumPost) || record.topic.blank? || record.topic.can_reply?(user))
  end

  def create?
    unbanned? && min_level? && (!record.is_a?(ForumPost) || (record.topic.present? && record.topic.can_reply?(user)))
  end

  def update?
    unbanned? && min_level? && (!record.is_a?(ForumPost) || record.editable_by?(user))
  end

  def destroy?
    unbanned? && min_level? && (!record.is_a?(ForumPost) || record.can_delete?(user))
  end

  def hide?
    unbanned? && min_level? && (!record.is_a?(ForumPost) || record.can_hide?(user))
  end

  def unhide?
    unbanned? && min_level? && user.is_moderator? && (!record.is_a?(ForumPost) || record.can_hide?(user))
  end

  def warning?
    unbanned? && min_level? && user.is_moderator?
  end

  def mark_spam?
    unbanned? && min_level? && user.is_moderator?
  end

  def mark_not_spam?
    unbanned? && min_level? && user.is_moderator?
  end

  def min_level?
    return true unless record.is_a?(ForumPost) && record.topic.present?
    return false unless record.topic.visible?(user)
    return false if record.topic.is_hidden? && !record.topic.can_hide?(user)
    return false if record.is_hidden? && !record.can_hide?(user)
    record.visible?(user)
  end

  def permitted_attributes
    %i[body]
  end

  def permitted_attributes_for_create
    super + %i[topic_id allow_voting]
  end

  def permitted_attributes_for_update
    attr = super
    attr += %i[allow_voting] if !record.is_a?(ForumPost) || (!record.is_aibur? && (user.is_admin? || !record.allow_voting?)) # Disallow users disabling voting
    attr
  end

  def permitted_search_params
    params = super + %i[creator_id creator_name updater_id updater_name topic_id topic_title_matches body_matches topic_category_id is_hidden linked_to not_linked_to] + nested_search_params(creator: User, topic: ForumTopic)
    params += %i[ip_addr updater_ip_addr] if can_search_ip_addr?
    params
  end

  def api_attributes
    super - %i[notified_mentions] + %i[mentions creator_name updater_name]
  end

  def html_data_attributes
    super + %i[topic]
  end

  def visible_for_search(relation)
    q = super
    q.active(user).permitted(user)
  end
end

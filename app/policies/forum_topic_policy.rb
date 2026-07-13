# frozen_string_literal: true

class ForumTopicPolicy < ApplicationPolicy
  def create?
    unbanned? && min_level? && (!record.is_a?(ForumTopic) || record.category.can_create_within?(user))
  end

  def show?
    min_level?
  end

  def update?
    unbanned? && min_level? && (!record.is_a?(ForumTopic) || record.editable_by?(user))
  end

  def destroy?
    unbanned? && min_level? && (!record.is_a?(ForumTopic) || record.can_delete?(user))
  end

  def hide?
    unbanned? && min_level? && (!record.is_a?(ForumTopic) || record.can_hide?(user))
  end

  def unhide?
    unbanned? && user.is_moderator? && min_level? && (!record.is_a?(ForumTopic) || record.can_hide?(user))
  end

  def lock?
    unbanned? && min_level? && user.is_moderator?
  end

  def unlock?
    unbanned? && min_level? && user.is_moderator?
  end

  def sticky?
    unbanned? && min_level? && user.is_moderator?
  end

  def unsticky?
    unbanned? && min_level? && user.is_moderator?
  end

  def subscribe?
    unbanned? && min_level?
  end

  def unsubscribe?
    unbanned? && min_level?
  end

  def mute?
    unbanned? && min_level?
  end

  def unmute?
    unbanned? && min_level?
  end

  def move?
    unbanned? && min_level? && user.is_moderator?
  end

  def mark_as_read?
    unbanned? && min_level?
  end

  def merge?
    unbanned? && min_level? && user.is_moderator?
  end

  def unmerge?
    unbanned? && min_level? && user.is_moderator?
  end

  def min_level?
    !record.is_a?(ForumTopic) || record.visible?(user)
  end

  def permitted_attributes
    opattr = %i[id body]
    opattr += %i[allow_voting] if !record.try(:original_post).is_a?(ForumPost) || (!record.original_post.is_aibur? && (user.is_admin? || !record.original_post.allow_voting?)) # Disallow users disabling voting
    attr = [:title, :category_id, { original_post_attributes: opattr }]
    attr += %i[is_sticky is_locked] if user.is_moderator?
    attr
  end

  def permitted_attributes_for_merge
    %i[target_topic_id]
  end

  def permitted_attributes_for_move
    %i[category_id]
  end

  def permitted_search_params
    params = super + %i[title title_matches category_id is_sticky is_locked is_hidden creator_id creator_name updater_id updater_name] + nested_search_params(creator: User, updater: User)
    params += %i[creator_ip_addr updater_ip_addr] if can_search_ip_addr?
    params
  end

  def api_attributes
    super + %i[creator_name updater_name]
  end

  def html_data_attributes
    super + [:is_read?, { category: %i[id name] }]
  end

  def visible_for_search(relation)
    q = super
    q = q.joins(:category).merge(ForumCategory.viewable(user))
    q = q.where("forum_topics.is_hidden": false).or(q.where("forum_topics.creator_id": user.id)) unless user.is_moderator?
    q
  end
end

# frozen_string_literal: true

class PostPolicy < ApplicationPolicy
  def show_seq?
    show?
  end

  def random?
    show?
  end

  def update?
    member? && min_level?
  end

  def update_iqdb?
    user.is_admin?
  end

  def expunge?
    user.is_approver? && user.is_admin?
  end

  def revert?
    member? && min_level?
  end

  def copy_notes?
    member?
  end

  def mark_as_translated?
    member? && min_level?
  end

  def regenerate_thumbnails?
    user.is_janitor?
  end

  def regenerate_videos?
    user.is_janitor?
  end

  def uploaders?
    user.is_janitor?
  end

  def destroy?
    user.is_approver?
  end

  def undelete?
    user.is_approver? && (!(!record.is_a?(Post) || record.is_taken_down?) || user.can_handle_takedowns?)
  end

  def move_favorites?
    user.is_approver?
  end

  def approve?
    user.is_approver?
  end

  def unapprove?
    user.is_approver?
  end

  def add_to_pool?
    member? && min_level?
  end

  def remove_from_pool?
    member? && min_level?
  end

  def favorites?
    unbanned?
  end

  def deleted?
    true
  end

  def ai_check?
    approver?
  end

  def change_locked_tags?
    user.is_admin?
  end

  def min_level?
    !record.is_a?(Post) || record.can_edit?(user)
  end

  def permitted_attributes_for_update
    attr = %i[
      tag_string old_tag_string
      tag_string_diff source_diff
      source old_source
      parent_id old_parent_id
      description old_description
      rating old_rating
      edit_reason
    ]
    attr += %i[is_rating_locked thumbnail_frame] if user.is_trusted?
    attr += %i[is_note_locked bg_color] if user.is_janitor?
    attr += %i[is_unlisted] if user.is_approver?
    attr += %i[is_comment_locked] if user.is_moderator?
    attr += %i[is_status_locked is_comment_disabled locked_tags hide_from_anonymous hide_from_search_engines min_edit_level] if user.is_admin?
    attr
  end

  # due to how internals work (inline editing), this is needed
  def permitted_attributes_for_show
    permitted_attributes_for_update
  end

  def permitted_attributes_for_mark_as_translated
    %i[translation_check partially_translated]
  end

  def permitted_search_params_for_uploaders
    permitted_search_params + %i[user_id user_name]
  end

  def api_attributes
    attr = super + %i[has_large apionly_has_visible_children children_ids pool_ids apionly_is_favorited? apionly_is_voted_up? apionly_is_voted_down?] - %i[pool_string fav_string vote_string]
    if record.visible?(user)
      attr += %i[apionly_file_url]
      attr += %i[apionly_large_file_url] if record.has_large?
      attr += %i[apionly_preview_file_url] if record.has_preview?
    else
      attr -= %i[md5 file_ext]
    end
    attr
  end
end

# frozen_string_literal: true

class UserPolicy < ApplicationPolicy
  def custom_style?
    unbanned?
  end

  def upload_limit?
    unbanned?
  end

  def me?
    unbanned?
  end

  def info?
    unbanned? && (!record.is_a?(User) || record.id == user.id || user.is_moderator?)
  end

  def unban?
    user.is_moderator?
  end

  def permitted_attributes
    %i[
      password old_password password_confirmation
      comment_threshold default_image_size favorite_tags blacklisted_tags
      time_zone per_page custom_style
    ] + User::Preferences.settable_list + [{ dmail_filter_attributes: %i[id words] }]
  end

  def permitted_attributes_for_create
    super + %i[name email]
  end

  def permitted_attributes_for_update
    attr = super + %i[enable_hover_zoom_form forum_unread_form] + [{ upload_notifications: [] }]
    attr += %i[profile_about profile_artinfo avatar_id] if unbanned? # Prevent editing when banned
    attr += %i[enable_compact_uploader] if record.post_active_count >= Config.instance.compact_uploader_minimum_posts
    attr
  end

  def permitted_search_params
    params = super + %i[name_matches about_me avatar_id level min_level max_level unrestricted_uploads can_upload_in_progress can_approve_posts can_manage_aibur]
    params += %i[ip_addr] if can_search_ip_addr?
    params += %i[email_matches] if user.is_admin?
    params
  end

  def api_attributes
    attr = %i[
      id created_at name level base_upload_limit
      post_upload_count post_update_count note_update_count
      level_string avatar_id wiki_page_version_count
      artist_version_count pool_version_count
      forum_post_count comment_count
      favorite_count positive_feedback_count
      positive_feedback_count neutral_feedback_count negative_feedback_count
      upload_limit profile_about profile_artinfo
    ] + User::Preferences.public_list

    if record.id == user.id
      attr += User::Preferences.private_list + %i[
        updated_at email last_logged_in_at
        recent_tags comment_threshold default_image_size
        favorite_tags blacklisted_tags time_zone per_page
        custom_style upload_notifications favorite_count followed_tags_list
        api_regen_multiplier api_burst_limit remaining_api_limit
        statement_timeout favorite_limit
        tag_query_limit has_mail?
      ]
    end
    attr
  end
end

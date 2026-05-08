# frozen_string_literal: true

class UploadPolicy < ApplicationPolicy
  def index?
    user.is_janitor?
  end

  def settings?
    create?
  end

  def permitted_attributes
    attr = %i[file direct_url source tag_string rating parent_id description checksum]
    attr += %i[as_pending] if user.unrestricted_uploads?
    attr += %i[locked_rating] if user.is_trusted?
    attr += %i[locked_tags] if user.is_admin?
    attr + [{ upload_media_asset_attributes: %i[checksum] }]
  end

  def permitted_search_params
    params = super + %i[uploader_id uploader_name source source_matches rating parent_id post_id has_post post_tags_match status backtrace tag_string] + nested_search_params(uploader: User)
    params << :ip_addr if can_search_ip_addr?
    params
  end

  def api_attributes
    super + %i[md5 file_ext file_size image_width image_height status status_message uploader_name media_asset_id] - %i[upload_media_asset_id]
  end
end

# frozen_string_literal: true

module Admin
  class UserPolicy < ApplicationPolicy
    def update?
      user.is_admin?
    end

    def alt_list?
      user.is_admin?
    end

    def edit_blacklist?
      update_blacklist?
    end

    def update_blacklist?
      user.is_admin?
    end

    def request_password_reset?
      password_reset?
    end

    def password_reset?
      user.is_owner?
    end

    def permitted_attributes
      attr = %i[name profile_about profile_artinfo base_upload_limit enable_privacy_mode unrestricted_uploads can_upload_in_progress can_approve_posts no_flagging no_replacements no_aibur_voting force_name_change]
      attr += %i[can_manage_aibur email email_verified age_verified title] if user.is_owner?
      attr += %i[level] if user.is_owner? || !record.is_admin?
      attr
    end
  end
end

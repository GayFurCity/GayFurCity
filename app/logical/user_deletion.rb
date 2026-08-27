# frozen_string_literal: true

class UserDeletion
  class ValidationError < StandardError
  end

  attr_reader(:user, :password, :request)

  def initialize(user, password, request)
    @user = user
    @password = password
    @request = request
  end

  def delete!
    validate
    create_name_history
    rename_user
    clear_user_settings
    reset_password
    create_mod_action
    create_user_event
    UserDeletionJob.perform_later(user.id)
  end

  private

  def create_name_history
    UserNameChangeRequest.create(desired_name: "user_#{user.id}", change_reason: "user deletion", status: "approved", approver: User.system, skip_limited_validation: true)
  end

  def create_mod_action
    ModAction.log!(user, :user_delete, user, user_id: user.id)
  end

  def create_user_event
    UserEvent.create_from_request!(user, :user_deletion, request)
  end

  def clear_user_settings
    user.update_columns(
      recent_tags:      "",
      favorite_tags:    "",
      blacklisted_tags: "",
      time_zone:        AdminConfig.instance.default_user_timezone,
      email:            "",
      avatar_id:        nil,
      profile_about:    "",
      profile_artinfo:  "",
      custom_style:     "",
      level:            User::Levels::MEMBER,
      mfa_secret:       nil,
      backup_codes:     [],
    )
  end

  def reset_password
    user.update_columns(password_hash: "", bcrypt_password_hash: "*LK*")
  end

  def rename_user
    name = "user_#{user.id}"
    n = 0
    name += "~" while User.exists?(name: name) && (n < 10)

    if n == 10
      raise(ValidationError, "New name could not be found")
    end

    user.update_column(:name, name)
    user.update_cache
  end

  def validate
    if user.is_banned?
      raise(ValidationError, "Banned users cannot delete their accounts")
    end

    if user.younger_than(1.week)
      raise(ValidationError, "Account must be one week old to be deleted")
    end

    unless User.authenticate(user.name, password)
      raise(ValidationError, "Password is incorrect")
    end

    if user.level >= User::Levels::ADMIN
      raise(ValidationError, "Admins cannot delete their account")
    end
  end
end

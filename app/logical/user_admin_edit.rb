# frozen_string_literal: true

class UserAdminEdit
  attr_reader(:user, :promoter, :ip_addr, :options)

  delegate(:errors, to: :user)

  PREFERENCES = [
    [:can_approve_posts, "approve posts", :is_admin?],
    [:unrestricted_uploads, "unrestricted uploads", :is_admin?],
    [:can_upload_in_progress, "upload in-progress posts", :is_admin?],
    [:no_flagging, "flagging ban", :is_admin?],
    [:no_replacements, "replacements ban", :is_admin?],
    [:no_aibur_voting, "tag change request voting ban", :is_admin?],
    [:can_manage_aibur, "manage tag change requests", :is_owner?],
    [:force_name_change, nil, :is_admin?],
    [:enable_privacy_mode, nil, :is_admin?],
    [:email_verified, nil, :is_owner?],
    [:age_verified, nil, :is_owner?],
  ].freeze

  def initialize(user, promoter, ip_addr, options)
    @user = user
    @promoter = promoter.resolvable(ip_addr)
    @ip_addr = ip_addr
    @options = options
  end

  def apply_preferences
    PREFERENCES.select { |p| promoter.send(p.third) }.map(&:first).each do |key|
      old = user.send("#{key}?")
      new = options[key].to_s.truthy?
      next if !options.key?(key) || old == new
      user.send("#{key}=", new)
    end
  end

  def apply_level
    new_level = options[:level].to_i
    return nil if !options.key?(:level) || user.level == new_level
    errors.add(:level, "Can't demote owner") if user.is_owner? && !promoter.is_owner?
    errors.add(:level, "Only owner can promote to admin") if new_level >= User::Levels::ADMIN && !promoter.is_owner?
    errors.add(:level, "Invalid level") unless User::VALID_LEVELS.include?(new_level)
    return nil if errors[:level].any?
    user.level = new_level
  end

  def apply_name
    return if !options.key?(:name) || user.name == options[:name]
    change_request = user.user_name_change_requests.create(
      original_name:           user.name,
      desired_name:            options[:name],
      change_reason:           "Administrative change",
      skip_limited_validation: true,
      creator:                 promoter,
    )
    if change_request.valid?
      change_request.approve!(promoter)
    else
      errors.add(:name, change_request.errors.full_messages.join("; "))
    end
  end

  def apply_misc
    attr = %i[profile_about profile_artinfo base_upload_limit]
    attr << :title if promoter.is_owner?
    attr.each do |key|
      next unless options.key?(key)
      user.send("#{key}=", options[key])
    end
  end

  def apply_email
    return unless promoter.is_owner?
    return if !options.key?(:email) || user.email == options[:email]
    user.email = options[:email]
    user.validate_email_format = true
  end

  def apply
    User.transaction do
      user.updater = promoter.resolvable(ip_addr)
      user.is_admin_edit = true
      apply_preferences
      apply_level
      apply_name
      apply_misc
      apply_email
      raise(ActiveRecord::Rollback) if invalid?

      user.save
    end
    valid?
  end

  def apply!
    apply
    raise(ActiveRecord::RecordInvalid, self) if invalid?
  end

  def valid?
    errors.blank?
  end

  def invalid?
    !valid?
  end
end

# frozen_string_literal: true

class User < ApplicationRecord
  class Error < StandardError; end
  class MFAError < StandardError; end

  class PrivilegeError < StandardError
    attr_accessor(:message)

    def initialize(msg = nil)
      @message = "Access Denied: #{msg}" if msg
    end
  end

  class PrivacyModeError < PrivilegeError
    def initialize(msg = "This user has privacy mode enabled")
      super
    end
  end

  module Levels
    ANONYMOUS    = 0
    BANNED       = 1
    REJECTED     = 4
    RESTRICTED   = 5
    MEMBER       = 10
    TRUSTED      = 15
    FORMER_STAFF = 19
    JANITOR      = 20
    MODERATOR    = 30
    SYSTEM       = 35
    ADMIN        = 40
    OWNER        = 50
    LOCKED       = 100 # intended to be a level above everyone else, used for raising restrictions above everyone

    def self.id_to_name(level)
      name = constants.find { |c| const_get(c) == level }.to_s.titleize
      return "Unknown: #{level}" if name.blank?
      name
    end

    def self.name_to_id(name)
      const_get(name.upcase)
    rescue NameError
      nil
    end

    def self.hash
      constants.to_h { |key| [key.to_s.titleize, const_get(key)] }.sort_by { |_name, level| level }.to_h
    end

    def self.staff_hash
      hash.select { |_name, level| level >= min_staff_level }
    end

    def self.min_staff_level
      JANITOR
    end

    def self.level_class(level)
      level = id_to_name(level) if level.is_a?(Integer)
      "user-#{level.downcase}"
    end

    def self.max_level
      # constants.map { |c| [c, User::Levels.const_get(c)] }.max_by(&:second)
      constants.map { |c| User::Levels.const_get(c) }.max
    end
  end

  # Used for `before_action :<role>_only`. Must have a corresponding `is_<role>?` method.
  Roles = Levels.constants.map(&:downcase) + %i[approver]
  VALID_LEVELS = (Levels.constants - %i[ANONYMOUS LOCKED]).map { |v| Levels.const_get(v) }.freeze

  module Preferences
    mattr_accessor(:settable, default: [])
    mattr_accessor(:private, default: [])
    mattr_accessor(:public, default: [])
    mattr_accessor(:anonymous, default: [])

    def self.pref(value, settable: true, private: true, public: false, anonymous: settable)
      self.settable << value if settable
      self.private << value if private
      self.public << value if public
      self.anonymous << value if anonymous
      value
    end

    DESCRIPTION_COLLAPSED_INITIALLY  = pref(1 << 0)
    HIDE_COMMENTS                    = pref(1 << 1)
    SHOW_HIDDEN_COMMENTS             = pref(1 << 2)
    RECEIVE_EMAIL_NOTIFICATIONS      = pref(1 << 3, anonymous: false)
    ENABLE_KEYBOARD_NAVIGATION       = pref(1 << 4)
    ENABLE_PRIVACY_MODE              = pref(1 << 5, anonymous: false)
    STYLE_USERNAMES                  = pref(1 << 6)
    ENABLE_AUTOCOMPLETE              = pref(1 << 7)
    CAN_APPROVE_POSTS                = pref(1 << 8, settable: false, public: true)
    UNRESTRICTED_UPLOADS             = pref(1 << 9, settable: false, public: true)
    DISABLE_CROPPED_THUMBNAILS       = pref(1 << 10)
    ENABLE_SAFE_MODE                 = pref(1 << 11)
    DISABLE_RESPONSIVE_MODE          = pref(1 << 12)
    NO_FLAGGING                      = pref(1 << 13, settable: false, private: false)
    DISABLE_USER_DMAILS              = pref(1 << 14, public: true, anonymous: false)
    ENABLE_COMPACT_UPLOADER          = pref(1 << 15, settable: false, anonymous: false)
    NO_REPLACEMENTS                  = pref(1 << 16, settable: false, private: false)
    MOVE_RELATED_THUMBNAILS          = pref(1 << 17)
    ENABLE_HOVER_ZOOM                = pref(1 << 18)
    HOVER_ZOOM_SHIFT                 = pref(1 << 19)
    HOVER_ZOOM_STICKY_SHIFT          = pref(1 << 20)
    HOVER_ZOOM_PLAY_AUDIO            = pref(1 << 21)
    CAN_MANAGE_AIBUR                 = pref(1 << 22, settable: false, public: true)
    FORCE_NAME_CHANGE                = pref(1 << 23, settable: false, private: false)
    SHOW_POST_UPLOADER               = pref(1 << 24)
    GO_TO_RECENT_FORUM_POST          = pref(1 << 25)
    DISABLE_COLORS                   = pref(1 << 26)
    NO_AIBUR_VOTING                  = pref(1 << 27, settable: false, private: false)
    EMAIL_VERIFIED                   = pref(1 << 28, settable: false, public: true)
    UNIQUE_VIEWS                     = pref(1 << 29)
    FORUM_UNREAD_BUBBLE              = pref(1 << 30, private: false)
    FORUM_UNREAD_ITALIC              = pref(1 << 31, private: false)
    AGE_VERIFIED                     = pref(1 << 32, settable: false, private: false)

    def self.map
      constants.to_h { |name| [name.to_s.downcase, const_get(name)] }
    end

    def self.list
      map.keys.map(&:to_sym)
    end

    def self.settable_list
      map.filter { |_name, value| settable.include?(value) }.keys.map(&:to_sym)
    end

    def self.private_list
      map.filter { |_name, value| private.include?(value) }.keys.map(&:to_sym)
    end

    def self.public_list
      map.filter { |_name, value| public.include?(value) }.keys.map(&:to_sym)
    end

    def self.anonymous_list
      map.filter { |_name, value| anonymous.include?(value) }.keys.map(&:to_sym)
    end

    def self.index(value)
      value = const_get(value) unless value.is_a?(Integer)
      Math.log2(value).to_i
    end

    def self.to_list(prefs)
      map.filter { |_name, value| prefs & value == value }.keys.map(&:to_sym)
    end
  end

  has_bit_flags(Preferences.map, field: "bit_prefs")

  def prefs_list
    Preferences.to_list(bit_prefs)
  end

  def age_verified_blame
    Cache.fetch("avb:#{id}", expires_in: 1.hour) do
      StaffAuditLog.where(action: :age_verified).where("(values->>'target_id')::integer = ?", id).order(id: :desc).first&.user
    end
  end

  attr_accessor(:password, :old_password, :validate_email_format, :is_admin_edit)

  after_initialize(:initialize_attributes, if: :new_record?)
  before_validation(:sanitize_upload_notifications, if: :will_save_change_to_upload_notifications?)

  validates(:email, presence: { if: :enable_email_verification? })
  validates(:email, uniqueness: { case_sensitive: false, if: :enable_email_verification? })
  validates(:email, format: { with: /\A.+@[^ ,;@]+\.[^ ,;@]+\z/, if: :enable_email_verification? })
  validates(:email, length: { maximum: 100 })
  validate(:validate_email_address_allowed, on: %i[create update], if: ->(rec) { (rec.new_record? && rec.email.present?) || (rec.email.present? && rec.email_changed?) })

  normalizes(:profile_about, :profile_artinfo, with: ->(value) { value.gsub("\r\n", "\n") })
  validates(:name, user_name: true, on: :create)
  validates(:default_image_size, inclusion: { in: %w[large fit fitv original] })
  validates(:per_page, inclusion: { in: -> { 1..Config.instance.max_per_page } })
  validates(:comment_threshold, presence: true)
  validates(:comment_threshold, numericality: { only_integer: true, less_than: 50_000, greater_than: -50_000 })
  validates(:password, length: { minimum: 6, maximum: 128, if: ->(rec) { rec.new_record? || rec.password.present? || rec.old_password.present? } }, unless: :is_system?)
  validates(:password, confirmation: true, unless: :is_system?)
  validates(:password_confirmation, presence: { if: ->(rec) { rec.new_record? || rec.old_password.present? } }, unless: :is_system?)
  validate(:validate_ip_addr_is_not_banned, on: :create)
  validate(:validate_sock_puppets, on: :create, if: -> { Config.instance.enable_sock_puppet_validation && !is_system? })
  validate(:validate_prefs, if: :will_save_change_to_bit_prefs?)
  before_validation(:normalize_blacklisted_tags, if: ->(rec) { rec.blacklisted_tags_changed? })
  before_validation(:staff_cant_disable_dmail)
  before_validation(:blank_out_nonexistent_avatars)
  validates(:blacklisted_tags, length: { maximum: -> { Config.instance.blacklisted_tags_max_size } })
  validates(:custom_style, length: { maximum: -> { Config.instance.custom_style_max_size } })
  validates(:profile_about, length: { maximum: -> { Config.instance.user_about_max_size } })
  validates(:profile_artinfo, length: { maximum: -> { Config.instance.user_about_max_size } })
  validates(:time_zone, inclusion: { in: ActiveSupport::TimeZone.all.map(&:name) })
  validates(:upload_notifications, inclusion: { in: -> { User.upload_notifications_options } })
  before_create(:promote_to_owner_if_first_user)
  before_create(:encrypt_password_on_create)
  # after_create :notify_sock_puppets
  after_create(:create_user_approval, if: ->(rec) { rec.is_restricted? })
  before_update(:encrypt_password_on_update)
  after_update(:log_update, if: :is_admin_edit)
  after_save(:update_cache)
  after_update(if: ->(rec) { rec.saved_change_to_profile_about? || rec.saved_change_to_profile_artinfo? || rec.saved_change_to_blacklisted_tags? }) do |rec|
    UserTextVersion.create_version(rec, updater || self)
  end
  resolvable(:updater)

  has_many(:api_keys, dependent: :destroy)
  has_one(:dmail_filter)
  has_many(:sent_dmails, ->(user) { owned_by(user) }, class_name: "Dmail", foreign_key: "from_id")
  has_many(:received_dmails, ->(user) { owned_by(user) }, class_name: "Dmail", foreign_key: "to_id")
  has_one(:recent_ban, -> { order("bans.id desc") }, class_name: "Ban")
  has_many(:bans, -> { order("bans.id desc") })
  has_many(:dmails, -> { order("dmails.id desc") }, foreign_key: "owner_id")
  has_many(:favorites, -> { order(id: :desc) })
  has_many(:feedback, class_name: "UserFeedback", dependent: :destroy)
  has_many(:comments, foreign_key: "creator_id")
  has_many(:forum_posts, -> { order("forum_posts.created_at, forum_posts.id") }, foreign_key: "creator_id")
  has_many(:forum_category_visits)
  has_many(:tickets, foreign_key: "creator_id")
  has_many(:note_versions, foreign_key: "updater_id")
  has_many(:posts, foreign_key: "uploader_id")
  has_many(:post_approvals, dependent: :destroy)
  has_many(:post_disapprovals, dependent: :destroy)
  has_many(:post_replacements, foreign_key: :creator_id)
  has_many(:post_sets, -> { order(name: :asc) }, foreign_key: :creator_id)
  has_many(:post_versions)
  has_many(:post_votes)
  has_many(:comment_votes)
  has_many(:forum_post_votes)
  has_many(:staff_notes, -> { active.order("staff_notes.id desc") })
  has_many(:user_name_change_requests, -> { order(id: :asc) })
  has_many(:text_versions, -> { order(id: :desc) }, class_name: "UserTextVersion")
  has_many(:artists, foreign_key: "linked_user_id")
  has_many(:blocks, class_name: "UserBlock")
  has_many(:followed_tags, class_name: "TagFollower")
  has_many(:notifications)
  has_many(:user_events)

  scope(:has_blacklisted_tag, ->(name) { where.regex(blacklisted_tags: "(^| )[~-]?#{Regexp.escape(name)}( |$)", flags: "ni") })
  scope(:email_verified, -> { where.has_bits(bit_prefs: Preferences::EMAIL_VERIFIED) })
  scope(:email_not_verified, -> { where.not_has_bits(bit_prefs: Preferences::EMAIL_VERIFIED) })

  belongs_to(:avatar, class_name: "Post", optional: true)
  accepts_nested_attributes_for(:dmail_filter)

  module AdminEditMethods
    def can_admin_edit?(user)
      # owners can edit anyone
      return true if user.is_owner?
      # no one else can edit admins
      return false if is_admin?
      # admins can edit anyone else
      user.is_admin?
    end

    def admin_edit(promoter, ip_addr, options)
      UserAdminEdit.new(self, promoter, ip_addr, options)
    end

    def admin_edit!(...)
      admin_edit(...).apply!
    end
  end

  module BanMethods
    def validate_ip_addr_is_not_banned
      if IpBan.is_banned?(CurrentUser.ip_addr) # rubocop:disable YiffSpace/CurrentUserOutsideOfRequests
        errors.add(:base, "IP address is banned")
        false
      end
    end

    def ban!(user)
      return false if is_banned?
      self.level = Levels::BANNED
      self.updater = user
      ModAction.log!(user, :user_ban, self, user_id: id)
      save(validate: false)
    end

    def unban!(user, ack: false)
      return false unless is_banned?
      self.level = Levels::MEMBER
      self.updater = user
      ModAction.log!(user, :user_unban, self, user_id: id) unless ack
      save(validate: false)
    end

    def ban_expired?
      is_banned? && recent_ban.try(:expired?)
    end
  end

  module NameMethods
    extend(ActiveSupport::Concern)

    module ClassMethods
      def name_to_id(name)
        normalized_name = normalize_name(name)
        Cache.fetch("uni:#{normalized_name}", expires_in: 4.hours) do
          User.where("lower(name) = ?", normalized_name).pick(:id)
        end
      end

      # @param arguments [Array<String, Array<String>>] a list of names
      # @return [Hash{String => Integer, nil}] a hash of normalized names to user IDs
      def bulk_name_to_id(*arguments)
        names = arguments.flatten.map { |n| normalize_name(n) }
        results = names.index_with { |name| Cache.fetch("uni:#{name}") }.compact_blank
        missing = names - results.keys
        fetched = User.where("lower(name) IN (?)", missing).select(:id, :name).to_h { |u| [normalize_name(u.name), u.id] }
        not_found = (missing - fetched.keys).index_with { nil }
        fetched.each { |name, id| Cache.write("uni:#{name}", id, expires_in: 4.hours) }
        { **results, **fetched, **not_found }
      end

      def name_or_id_to_id(name)
        if name =~ /\A!\d+\z/
          return name[1..].to_i
        end
        User.name_to_id(name)
      end

      def name_or_id_to_id_forced(name)
        if name =~ /\A\d+\z/
          return name.to_i
        end
        User.name_to_id(name)
      end

      def id_to_name(user_id)
        RequestStore[:id_name_cache] ||= {}
        if RequestStore[:id_name_cache].key?(user_id)
          return RequestStore[:id_name_cache][user_id]
        end
        name = Cache.fetch("uin:#{user_id}", expires_in: 4.hours) do
          User.where(id: user_id).pick(:name) || Config.instance.anonymous_user_name
        end
        RequestStore[:id_name_cache][user_id] = name
        name
      end

      def find_by_normalized_name(name)
        where("lower(name) = ?", normalize_name(name)).first
      end

      def find_by_normalized_name!(name)
        find_by_normalized_name(name) || raise(ActiveRecord::RecordNotFound)
      end

      def find_by_normalized_name_or_id(name)
        if name =~ /\A!\d+\z/
          where("id = ?", name[1..].to_i).first
        else
          find_by(name: name)
        end
      end

      def find_by_current_or_former_name(name)
        find_by_normalized_name(name) || find_by_former_name(name)
      end

      def find_by_current_or_former_name!(name)
        find_by_current_or_former_name(name) || raise(ActiveRecord::RecordNotFound)
      end

      def find_by_former_name(name)
        UserNameChangeRequest.where("lower(original_name) = ?", User.normalize_name(name)).includes(:user).order(id: :desc).first&.user
      end

      def find_by_former_name!(name)
        find_by_former_name(name) || raise(ActiveRecord::RecordNotFound)
      end

      def normalize_name(name)
        name.to_s.downcase.strip.tr(" ", "_").to_s
      end
    end

    def pretty_name
      name.gsub(/([^_])_+(?=[^_])/, "\\1 \\2")
    end

    def update_cache
      Cache.write("uin:#{id}", name, expires_in: 4.hours)
      Cache.write("uni:#{User.normalize_name(name)}", id, expires_in: 4.hours)
    end
  end

  module PasswordMethods
    def password_token
      # noinspection RubyArgCount
      Zlib.crc32(bcrypt_password_hash)
    end

    def bcrypt_password
      BCrypt::Password.new(bcrypt_password_hash)
    end

    def encrypt_password_on_create
      self.password_hash = ""
      self.bcrypt_password_hash = User.bcrypt(password)
    end

    def encrypt_password_on_update
      return if password.blank?
      return if old_password.blank?

      if bcrypt_password == old_password
        self.bcrypt_password_hash = User.bcrypt(password)
        true
      else
        errors.add(:old_password, "is incorrect")
        false
      end
    end

    def upgrade_password(pass)
      update_columns(password_hash: "", bcrypt_password_hash: User.bcrypt(pass))
    end
  end

  module AuthenticationMethods
    extend(ActiveSupport::Concern)

    module ClassMethods
      def authenticate(name, pass)
        user = find_by(name: name)
        if user&.bcrypt_password == pass
          user
        end
      end

      def bcrypt(pass)
        BCrypt::Password.create(pass)
      end
    end

    def authenticate_api_key(key)
      return false unless is_verified?
      api_key = api_keys.find_by(key: key)
      api_key.present? && ActiveSupport::SecurityUtils.secure_compare(api_key.key, key) && [self, api_key]
    end
  end

  module LevelMethods
    extend(ActiveSupport::Concern)

    Levels.constants.each do |constant|
      next if Levels.const_get(constant) < Levels::MEMBER

      define_method("is_#{constant.downcase}?") do
        level >= Levels.const_get(constant)
      end
    end

    module ClassMethods
      def anonymous
        @anonymous ||= begin
          user = User.new do |user|
            user.name = Config.instance.anonymous_user_name
            user.level = Levels::ANONYMOUS
            user.created_at = Time.now
            user.email = "anonymous@#{GayFurCity.config.domain}"
          end
          user.readonly!
          wrap_user(user.freeze)
        end
      end

      def system(update: true)
        @system ||= begin
          user = User.find_or_initialize_by(level: Levels::SYSTEM).tap do |user|
            user.email = "system@#{GayFurCity.config.domain}"
            user.name = Config.instance.system_user_name
            user.can_approve_posts    = true
            user.unrestricted_uploads = true
            user.email_verified       = true
          end
          user.save! if user.changed? && (user.new_record? || update)
          wrap_user(user)
        end
      end

      def owner
        @owner ||= wrap_user(User.find_by!(level: Levels::OWNER))
      end

      private

      def wrap_user(user)
        UserResolvable.new(user, "127.0.0.1")
      end
    end

    def promote_to_owner_if_first_user
      return if Rails.env.test?

      if !is_system? && !User.exists?(level: Levels::OWNER)
        self.level = Levels::OWNER
        self.created_at = 2.weeks.ago
        self.can_approve_posts = true
        self.unrestricted_uploads = true
        self.can_manage_aibur = true
      end
    end

    def level_string_was
      level_string(level_before_last_save)
    end

    def level_string(value = nil)
      User::Levels.id_to_name(value || level)
    end

    def level_string_pretty
      return level_string if title.blank?
      Helpers.tag.span(title, title: level_string)
    end

    def level_name
      Levels.level_name(level)
    end

    def is_anonymous?
      level == Levels::ANONYMOUS
    end

    def is_banned?
      level == Levels::BANNED
    end

    def is_rejected?
      level == Levels::REJECTED
    end

    def is_restricted?
      level == Levels::RESTRICTED
    end

    def is_system?
      level == Levels::SYSTEM
    end

    def is_pending?
      is_rejected? || is_restricted?
    end

    def is_staff?
      level >= Levels.min_staff_level
    end

    def is_approver?
      can_approve_posts?
    end

    def can_post_vote?
      policy_for(PostVote).create?
    end

    def can_post_downvote?
      can_post_vote? && older_than(3.days)
    end

    def can_favorite?
      policy_for(Favorite).create?
    end

    def can_comment_vote?
      policy_for(Comment).create?
    end

    def staff_cant_disable_dmail
      self.disable_user_dmails = false if is_janitor?
    end

    def level_css_class
      Levels.level_class(level)
    end

    def create_user_approval
      UserApproval.create!(user_id: id)
    end
  end

  module EmailMethods
    def is_verified?
      id.present? && email_verified?
    end

    def mark_unverified!(user)
      update!(email_verified: false, updater: user)
    end

    def mark_verified!(user)
      update!(email_verified: true, updater: user)
    end

    def enable_email_verification?
      # Allow admins to edit users with blank/duplicate emails
      return false if is_admin_edit && !email_changed?
      Config.instance.enable_email_verification? && validate_email_format
    end

    def validate_email_address_allowed
      if EmailBlacklist.is_banned?(email)
        errors.add(:base, "Email address may not be used")
        false
      end
    end
  end

  module BlacklistMethods
    extend(ActiveSupport::Concern)

    class_methods do
      def rewrite_blacklists!(old_name, new_name)
        has_blacklisted_tag(old_name).find_each do |user|
          user.with_lock do
            user.rewrite_blacklist(old_name, new_name)
            user.save!
          end
        end
      end
    end

    def rewrite_blacklist(old_name, new_name)
      blacklisted_tags.gsub!(/(?:^| )([-~])?#{Regexp.escape(old_name)}(?: |$)/i) { " #{$1}#{new_name} " }
    end

    def normalize_blacklisted_tags
      self.blacklisted_tags = TagAlias.to_aliased_query(blacklisted_tags, comments: true) if blacklisted_tags.present?
    end

    def is_blacklisting_user?(user)
      return false if blacklisted_tags.blank?
      bltags = blacklisted_tags.split("\n").map(&:downcase)
      strings = %W[user:#{user.name.downcase} user:!#{user.id} userid:#{user.id}]
      strings.any? { |str| bltags.include?(str) }
    end
  end

  module ForumMethods
    def is_forum_unread?
      return false unless is_member?
      last_post_created_at = ForumTopic.visible(self).unmuted(self).order(updated_at: :desc).pick(:last_post_created_at)
      max_last_read_at = forum_category_visits.maximum(:last_read_at)
      return false if last_post_created_at.nil?
      return true if max_last_read_at.nil?
      last_post_created_at > max_last_read_at
    end
  end

  module ThrottleMethods
    def throttle_reason(reason, timeframe = "hourly")
      reasons = {
        REJ_NEWBIE:  "can not yet perform this action. Account is too new",
        REJ_LIMITED: "have reached the #{timeframe} limit for this action",
      }
      reasons.fetch(reason, "unknown throttle reason, please report this as a bug")
    end

    def upload_reason_string(reason)
      reasons = {
        REJ_UPLOAD_HOURLY: "have reached your hourly upload limit",
        REJ_UPLOAD_EDIT:   "have no remaining tag edits available",
        REJ_UPLOAD_LIMIT:  "have reached your upload limit",
        REJ_UPLOAD_NEWBIE: "cannot upload during your first week",
      }
      reasons.fetch(reason, "unknown upload rejection reason")
    end
  end

  module MFAMethods
    MAX_BACKUP_CODES = 6
    # number of dash delimited sections
    BACKUP_CODE_PARTS = 2
    # length of each section
    BACKUP_CODE_SECTION_LENGTH = 4

    def mfa
      @mfa ||= MFA.new(mfa_secret, username: name, last_used_at: mfa_last_used_at) if mfa_secret.present?
    end

    def update_mfa_secret!(secret, request)
      with_lock do
        update!(mfa_secret: secret)
        remove_instance_variable(:@mfa) if instance_variable_defined?(:@mfa)

        if mfa_secret_before_last_save.nil?
          UserEvent.create_from_request!(self, :mfa_enable, request)
          regenerate_backup_codes!(request)
        elsif secret.nil?
          UserEvent.create_from_request!(self, :mfa_disable, request)
          update!(backup_codes: nil)
        else
          UserEvent.create_from_request!(self, :mfa_update, request)
        end
      end
    end

    def verify_backup_code(code)
      return false unless backup_codes.present? && backup_codes.include?(code)
      self.backup_codes -= [code]
      save!
    end

    def generate_backup_codes(max_codes: MAX_BACKUP_CODES, parts: BACKUP_CODE_PARTS, length: BACKUP_CODE_SECTION_LENGTH)
      max_codes.times.map { parts.times.map { SecureRandom.hex(length / 2) }.join("-") }
    end

    def regenerate_backup_codes!(request, max_codes: MAX_BACKUP_CODES, parts: BACKUP_CODE_PARTS, length: BACKUP_CODE_SECTION_LENGTH)
      with_lock do
        update!(backup_codes: generate_backup_codes(max_codes: max_codes, parts: parts, length: length))
        UserEvent.create_from_request!(self, :backup_codes_generate, request)
      end
    end
  end

  module LimitMethods
    def younger_than(duration)
      return false if GayFurCity.config.disable_age_checks?
      younger_than!(duration)
    end

    def younger_than!(duration)
      created_at > duration.ago
    end

    def older_than(duration)
      return true if GayFurCity.config.disable_age_checks?
      older_than!(duration)
    end

    def older_than!(duration)
      created_at < duration.ago
    end

    class Throttle
      include(ActiveModel::Serializers::JSON)

      attr_reader(:name, :limiter, :bypass, :newbie_duration, :level)

      def initialize(name, limiter, bypass, newbie_duration, level)
        @name = name
        @limiter = limiter
        @bypass = bypass
        @newbie_duration = newbie_duration
        @level = level
      end

      def bypass?(user)
        (bypass && (bypass.is_a?(Symbol) ? user.send(bypass) : user.instance_exec(&bypass))) || false
      end

      def newbie?(user)
        (newbie_duration && user.younger_than(newbie_duration)) || false
      end

      def limit(user)
        user.instance_exec(&limiter)
      end

      def limited?(user)
        limit(user) <= 0
      end

      def level?(user)
        level.is_a?(Range) ? level.include?(user.level) : (level.blank? || user.level == level)
      end

      def serializable_hash(*)
        %i[name newbie_duration level].index_with { |k| send(k) }
      end
    end

    cattr_accessor(:throttles, default: [])

    def self.create_user_throttle_detailed(name, limiter, bypass, newbie_duration, level)
      throttle = Throttle.new(name, limiter, bypass, newbie_duration, level)
      throttles << throttle
      define_method(:"#{name}_limit", -> { throttle.limit(self) })

      define_method(:"can_#{name}_with_reason") do
        return true if GayFurCity.config.disable_throttles? || throttle.bypass?(self)
        return :REJ_NEWBIE if throttle.newbie?(self)
        return :REJ_LIMITED if throttle.limited?(self)
        true
      end
    end

    def self.create_user_throttle(name, config, klass, method, column, newbie, window: 1.hour, level: Levels::MEMBER..)
      create_user_throttle_detailed(name, -> { Config.get(config) - klass.public_send(method, id).where.gt(column => window.ago).count }, -> { Config.bypass?(config, self) }, newbie, level)
    end

    def token_bucket
      @token_bucket ||= UserThrottle.new({ prefix: "thtl:", duration: 1.minute }, self)
    end

    def general_bypass_throttle?
      is_trusted?
    end

    create_user_throttle(:artist_edit, :artist_edit_limit, ArtistVersion, :for_updater, :updated_at, 3.days)
    create_user_throttle(:post_edit, :post_edit_limit, PostVersion, :for_updater, :updated_at, 3.days)
    create_user_throttle(:post_appeal, :post_appeal_limit, PostAppeal, :for_creator, :created_at, 3.days)
    create_user_throttle(:wiki_edit, :wiki_edit_limit, WikiPageVersion, :for_updater, :updated_at, 3.days)
    create_user_throttle(:pool, :pool_limit, Pool, :for_creator, :created_at, 3.days)
    create_user_throttle(:pool_edit, :pool_edit_limit, PoolVersion, :for_updater, :updated_at, 3.days)
    create_user_throttle(:note_edit, :note_edit_limit, NoteVersion, :for_updater, :updated_at, 3.days)
    create_user_throttle(:comment, :comment_limit, Comment, :for_creator, :created_at, 3.days)
    create_user_throttle(:forum_post, :comment_limit, ForumPost, :for_creator, :created_at, 3.days)
    create_user_throttle(:dmail_minute, :dmail_minute_limit, Dmail, :sent_by, :created_at, 3.days, window: 1.minute)
    create_user_throttle(:dmail, :dmail_hour_limit, Dmail, :sent_by, :created_at, 3.days)
    create_user_throttle(:dmail_day, :dmail_day_limit, Dmail, :sent_by, :created_at, 3.days, window: 1.day)
    # dmails sent by a user of the "restricted" level
    create_user_throttle(:dmail_restricted, :dmail_restricted_day_limit, Dmail, :sent_by, :created_at, nil, window: 1.day, level: Levels::RESTRICTED)
    create_user_throttle(:comment_vote, :comment_vote_limit, CommentVote, :for_user, :created_at, 3.days)
    create_user_throttle(:post_vote, :post_vote_limit, PostVote, :for_user, :created_at, nil, level: Levels::RESTRICTED..)
    create_user_throttle(:post_flag, :post_flag_limit, PostFlag, :for_creator, :created_at, 3.days)
    create_user_throttle(:ticket, :ticket_limit, Ticket, :for_creator, :created_at, 3.days)
    create_user_throttle(:forum_vote, :forum_vote_limit, ForumPostVote, :for_user, :created_at, 3.days)
    create_user_throttle_detailed(:pool_post_edit, -> { Config.instance.pool_post_edit_limit - PoolVersion.for_updater(id).where.gt(updated_at: 1.hour.ago).group(:pool_id).count(:pool_id).length },
                                  :general_bypass_throttle?, 3.days, Levels::MEMBER..)
    create_user_throttle_detailed(:suggest_tag, -> { Config.instance.tag_suggestion_limit - (TagAlias.for_creator(id).where.gt(created_at: 1.hour.ago).count + TagImplication.for_creator(id).where.gt(created_at: 1.hour.ago).count + BulkUpdateRequest.for_creator(id).where.gt(created_at: 1.hour.ago).count) },
                                  :is_janitor?, 3.days, Levels::MEMBER..)

    def can_remove_from_pools?
      is_staff? || (is_member? && older_than(3.days))
    end

    def can_discord?
      is_staff? || (is_member? && older_than(3.days))
    end

    def can_view_flagger?(flagger_id)
      is_staff? || flagger_id == id
    end

    def can_view_flagger_on_post?(flag)
      is_janitor? || flag.creator_id == id || flag.is_deletion
    end

    def can_replace?
      !no_replacements?
    end

    def can_view_staff_notes?
      is_staff?
    end

    def can_handle_takedowns?
      is_owner?
    end

    def can_edit_avoid_posting_entries?
      is_owner?
    end

    def can_revert_post_versions?
      is_member?
    end

    def can_upload_with_reason
      return true if is_owner?
      return :REJ_UPLOAD_HOURLY if hourly_upload_limit <= 0 && !GayFurCity.config.disable_throttles?
      return true if unrestricted_uploads? || is_admin?
      return :REJ_UPLOAD_NEWBIE if younger_than(3.days)
      return :REJ_UPLOAD_EDIT if !is_trusted? && post_edit_limit <= 0 && !GayFurCity.config.disable_throttles?
      return :REJ_UPLOAD_LIMIT if upload_limit <= 0 && !GayFurCity.config.disable_throttles?
      true
    end

    def hourly_upload_limit
      @hourly_upload_limit ||= begin
        post_count = posts.where(created_at: 1.hour.ago..).count
        replacement_count = can_approve_posts? ? 0 : post_replacements.where("created_at >= ? and status != ?", 1.hour.ago, "original").count
        Config.instance.hourly_upload_limit - post_count - replacement_count
      end
    end

    def upload_limit
      pieces = upload_limit_pieces
      base_upload_limit + (pieces[:approved] / 10) - (pieces[:deleted] / 4) - pieces[:pending]
    end

    def upload_limit_pieces
      @upload_limit_pieces ||= begin
        deleted_count = Post.deleted.for_uploader(id).count
        rejected_replacement_count = post_replacement_rejected_count
        replaced_penalize_count = own_post_replaced_penalize_count
        unapproved_count = Post.pending_or_flagged.for_uploader(id).count
        unapproved_replacements_count = post_replacements.pending.count
        approved_count = Post.for_uploader(id).where(is_flagged: false, is_deleted: false, is_pending: false).count

        {
          deleted:        deleted_count + replaced_penalize_count + rejected_replacement_count,
          deleted_ignore: own_post_replaced_count - replaced_penalize_count,
          approved:       approved_count,
          pending:        unapproved_count + unapproved_replacements_count,
        }.to_open_hash
      end
    end

    def uploaders_list_pieces
      @uploaders_list_pieces ||= {
        pending:              Post.pending.for_uploader(id).count,
        approved:             Post.for_uploader(id).where(is_flagged: false, is_deleted: false, is_pending: false).count,
        deleted:              Post.deleted.for_uploader(id).count,
        flagged:              Post.flagged.for_uploader(id).count,
        replaced:             own_post_replaced_count,
        replacement_pending:  post_replacements.pending.count,
        replacement_rejected: post_replacement_rejected_count,
        replacement_promoted: post_replacements.promoted.count,
      }
    end

    def post_upload_throttle
      @post_upload_throttle ||= is_trusted? ? hourly_upload_limit : [hourly_upload_limit, post_edit_limit].min
    end

    def tag_query_limit
      Config.instance.tag_query_limit
    end

    def favorite_limit
      100_000
    end

    def api_regen_multiplier
      1
    end

    def api_burst_limit
      # can make this many api calls at once before being bound by
      # api_regen_multiplier refilling your pool
      if is_former_staff?
        120
      elsif is_trusted?
        90
      else
        60
      end
    end

    def remaining_api_limit
      token_bucket.uncached_count
    end

    def statement_timeout
      if is_former_staff?
        9_000
      elsif is_trusted?
        6_000
      else
        3_000
      end
    end
  end

  module CountMethods
    def wiki_page_version_count
      wiki_update_count
    end

    def post_active_count
      post_upload_count - post_deleted_count
    end

    def post_upload_count
      post_count
    end

    def note_version_count
      note_update_count
    end

    def artist_version_count
      artist_update_count
    end

    def pool_version_count
      pool_update_count
    end

    def flag_count
      post_flag_count
    end

    def positive_feedback_count
      feedback.active.positive.count
    end

    def neutral_feedback_count
      feedback.active.neutral.count
    end

    def negative_feedback_count
      feedback.active.negative.count
    end

    def deleted_feedback_count
      feedback.deleted.count
    end

    def refresh_counts
      RefreshUserCountsJob.perform_later(self)
    end

    def refresh_counts!
      self.class.without_timeout do
        User.where(id: id).update_all(
          post_count:                       Post.for_uploader(id).count,
          post_deleted_count:               Post.for_uploader(id).deleted.count,
          post_update_count:                PostVersion.for_updater(id).count,
          post_flag_count:                  PostFlag.for_creator(id).count,
          favorite_count:                   Favorite.for_user(id).count,
          wiki_update_count:                WikiPageVersion.for_updater(id).count,
          note_update_count:                NoteVersion.for_updater(id).count,
          forum_post_count:                 ForumPost.for_creator(id).count,
          comment_count:                    Comment.for_creator(id).count,
          pool_update_count:                PoolVersion.for_updater(id).count,
          set_count:                        PostSet.owned_by(self).count,
          artist_update_count:              ArtistVersion.for_updater(id).count,
          own_post_replaced_count:          PostReplacement.for_uploader_on_approve(id).count,
          own_post_replaced_penalize_count: PostReplacement.penalized.for_uploader_on_approve(id).count,
          post_replacement_rejected_count:  post_replacements.rejected.count,
          ticket_count:                     Ticket.for_creator(id).count,
          post_vote_count:                  post_votes.count,
          comment_vote_count:               comment_votes.count,
          forum_post_vote_count:            forum_post_votes.count,
        )
      end
    end
  end

  module SearchMethods
    def admins
      where(level: Levels::ADMIN)
    end

    def with_email(email)
      if email.blank?
        none
      else
        where("lower(email) = lower(?)", email)
      end
    end

    def query_dsl
      super
        .field(:level)
        .field(:avatar_id)
        .field(:email_matches, :email, ilike: true)
        .field(:name_matches, :name, ilike: true, normalize: method(:normalize_name).to_proc)
        .field(:ip_addr, :last_ip_addr)
        .custom(:about_me, ->(q, v) { q.attribute_matches(:profile_about, v).or(q.attribute_matches(:profile_artinfo, v)) })
        .custom(:min_level, ->(q, v) { q.where.gteq(level: v) })
        .custom(:max_level, ->(q, v) { q.where.lteq(level: v) })
        .custom(:can_approve_posts, ->(q, v) { bitprefs_query(q, v, :can_approve_posts) })
        .custom(:unrestricted_uploads, ->(q, v) { bitprefs_query(q, v, :unrestricted_uploads) })
        .custom(:can_manage_aibur, ->(q, v) { bitprefs_query(q, v, :can_manage_aibur) })
    end

    def bitprefs_query(q, value, pref)
      include_bits = 0
      exclude_bits = 0

      bit = Preferences.const_get(pref.upcase)
      if value.to_s.truthy?
        include_bits |= bit
      elsif value.to_s.falsy?
        exclude_bits |= bit
      end

      q = q.where("(bit_prefs & :mask) = :mask", mask: include_bits) if include_bits > 0
      q = q.where("(bit_prefs & :mask) = 0", mask: exclude_bits) if exclude_bits > 0
      q
    end

    def apply_order(params)
      order_with({
        name:              { "users.name": :asc },
        post_upload_count: { "users.post_count": :desc },
        note_count:        { "users.note_update_count": :desc },
        post_update_count: { "users.post_update_count": :desc },
      }, params[:order])
    end
  end

  concerning(:SockPuppetMethods) do
    attr_writer(:validate_sock_puppets)

    def validate_sock_puppets
      return if @validate_sock_puppets == false

      if User.where(last_ip_addr: CurrentUser.ip_addr).exists?(["created_at > ?", 1.day.ago]) # rubocop:disable YiffSpace/CurrentUserOutsideOfRequests
        errors.add(:last_ip_addr, "was used recently for another account and cannot be reused for another day")
      end
    end
  end

  module BlockMethods
    def is_blocking?(target)
      blocks.exists?(target: target)
    end

    def block_for(target)
      blocks.find_by(target: target)
    end

    def is_blocking_comments_from?(target)
      is_blocking?(target) && block_for(target).hide_comments?
    end

    def is_blocking_forum_topics_from?(target)
      is_blocking?(target) && block_for(target).hide_forum_topics?
    end

    def is_blocking_forum_posts_from?(target)
      is_blocking?(target) && block_for(target).hide_forum_posts?
    end

    def is_blocking_messages_from?(target)
      is_blocking?(target) && block_for(target).disable_messages?
    end

    def is_suppressing_mentions_from?(target)
      is_blocking?(target) && block_for(target).suppress_mentions?
    end
  end

  module LogChanges
    def log_name_change(user)
      ModAction.log!(user, :user_name_change, self, user_id: id)
    end

    def log_update
      if saved_change_to_profile_about? || saved_change_to_profile_artinfo?
        ModAction.log!(updater, :user_text_change, self, user_id: id)
      end

      if saved_change_to_blacklisted_tags
        ModAction.log!(updater, :user_blacklist_change, self, user_id: id)
      end

      if saved_change_to_base_upload_limit?
        ModAction.log!(updater, :user_upload_limit_change, self, old_upload_limit: base_upload_limit_before_last_save, upload_limit: base_upload_limit, user_id: id)
      end

      if saved_change_to_title? && (title_was.strip != title.strip)
        StaffAuditLog.log!(updater, :user_title_change, target_id: id, title: title)
      end

      if saved_change_to_force_name_change? && force_name_change?
        StaffAuditLog.log!(updater, :force_name_change, target_id: id)
      end

      if saved_change_to_age_verified?
        StaffAuditLog.log!(updater, age_verified? ? :age_verified : :age_unverified, target_id: id)
      end

      if bit_prefs != bit_prefs_before_last_save
        added = []
        removed = []
        UserAdminEdit::PREFERENCES.select { |p| p.second.present? }.each do |key, name|
          next unless send("saved_change_to_#{key}?")
          if send(key)
            added << name
          else
            removed << name
          end
        end

        if added.any? || removed.any?
          ModAction.log!(updater, :user_flags_change, self, user_id: id, added: added, removed: removed)
        end
      end

      if saved_change_to_level?
        ModAction.log!(updater, :user_level_change, self, user_id: id, level: level_string, old_level: level_string_was)
      end

      log_name_change(updater) if saved_change_to_name?
    end
  end

  module FollowerMethods
    def tag_followed?(tag)
      tag = tag.name if tag.is_a?(Tag)
      if tag.to_s =~ /\A\d+\z/
        followed_tags.joins(:tag).exists?(tag: { id: tag })
      else
        followed_tags.joins(:tag).exists?(tag: { name: tag })
      end
    end

    def followed_tags_list
      followed_tags.map(&:tag_name)
    end
  end

  module NotificationMethods
    def has_unread_notifications?
      unread_notification_count > 0
    end
  end

  include(AdminEditMethods)
  include(BanMethods)
  include(NameMethods)
  include(PasswordMethods)
  include(AuthenticationMethods)
  include(LevelMethods)
  include(EmailMethods)
  include(BlacklistMethods)
  include(ForumMethods)
  include(LimitMethods)
  include(CountMethods)
  include(BlockMethods)
  include(LogChanges)
  include(FollowerMethods)
  include(NotificationMethods)
  include(MFAMethods)
  extend(SearchMethods)
  extend(ThrottleMethods)

  def set_per_page
    if per_page.nil?
      self.per_page = Config.instance.posts_per_page
    end

    true
  end

  def blank_out_nonexistent_avatars
    if avatar_id.present? && avatar.nil?
      self.avatar_id = nil
    end
  end

  def has_mail?
    unread_dmail_count > 0
  end

  def hide_favorites?(user)
    return false if user.is_moderator?
    return true if is_banned?
    enable_privacy_mode? && user.id != id
  end

  def hide_followed_tags?(user)
    return false if user.is_moderator?
    enable_privacy_mode? && user.id != id
  end

  def compact_uploader?
    post_upload_count >= 10 && enable_compact_uploader?
  end

  def enable_forum_unread?
    forum_unread_bubble? || forum_unread_italic?
  end

  def forum_unread_form
    return "bubble" if forum_unread_bubble?
    return "italic" if forum_unread_italic?
    false
  end

  def forum_unread_form=(val)
    if val == "bubble"
      self.forum_unread_bubble = true
      self.forum_unread_italic = false
    elsif val == "italic"
      self.forum_unread_bubble = false
      self.forum_unread_italic = true
    else
      self.forum_unread_bubble = false
      self.forum_unread_italic = false
    end
  end

  def enable_hover_zoom_shift?
    enable_hover_zoom? && hover_zoom_shift?
  end

  def enable_hover_zoom_form
    return false unless enable_hover_zoom?
    return "shift" if enable_hover_zoom_shift?
    true
  end

  def enable_hover_zoom_form=(value)
    if value == "shift"
      self.enable_hover_zoom = true
      self.hover_zoom_shift = true
    else
      self.enable_hover_zoom = value.to_s.truthy?
      self.hover_zoom_shift = false
    end
  end

  def initialize_attributes
    return if Rails.env.test?
    GayFurCity.config.customize_new_user(self)
  end

  def presenter(view = nil)
    @presenter ||= {}
    @presenter[view] ||= UserPresenter.new(self, view: view)
  end

  # Users with invalid names may be automatically renamed in the future.
  def name_error
    errors = UserNameValidator.validate(self)
    errors << "Forced change by administrator" if force_name_change?
    errors.join("; ").presence
  end

  def validate_prefs
    errors.add(:can_manage_aibur, %(Members cannot have the "Manage Tag Change Requests" permission)) if level == Levels::MEMBER && can_manage_aibur?
    errors.add(:no_aibur_voting, %(User cannot have both "Manage Tag Change Requests" & "No AIBUR Voting")) if can_manage_aibur? && no_aibur_voting?
  end

  def clear_favorites
    ClearUserFavoritesJob.perform_later(self)
  end

  def self.upload_notifications_options
    %w[post_delete post_undelete post_approve post_unapprove appeal_accept appeal_reject replacement_approve replacement_reject replacement_promote]
  end

  def notify_for_upload(model, type)
    return unless upload_notifications.include?(type.to_s)
    notifications.create!(category: type, data: { post_id: model.respond_to?(:post_id) ? model.post_id : nil, "#{model.class.name.underscore}_id": model.id }.compact_blank)
  end

  def sanitize_upload_notifications
    self.upload_notifications = upload_notifications.compact_blank.uniq
  end

  def resolvable(ip_addr = nil)
    UserResolvable.new(self, ip_addr || last_ip_addr || "127.0.0.1")
  end

  def resolve
    self
  end

  def is?(user_or_id)
    id == u2id(user_or_id)
  end

  def safe_mode?
    Config.instance.safe_mode? || enable_safe_mode?
  end

  def ==(other)
    return super if other.is_a?(User)
    other.is_a?(UserResolvable) && super(other.user)
  end

  def ===(other)
    other == UserLike || super
  end

  def is_a?(other)
    other == UserLike || super
  end

  def policy_for(record)
    Pundit.policy!(self, record)
  end

  def self.available_includes
    %i[artists bans feedback]
  end
end

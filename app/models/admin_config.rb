# frozen_string_literal: true

class AdminConfig < ApplicationRecord
  self.table_name = "admin_config"
  validate(:validate_singleton_instance, on: :create)
  before_update(:log_update)
  after_update(-> { AdminConfig.delete_cache })
  resolvable(:updater)

  def validate_singleton_instance
    errors.add(:base, "Only one config record per instance is allowed") if AdminConfig.exists?(id: AdminConfig.config_id)
  end

  def log_update
    data = changes
    data.delete("updated_at")
    return if data.empty?
    log = StaffAuditLog.log!(updater, :config_update, data: data)
    if log.errors.any?
      Rails.logger.debug(log.errors.full_messages.inspect)
    end
  end

  def self.bypass?(option, user)
    return false unless column_names.include?("#{option}_bypass")
    user.level >= instance.public_send("#{option}_bypass")
  end

  def self.get(option)
    v = instance.public_send(option)
    return Float::INFINITY if v == -1
    return v.with_open_access if v.is_a?(Hash)
    v
  end

  # Admin config options are normally edited through the admin UI and stored in the `admin_config`
  # table, but any of them can be pinned to a fixed value via GAYFURCITY_ADMIN_CONFIG_<NAME>
  # (e.g. GAYFURCITY_ADMIN_CONFIG_ENABLE_SIGNUPS=false). A pinned option always wins over the
  # stored value and can no longer be edited in the UI - see settable_columns.
  def self.env_override_name(column)
    "#{GayFurCity::Config.env_name}_ADMIN_CONFIG_#{column.to_s.upcase}"
  end

  def self.env_override?(column)
    return false if %w[id updated_at].include?(column.to_s)
    ENV.key?(env_override_name(column))
  end

  def self.env_override(column)
    cast_env_value(column, ENV.fetch(env_override_name(column)))
  end

  def self.cast_env_value(column, raw)
    case columns_hash[column.to_s]&.type
    when :integer
      raw.to_i
    when :boolean
      raw.truthy?
    when :jsonb, :json
      JSON.parse(raw)
    else
      raw
    end
  end

  def self.env_overridden_columns
    column_names.select { |c| env_override?(c) }
  end

  def self.get_user(option, user)
    value = get(option)
    return nil if value.blank?
    return value unless value.is_a?(Hash)
    v = value.transform_keys(&:to_i).select { |k,| k <= user.level }.max_by(&:first)&.second
    v = 0 unless v.is_a?(Numeric) # jsonb has no schema - guard against a corrupt/non-numeric stored value
    return Float::INFINITY if v == -1
    v
  end

  def self.user?(option, user)
    value = get(option)
    return false if value.blank?
    user&.level.to_i >= value
  end

  def self.get_with_bypass(option, user)
    return Float::INFINITY if bypass?(option, user)
    get_user(option, user)
  end

  def self.instance
    Cache.fetch("admin_config:#{config_id}") do
      uncached
    end
  end

  def self.hash_columns
    Cache.fetch("admin_config:hash_columns") do
      columns_hash.select { |_k, v| %i[json jsonb].include?(v.type) }.keys
    end
  end

  def self.values_for_hash_column(name)
    column_defaults[name.to_s].keys
  end

  # we technically could have a desync between model and hash columns, but I don't think that's
  # a big enough issue to care about
  def self.uncached
    find_or_create_by!(id: config_id)
  end

  def self.delete_cache
    Cache.delete("admin_config:#{config_id}")
    Cache.delete("admin_config:hash_columns")
  end

  def self.config_id
    GayFurCity.config.config_id
  end

  def self.settable_columns(_user)
    excluded = %w[id updated_at] + disabled_config_options + env_overridden_columns
    columns.reject { |c| excluded.include?(c.name) }
  end

  def self.disabled_config_options
    list = GayFurCity.config.disabled_config_options
    list.each do |name|
      list << "#{name}_bypass" if column_names.include?("#{name}_bypass")
    end
    list
  end

  def self.usable?(user, attribute)
    settable_columns(user).map(&:name).include?(attribute.to_s) && policy(user).update? && policy(user).can_use_attribute?(attribute.to_sym, :update)
  end

  def self.has_bypass?(attribute)
    column_names.include?("#{attribute}_bypass")
  end

  def self.show_backtrace?(user)
    return true if Rails.env.development?
    value = get(:show_backtrace)
    value <= user&.level.to_i
  end

  def usable?(...)
    AdminConfig.usable?(...)
  end

  def ary(key)
    public_send(key).split(",").map(&:strip)
  end

  def safe_app_name
    app_name.gsub(/[^a-zA-Z0-9_-]/, "_")
  end

  def system_user_name=(value)
    User.system(update: false).admin_edit!(updater, updater_ip_addr, name: value) if updater.present?
    super
  end

  column_names.each do |column|
    # Every read of a config value (instance readers, the AdminConfig.foo/foo? class delegates
    # below, and get/get_user/bypass? above, which all funnel through instance.public_send) needs
    # to see the env override transparently, so it's applied here at the lowest level rather than
    # in each of those call sites individually.
    unless %w[id updated_at].include?(column)
      define_method(column) do
        next self.class.env_override(column) if self.class.env_override?(column)
        super()
      end
    end
    define_method("#{column}?") { !!public_send(column) } unless method_defined?(:"#{column}?")
    define_singleton_method(column) { get(column) } unless singleton_methods.include?(column)
    define_singleton_method("#{column}?") { !!public_send(column) } unless singleton_methods.include?(:"#{column}?")
  end

  class << self
    delegate(:safe_app_name, :ary, to: :instance)
  end
end

# frozen_string_literal: true

class Config < ApplicationRecord
  self.table_name = "config"
  validate(:singleton_instance, on: :create)
  before_update(:log_update)
  after_update(-> { Config.delete_cache })
  resolvable(:updater)

  def singleton_instance
    errors.add(:base, "Only one config record per instance is allowed") if Config.exists?(id: Config.config_id)
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
    Cache.fetch("config:#{config_id}") do
      uncached
    end
  end

  def self.hash_columns
    Cache.fetch("config:hash_columns") do
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
    Cache.delete("config:#{config_id}")
    Cache.delete("config:hash_columns")
  end

  def self.config_id
    GayFurCity.config.config_id
  end

  def self.settable_columns(_user)
    columns.reject { |c| (%w[id updated_at] + disabled_config_options).include?(c.name) }
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
    Config.usable?(...)
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
    define_method("#{column}?") { !!public_send(column) } unless method_defined?(:"#{column}?")
    define_singleton_method(column) { get(column) } unless singleton_methods.include?(column)
    define_singleton_method("#{column}?") { !!public_send(column) } unless singleton_methods.include?(:"#{column}?")
  end

  class << self
    delegate(:safe_app_name, :ary, to: :instance)
  end
end

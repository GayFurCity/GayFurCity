# frozen_string_literal: true

class CurrentUser < ActiveSupport::CurrentAttributes
  attribute(:user, default: -> { User.anonymous })
  attribute(:ip_addr, default: "127.0.0.1")
  attribute(:request)
  attribute(:safe_mode, default: -> { Config.instance.safe_mode? })

  alias safe_mode? safe_mode
  delegate(:id, to: :user, allow_nil: true)
  delegate_missing_to(:user, allow_nil: true)

  def safe_mode=(value)
    value = true if Config.instance.safe_mode?
    super
  end

  def user
    value = super
    return value if value.is_a?(UserResolvable) || !value.is_a?(User)
    return UserResolvable.new(value, ip_addr) if ip_addr.present?
    value
  end

  def user=(value)
    if value.is_a?(UserResolvable)
      self.ip_addr = value.ip_addr
      value = value.user
    end
    super
  end

  def self.scoped(user, ip_addr = "127.0.0.1", &)
    set(user: user, ip_addr: ip_addr, &)
  end

  def self.as_system(&)
    scoped(::User.system, &)
  end
end

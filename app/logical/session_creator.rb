# frozen_string_literal: true

class SessionCreator
  class AuthTypeError < StandardError; end
  AUTH_TYPES = %w[login reauthenticate].freeze
  attr_reader(:session, :cookies, :name, :password, :ip_addr, :remember, :secure, :request)

  def initialize(session, cookies, name, password, ip_addr, request, remember: false, secure: false)
    @session = session
    @cookies = cookies
    @name = name
    @password = password
    @ip_addr = ip_addr
    @remember = remember
    @secure = secure
    @request = request
  end

  def authenticate(type = :login)
    raise(AuthTypeError, "Invalid authentication type: #{type}") unless AUTH_TYPES.include?(type.to_s)
    user = User.find_by_normalized_name(name)
    if User.authenticate(name, password)
      process_login(user, type)
      user
    else
      UserEvent.create_from_request!(user, :"failed_#{type}", request) if user.present?
      nil
    end
  end

  def verify_mfa(user, code, type = :login)
    raise(AuthTypeError, "Invalid authentication type: #{type}") unless AUTH_TYPES.include?(type.to_s)
    if user.mfa.verify(code)
      process_login(user, type, mfa: true)
      user
    elsif user.verify_backup_code(code)
      process_login(user, type, mfa: true, backup: true)
      user
    else
      UserEvent.create_from_request!(user, :"mfa_failed_#{type}", request)
      nil
    end
  end

  def process_login(user, type = :login, mfa: false, backup: false)
    raise(AuthTypeError, "Invalid authentication type: #{type}") unless AUTH_TYPES.include?(type.to_s)
    update = { last_ip_addr: ip_addr, last_logged_in_at: Time.now }
    if user.is_banned?
      UserEvent.create_from_request!(user, :banned_login, request)
    else
      if mfa
        update[:mfa_last_used_at] = Time.now
        UserEvent.create_from_request!(user, :"#{backup ? 'backup_code' : 'mfa'}_#{type}", request)
      elsif user.mfa.present?
        UserEvent.create_from_request!(user, :"mfa_#{type}_pending_verification", request)
        return
      else
        UserEvent.create_from_request!(user, type, request)
      end
      user.update_columns(**update)
    end
    session[:user_id] = user.id
    session[:last_authenticated_at] = Time.now.utc.to_s
    session[:ph] = user.password_token

    if remember
      verifier = ActiveSupport::MessageVerifier.new(GayFurCity.config.remember_key, serializer: JSON, digest: "SHA256")
      cookies.encrypted[:remember] = { value: verifier.generate("#{user.id}:#{user.password_token}", purpose: "rbr", expires_in: 14.days), expires: Time.now + 14.days, httponly: true, same_site: :lax, secure: Rails.env.production? }
    end
  end
end

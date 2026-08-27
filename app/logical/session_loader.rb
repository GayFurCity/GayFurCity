# frozen_string_literal: true

require("base64")

class SessionLoader
  class AuthenticationFailure < StandardError; end

  class BannedError < AuthenticationFailure
    attr_reader(:ban)

    def initialize(ban)
      if ban.blank? || ban.expires_at.blank?
        super("Account is permanently banned")
      else
        super("Account is banned for #{ban.expire_days}")
      end
      @ban = ban
    end
  end

  attr_reader(:session, :cookies, :request, :params)

  def initialize(request)
    @request = request
    @session = request.session
    @cookies = request.cookie_jar
    @params = request.parameters
    @remember_validator = ActiveSupport::MessageVerifier.new(GayFurCity.config.remember_key, serializer: JSON, digest: "SHA256")
  end

  def load
    CurrentUser.user = User.anonymous
    CurrentUser.ip_addr = request.remote_ip

    if has_api_authentication?
      load_session_for_api
    elsif session[:user_id]
      load_session_user
    elsif has_remember_token?
      load_remember_token
    end

    if CurrentUser.user.is_banned?
      raise(BannedError, CurrentUser.user.recent_ban)
    end
    set_statement_timeout
    update_last_logged_in_at
    update_last_ip_addr
    set_time_zone
    set_safe_mode
    refresh_old_remember_token
    GayFurCity::Logger.initialize(CurrentUser.user)
  end

  def has_api_authentication?
    request.authorization.present? || params[:login].present? || (params[:api_key].present? && params[:api_key].is_a?(String))
  end

  def has_remember_token?
    cookies.encrypted[:remember].present?
  end

  private

  def set_statement_timeout
    timeout = CurrentUser.user.statement_timeout
    timeout = 0 unless timeout.is_a?(Numeric) && timeout.finite? # Postgres: 0 means "no timeout", not Infinity
    ActiveRecord::Base.connection.execute("set statement_timeout = #{timeout.to_i}")
  end

  def load_remember_token
    message = @remember_validator.verify(cookies.encrypted[:remember], purpose: "rbr")
    return if message.nil?
    pieces = message.split(":")
    return unless pieces.length == 2
    user = User.find_by(id: pieces[0].to_i)
    return unless user
    return if pieces[1].to_i != user.password_token
    CurrentUser.user = user
    session[:user_id] = user.id
    session[:ph] = user.password_token # This has been validated by the remember token
  rescue StandardError
    nil
  end

  def refresh_old_remember_token
    if cookies.encrypted[:remember] && !CurrentUser.user.is_anonymous?
      cookies.encrypted[:remember] = { value: @remember_validator.generate("#{CurrentUser.user.id}:#{CurrentUser.password_token}", purpose: "rbr", expires_in: 14.days), expires: Time.now + 14.days, httponly: true, same_site: :lax, secure: Rails.env.production? }
    end
  end

  def load_session_for_api
    if request.authorization
      authenticate_basic_auth
    elsif params[:login].present? && params[:api_key].present?
      authenticate_api_key(params[:login], params[:api_key])
    else
      raise(AuthenticationFailure)
    end
  end

  def authenticate_basic_auth
    credentials = ::Base64.decode64(request.authorization.split(" ", 2).last || "")
    login, api_key = credentials.split(":", 2)
    authenticate_api_key(login, api_key)
  end

  def authenticate_api_key(name, key)
    user, api_key = User.find_by_normalized_name(name)&.authenticate_api_key(key)
    raise(AuthenticationFailure, "Invalid API key") if user.blank?
    update_api_key(api_key)
    raise(User::PrivilegeError) unless api_key.has_permission?(request.remote_ip, request.params[:controller], request.params[:action])
    CurrentUser.user = user
  end

  def load_session_user
    user = User.find_by(id: session[:user_id])
    raise(AuthenticationFailure) if user.nil?
    return if session[:ph] != user.password_token
    CurrentUser.user = user
  end

  def update_last_logged_in_at
    return if CurrentUser.user.is_anonymous?
    return if CurrentUser.last_logged_in_at && CurrentUser.last_logged_in_at > 1.week.ago
    CurrentUser.user.update_attribute(:last_logged_in_at, Time.now)
  end

  def update_last_ip_addr
    return if CurrentUser.user.is_anonymous?
    return if CurrentUser.user.last_ip_addr == request.remote_ip
    CurrentUser.user.update_attribute(:last_ip_addr, request.remote_ip)
  end

  def update_api_key(api_key)
    api_key.increment!(:uses, touch: :last_used_at)
    api_key.update!(last_ip_address: request.remote_ip)
    Reports.log_api_key_usage(api_key.id, request.params[:controller], request.params[:action], request.request_method, request.fullpath, request.remote_ip)
  end

  def set_time_zone
    Time.zone = CurrentUser.user.time_zone
  end

  def set_safe_mode
    safe_mode = AdminConfig.instance.safe_mode? || params[:safe_mode].to_s.truthy? || CurrentUser.user.enable_safe_mode?
    CurrentUser.safe_mode = safe_mode
  end
end

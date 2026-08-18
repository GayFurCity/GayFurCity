# frozen_string_literal: true

require("timeout")

class ApplicationController < ActionController::Base
  class APIThrottled < StandardError; end
  class FeatureUnavailable < StandardError; end
  class RequestTimeoutError < StandardError; end

  skip_forgery_protection(if: -> { SessionLoader.new(request).has_api_authentication? || request.options? })
  before_action(:reset_current_user)
  before_action(:set_current_user)
  # Registered after set_current_user (so CurrentUser is resolved) but before everything else, so
  # it wraps the rest of the before_actions, the action itself, and rendering - the parts the
  # per-query timeouts (Postgres statement_timeout, the Elasticsearch client's request_timeout)
  # don't cover, e.g. a slow view or a runaway Ruby-level loop.
  around_action(:enforce_request_cycle_timeout)
  before_action(:normalize_search)
  before_action(:api_check)
  before_action(:enable_cors)
  before_action(:check_valid_username)
  after_action(:reset_current_user)
  layout("default")

  self.responder = ApplicationResponder

  include(TitleHelper)
  include(DeferredPosts)
  include(Pundit::Authorization)

  helper_method(:deferred_post_ids, :deferred_posts, :search_params, :can_use_attribute?, :can_use_attributes?, :can_use_any_attribute?)

  rescue_from(Exception, with: :rescue_exception)

  # This is raised on requests to `/blah.js`. Rails has already rendered StaticController#not_found
  # here, so calling `rescue_exception` would cause a double render error.
  rescue_from(ActionController::InvalidCrossOriginRequest, with: -> {})

  def enable_cors
    response.headers["Access-Control-Allow-Origin"] = "*"
    response.headers["Access-Control-Allow-Headers"] = "Authorization"
    response.headers["Access-Control-Allow-Methods"] = "GET, HEAD, POST, PATCH, PUT, DELETE, OPTIONS"
  end

  def check_valid_username
    return if params[:controller] == "users/name_change_requests"

    if request.format.html? && CurrentUser.user.name_error
      redirect_to(new_user_name_change_request_path)
    end
  end

  protected

  def api_check
    if !CurrentUser.user.is_anonymous? && !request.get? && !request.head?
      throttled = CurrentUser.user.token_bucket.throttled?
      headers["X-Api-Limit"] = CurrentUser.user.token_bucket.cached_count.to_s
      raise(APIThrottled) if throttled
    end

    true
  end

  def rescue_exception(exception)
    @exception = exception

    # If InvalidAuthenticityToken was raised, CurrentUser isn't set so we have to do it here manually.
    CurrentUser.user ||= User.anonymous

    case exception
    when PostReplacement::ProcessingError
      render_expected_error(400, exception)
    when APIThrottled
      render_expected_error(429, "Throttled: Too many requests")
    when ActiveRecord::QueryCanceled
      render_error_page(500, exception, message: "The database timed out running your query.")
    when ActionController::BadRequest, PostVersion::UndoError, Undoable::UndoError
      render_error_page(400, exception)
    when SessionLoader::AuthenticationFailure
      session.delete(:user_id)
      cookies.delete(:remember)
      status = 401
      if exception.is_a?(SessionLoader::BannedError)
        status = 403
        if request.format.json?
          return render(json: {
            success: false,
            message: exception.message,
            code:    nil,
            ban:     exception.try(:ban),
          }, status: status)
        end
        return redirect_to(acknowledge_bans_path(user_id: CurrentUser.user.signed_id(purpose: :acknowledge_ban))) if CurrentUser.user.ban_expired?
      end
      render_expected_error(status, exception.message)
    when ActionController::InvalidAuthenticityToken
      render_expected_error(403, "ActionController::InvalidAuthenticityToken. Did you properly authorize your request?")
    when ActiveRecord::RecordNotFound
      render404
    when ActiveSupport::MessageVerifier::InvalidSignature, Pundit::NotAuthorizedError
      access_denied
    when User::PrivilegeError
      access_denied(exception)
    when ActionController::RoutingError
      render_error_page(405, exception)
    when ActionController::UnknownFormat, ActionView::MissingTemplate
      render_unsupported_format
    when GayFurCity::Paginator::PaginationError
      render_expected_error(410, exception.message)
    when TagQuery::CountExceededError
      render_expected_error(422, exception.message)
    when FeatureUnavailable
      render_expected_error(501, "This feature isn't available")
    when PG::ConnectionBad
      render_error_page(503, exception, message: "The database is unavailable. Try again later.")
    when RequestTimeoutError
      render_error_page(504, exception, message: "This request took too long to process and was canceled.")
    when ActionController::UnpermittedParameters, ActionController::ParameterMissing
      render_expected_error(400, exception.message)
    when BCrypt::Errors::InvalidHash
      render_expected_error(400, "You must reset your password.")
    else
      render_error_page(500, exception)
    end
  end

  def render404
    respond_to do |fmt|
      fmt.html do
        render("static/404", formats: %i[html atom], status: :not_found)
      end
      fmt.json do
        render(json: { success: false, reason: "not found" }, status: :not_found)
      end
      fmt.any do
        render_unsupported_format
      end
    end
  end

  def render_unsupported_format
    render_expected_error(406, "#{request.format} is not a supported format for this page", format: :html)
  end

  def render_expected_error(status, message, format: request.format.symbol)
    format = :html unless format.in?(%i[html json atom])
    @message = message
    render("static/error", status: status, formats: format)
  end

  def render_error_page(status, exception, message: exception.message, format: request.format.symbol)
    @exception = exception
    @expected = status < 500
    @message = message.encode("utf-8", invalid: :replace, undef: :replace)
    @backtrace = Rails.backtrace_cleaner.clean(@exception.backtrace)
    format = :html unless format.in?(%i[html json atom])

    if !Config.user?(:show_backtrace, CurrentUser.user) && message == exception.message
      @message = "An unexpected error occurred."
    end

    GayFurCity::Logger.log(@exception, expected: @expected)
    log = ExceptionLog.add!(exception, user_id: CurrentUser.user.id, request: request) unless @expected
    @log_code = log&.code
    render("static/error", status: status, formats: format)
  end

  def access_denied(exception = nil)
    previous_url = params[:url] || request.fullpath
    @message = "Access Denied: #{exception}" if exception.is_a?(String)
    @message ||= exception&.message || "Access Denied"

    respond_to do |format|
      format.html do
        if CurrentUser.user.is_anonymous?
          if request.get?
            redirect_to(new_session_path(url: previous_url), notice: @message)
          else
            redirect_to(new_session_path, notice: @message)
          end
        else
          render(template: "static/access_denied", status: :forbidden)
        end
      end
      format.json do
        render(json: { success: false, reason: @message }.to_json, status: :forbidden)
      end
    end
  rescue ActionController::UnknownFormat
    render(plain: @message, status: :forbidden)
  end

  def set_current_user
    CurrentUser.request = request
    SessionLoader.new(request).load
    session.send(:load!) unless session.send(:loaded?)
  end

  # Uses Ruby's Timeout, which interrupts the running thread wherever it happens to be - unsafe in
  # general (it can abort mid-query/mid-transaction), but this sits behind the tighter, cleaner
  # timeouts on individual Postgres queries (statement_timeout) and Elasticsearch requests
  # (request_timeout) that fire first for the common case. This is only a backstop for the rest of
  # the action - rendering, view logic, non-DB work - not the primary defense.
  def enforce_request_cycle_timeout(&action)
    timeout = Config.get_user(:request_cycle_timeout, CurrentUser.user)
    timeout = 10_000 unless timeout.is_a?(Numeric) # jsonb has no schema - guard against a corrupt stored value
    return action.call unless timeout.finite?
    Timeout.timeout(timeout / 1000.0, RequestTimeoutError, &action)
  end

  def reset_current_user
    CurrentUser.reset
    # Time.zone is a raw thread-global (unlike CurrentUser, an ActiveSupport::CurrentAttributes that
    # already resets itself around each request/test) - session_loader.rb sets it per-user with no
    # matching reset, so on a reused thread (Puma reuses threads across requests by default) a later
    # request/test can inherit a previous user's timezone. Reset it here, in the before_action pass of
    # this same callback, so it goes back to the app default before set_current_user re-derives it for
    # the current request's user; the after_action pass then leaves it clean for whatever runs next.
    Time.zone = Rails.application.config.time_zone
  end

  def requires_reauthentication
    return if CurrentUser.user.is_anonymous?

    last_authenticated_at = session[:last_authenticated_at]
    if last_authenticated_at.blank? || Time.zone.parse(last_authenticated_at) < 1.hour.ago
      redirect_to(confirm_password_session_path(url: request.fullpath))
    end
  end

  def user_access_check(method)
    if !CurrentUser.user.send(method) || CurrentUser.user.is_banned? || IpBan.is_banned?(CurrentUser.ip_addr)
      access_denied
    end
  end

  User::Roles.each do |role|
    define_method("#{role}_only") do
      user_access_check("is_#{role}?")
    end
  end

  %i[can_view_staff_notes can_handle_takedowns can_manage_aibur can_edit_avoid_posting_entries].each do |role|
    define_method("#{role}_only") do
      user_access_check("#{role}?")
    end
  end

  def logged_in_only
    if CurrentUser.user.is_anonymous?
      access_denied("Must be logged in")
    end
  end

  def pundit_user
    CurrentUser.user
  end

  def pundit_params_for(record)
    key = Pundit::PolicyFinder.new(record).param_key
    if key == "symbol"
      wrapper = send(:_wrapper_options).try(:name)

      if wrapper.present?
        key = wrapper
      elsif record.is_a?(Symbol)
        key = record
      elsif record.is_a?(Array) && record.last.is_a?(Symbol)
        key = record.last
      elsif record.respond_to?(:to_sym)
        key = record.to_sym
      end
    end
    params.fetch(key, {})
  end

  def can_use_attribute?(object, attr)
    policy(object).can_use_attribute?(attr, params[:action])
  end

  def can_use_any_attribute?(object, *attrs)
    policy(object).can_use_any_attribute?(*attrs, action: params[:action])
  end

  alias can_use_attributes? can_use_attribute?

  # Remove blank `search` params from the url.
  #
  # /tags?search[name]=touhou&search[category]=&search[order]=
  # => /tags?search[name]=touhou
  def normalize_search
    return unless request.get? || request.head?
    params[:search] ||= ActionController::Parameters.new

    deep_reject_blank = ->(hash) do
      hash.reject { |_k, v| v.blank? || (v.is_a?(Hash) && deep_reject_blank.call(v).blank?) }
    end
    if params[:search].is_a?(ActionController::Parameters)
      nonblank_search_params = deep_reject_blank.call(params[:search])
    else
      nonblank_search_params = ActionController::Parameters.new
    end

    if nonblank_search_params != params[:search]
      params[:search] = nonblank_search_params
      redirect_to(url_for(params: params.except(:controller, :action, :index).permit!))
    end
  end

  def search_params(relation = nil)
    p = params.fetch(:search, {})
    return p.permit! if relation.nil? || p.empty?
    po = policy(relation)
    if po.respond_to?("permitted_search_params_for_#{action_name}")
      return p.permit(po.send("permitted_search_params_for_#{action_name}"))
    end
    p.permit(po.permitted_search_params)
  end

  def format_json(data, **)
    ->(format) do
      format.json { render(json: data.to_json, **) }
    end
  end

  def notice(message)
    flash[:notice] = message if request.format.html?
  end

  def model_includes(params, model: nil) # rubocop:disable Lint/UnusedMethodArgument
    if params[:only] && params[:format] == "json"
      includes_array = ParameterBuilder.includes_parameters(params[:only], model_name)
    elsif params[:action] == "index"
      includes_array = default_includes(params)
    else
      includes_array = []
    end
    includes_array
  end

  def default_includes(*)
    []
  end

  def model_name
    controller_name.classify
  end
end

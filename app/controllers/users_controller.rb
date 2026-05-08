# frozen_string_literal: true

class UsersController < ApplicationController
  respond_to(:html, :json)
  skip_before_action(:api_check)
  before_action(:logged_in_only, only: %i[edit upload_limit update])

  def index
    if params[:name].present?
      @user = User.find_by_current_or_former_name!(User.normalize_name(params[:name]))
      redirect_to(user_path(@user, n: params[:n]))
    else
      @users = User.search_current(search_params(User))
                   .paginate(params[:page], limit: params[:limit])
      respond_with(@users)
    end
  end

  def show
    @user = User.find(User.name_or_id_to_id_forced(params[:id]))
    @presenter = UserPresenter.new(@user, view: view_context)
    respond_with(@user)
  end

  def new
    raise(User::PrivilegeError, "Already signed in") unless CurrentUser.user.is_anonymous?
    return access_denied("Signups are disabled") unless Config.instance.enable_signups?
    @user = User.new
    respond_with(@user)
  end

  def edit
    @user = User.find(CurrentUser.user.id)
    raise(User::PrivilegeError, "Must verify account email") unless @user.is_verified?
    respond_with(@user)
  end

  def home
    @user = CurrentUser.user
  end

  def search
  end

  def upload_limit
    authorize(User)
    @presenter = UserPresenter.new(CurrentUser.user, view: view_context)
    pieces = CurrentUser.upload_limit_pieces
    @approved_count = pieces.approved
    @deleted_count = pieces.deleted
    @pending_count = pieces.pending
  end

  def me
    @user = authorize(CurrentUser.user)
    respond_with(@user)
  end

  def create
    raise(User::PrivilegeError, "Already signed in") unless CurrentUser.user.is_anonymous?
    raise(User::PrivilegeError, "Signups are disabled") unless Config.instance.enable_signups?
    User.transaction do
      @user = User.new(permitted_attributes(User).merge({ last_ip_addr: request.remote_ip }))
      @user.validate_email_format = true
      @user.email_verified = false if Config.instance.enable_email_verification?
      if !GayFurCity.config.recaptcha.enabled? || verify_recaptcha(model: @user)
        @user.save
        if @user.errors.empty?
          session[:user_id] = @user.id
          session[:ph] = @user.password_token
          if Config.instance.enable_email_verification?
            Users::EmailConfirmationMailer.confirmation(@user).deliver_now
          end
          UserEvent.create_from_request!(@user, :user_creation, request)
        else
          flash[:notice] = "Sign up failed: #{@user.errors.full_messages.join('; ')}"
        end
        set_current_user
      else
        flash[:notice] = "Sign up failed"
      end
      respond_with(@user)
    end
  rescue ::Mailgun::CommunicationError
    session[:user_id] = nil
    @user.errors.add(:email, "There was a problem with your email that prevented sign up")
    @user.id = nil
    flash[:notice] = "There was a problem with your email that prevented sign up"
    respond_with(@user)
  end

  def update
    @user = User.find(CurrentUser.user.id)
    @user.validate_email_format = true
    raise(User::PrivilegeError, "Must verify account email") unless @user.is_verified?
    @user.update(permitted_attributes(@user))
    if @user.errors.any?
      flash[:notice] = @user.errors.full_messages.join("; ")
    else
      if @user.saved_change_to_bcrypt_password_hash?
        UserEvent.create_from_request!(@user, :password_change, request)
      end
      flash[:notice] = "Settings updated"
    end
    respond_with(@user) do |format|
      format.html { redirect_back_or_to(edit_users_path) }
    end
  end

  def custom_style
    authorize(User)
    @css = CustomCss.parse(CurrentUser.user.custom_style)
    expires_in(10.years)
  end

  def unban
    @user = authorize(User.find(params[:id]))
    return render_expected_error(422, "User is not banned") unless @user.is_banned?
    @user.unban!(CurrentUser.user)
    notice("User unbanned")
    respond_with(@user)
  end

  def info
    @user = authorize(User.find(params[:id]))
    @info = UserInfo.new(@user)
    respond_with(@info)
  end
end

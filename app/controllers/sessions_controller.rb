# frozen_string_literal: true

class SessionsController < ApplicationController
  def new
    @user = User.new(name: params[:name].presence)
  end

  def create
    sparams = params.fetch(:session, {}).slice(:url, :name, :password, :remember, :type)
    if RateLimiter.check_limit("login:#{request.remote_ip}", 15, 12.hours)
      GayFurCity::Logger.add_attributes("user.login" => "rate_limited")
      return redirect_to(new_session_path, notice: "Username/Password was incorrect")
    end
    session_creator = SessionCreator.new(session, cookies, sparams[:name], sparams[:password], request.remote_ip, request, remember: sparams[:remember], secure: request.ssl?)

    @type = sparams[:type].presence || "login"
    if (@user = session_creator.authenticate(@type))
      @url = (sparams[:url] if sparams[:url]&.start_with?("/") && !sparams[:url].start_with?("//")) || posts_path
      if @user&.mfa.present?
        @remember = sparams[:remember]
        render(:confirm_mfa)
      else
        GayFurCity::Logger.add_attributes("user.login" => "success")
        redirect_to(@url)
      end
    else
      RateLimiter.hit("login:#{request.remote_ip}", 6.hours)
      GayFurCity::Logger.add_attributes("user.login" => "fail")
      redirect_back_or_to(new_session_path, notice: "Username/Password was incorrect")
    end
  end

  def destroy
    session.delete(:user_id)
    session.delete(:last_authenticated_at)
    cookies.delete(:remember)
    UserEvent.create_from_request!(CurrentUser.user, :logout, request)
    redirect_to(posts_path, notice: "You are now logged out")
  end

  def confirm_password
  end

  def verify_mfa
    @user = User.find_signed!(params.dig(:mfa, :user_id), purpose: :verify_mfa)
    @url = params.dig(:mfa, :url).presence || posts_path
    @type = params.dig(:mfa, :type).presence || "login"

    session_creator = SessionCreator.new(session, cookies, nil, nil, request.remote_ip, request, remember: params.dig(:mfa, :remember), secure: request.ssl?)

    if session_creator.verify_mfa(@user, params.dig(:mfa, :code), @type)
      @url = posts_path unless @url.start_with?("/") && !@url.start_with?("//")
      redirect_to(@url)
    else
      @user.mfa.errors.add(:code, "is incorrect")
      render(:confirm_mfa)
    end
  end
end

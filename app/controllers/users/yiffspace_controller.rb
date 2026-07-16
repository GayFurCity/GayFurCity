# frozen_string_literal: true

module Users
  # Bridges the yiffspace-auth engine's own session (Discord identity + Logto tokens, at
  # /auth) into this app's own login session (session[:user_id], via SessionCreator) and into
  # LinkedAccount rows.
  class YiffspaceController < ApplicationController
    include(YiffSpace::Auth::Helper::Scoped)

    PROVIDER = "yiffspace"

    def callback
      return redirect_to(new_session_path, notice: "YiffSpace sign in failed") unless yiffspace_logged_in?
      return connect_to_current_user unless CurrentUser.user.is_anonymous?

      existing = LinkedAccount.find_by(provider: PROVIDER, uid: yiffspace_user.id)
      return sign_in_linked_user(existing.user) if existing

      PendingAccountLink.stash!(session, provider: PROVIDER, uid: yiffspace_user.id, display_name: discord_display_name)
      @discord_username = discord_display_name
    end

    private

    def discord_display_name
      yiffspace_user.display_name.presence || yiffspace_user.username
    end

    def connect_to_current_user
      existing = LinkedAccount.find_by(provider: PROVIDER, uid: yiffspace_user.id)

      if existing.present? && existing.user_id != CurrentUser.user.id
        return redirect_to(edit_user_linked_accounts_path, notice: "That YiffSpace account is already linked to a different user")
      end

      already_linked = CurrentUser.user.linked_accounts.find_by(provider: PROVIDER)
      if already_linked.present? && already_linked.uid != yiffspace_user.id
        return redirect_to(edit_user_linked_accounts_path, notice: "Your account already has a different YiffSpace identity linked - unlink it first")
      end

      CurrentUser.user.linked_accounts.find_or_create_by!(provider: PROVIDER, uid: yiffspace_user.id) do |link|
        link.display_name = discord_display_name
      end
      UserEvent.create_from_request!(CurrentUser.user, :linked_account_connect, request, metadata: { "provider" => PROVIDER }) if already_linked.blank?
      redirect_to(edit_user_linked_accounts_path, notice: "YiffSpace account linked")
    end

    def sign_in_linked_user(user)
      session_creator = SessionCreator.new(session, cookies, nil, nil, request.remote_ip, request, remember: true, secure: request.ssl?)
      session_creator.process_login(user, :login)

      if user.mfa.present?
        UserEvent.create_from_request!(user, :mfa_linked_account_login_pending_verification, request, metadata: { "provider" => PROVIDER })
        @user = user
        @url = posts_path
        @type = "login"
        @remember = true
        render(template: "sessions/confirm_mfa")
      else
        UserEvent.create_from_request!(user, :linked_account_login, request, metadata: { "provider" => PROVIDER })
        GayFurCity::Logger.add_attributes("user.login" => "success")
        redirect_to(posts_path, notice: "You are now logged in")
      end
    end
  end
end

# frozen_string_literal: true

module Users
  class EmailChangesController < ApplicationController
    respond_to(:html)

    def new
    end

    def create
      user = CurrentUser.user
      email_change = UserEmailChange.new(user, params[:email_change][:email], params[:email_change][:password])
      email_change.process
      if user.errors.any?
        flash[:notice] = user.errors.full_messages.join("; ")
        redirect_to(new_users_email_change_path)
      else
        UserEvent.create_from_request!(user, :email_change, request)
        redirect_to(home_users_path, notice: "Email was updated")
      end
    end
  end
end

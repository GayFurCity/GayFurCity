# frozen_string_literal: true

module Users
  class LinkedAccountsController < ApplicationController
    respond_to(:html, :json)

    before_action(:requires_reauthentication)

    def edit
      @user = authorize(CurrentUser.user, policy_class: LinkedAccountPolicy)
      @linked_accounts = @user.linked_accounts.index_by(&:provider)
      respond_with(@user)
    end

    def destroy
      @linked_account = authorize(CurrentUser.user.linked_accounts.find(params[:id]))
      if @linked_account.destroy
        UserEvent.create_from_request!(CurrentUser.user, :linked_account_disconnect, request, metadata: { "provider" => @linked_account.provider })
      end
      notice("#{@linked_account.provider_name} account unlinked")
      respond_with(@linked_account, location: edit_user_linked_accounts_path)
    end
  end
end

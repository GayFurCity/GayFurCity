# frozen_string_literal: true

module Users
  module MFA
    class BackupCodesController < ApplicationController
      respond_to(:html)
      respond_to(:text, only: %i[show])
      before_action(:requires_reauthentication)

      def show
        @user = authorize(CurrentUser.user, policy_class: BackupCodePolicy)
        return render_expected_error(422, "MFA not enabled") if @user.mfa.blank?
        respond_with(@user.mfa)
      end

      def create
        @user = authorize(CurrentUser.user, policy_class: BackupCodePolicy)
        @user.regenerate_backup_codes!(request)
        respond_with(@user) do |format|
          format.html { redirect_back_or_to(user_mfa_backup_codes_path, notice: "Backup codes regenerated, all previous codes are now invalid") }
        end
      end
    end
  end
end

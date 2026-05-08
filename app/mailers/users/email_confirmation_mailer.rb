# frozen_string_literal: true

module Users
  class EmailConfirmationMailer < ApplicationMailer
    helper(ApplicationHelper)
    helper(UsersHelper)
    include(UsersHelper)

    default(from: GayFurCity.config.email.from_addr, content_type: "text/html")

    def confirmation(user)
      @user = user
      headers["List-Unsubscribe"] = "<#{Routes.users_email_notification_url(user_id: @user.id, sig: email_sig(@user, :unsubscribe), host: GayFurCity.config.hostname, only_path: false)}>"
      mail(to: @user.email, subject: "#{Config.instance.app_name} account confirmation")
    end
  end
end

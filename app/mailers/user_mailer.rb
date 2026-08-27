# frozen_string_literal: true

class UserMailer < ApplicationMailer
  helper(ApplicationHelper)
  helper(UsersHelper)
  include(UsersHelper)

  default(from: GayFurCity.config.email.from_addr, content_type: "text/html")

  def dmail_notice(dmail)
    @dmail = dmail
    headers["List-Unsubscribe"] = "<#{Routes.users_email_notification_url(user_id: @dmail.from.id, sig: email_sig(@dmail.from, :unsubscribe), host: GayFurCity.config.hostname, only_path: false)}>"
    mail(to: "#{dmail.to.name} <#{dmail.to.email}>", subject: "#{AdminConfig.instance.app_name} - Message received from #{dmail.from.name}")
  end

  def forum_notice(user, forum_topic, forum_posts)
    @user = user
    @forum_topic = forum_topic
    @forum_posts = forum_posts
    headers["List-Unsubscribe"] = "<#{Routes.users_email_notification_url(user_id: @user.id, sig: email_sig(@user, :unsubscribe), host: GayFurCity.config.hostname, only_path: false)}>"
    mail(to: "#{user.name} <#{user.email}>", subject: "#{AdminConfig.instance.app_name} forum topic #{forum_topic.title} updated")
  end
end

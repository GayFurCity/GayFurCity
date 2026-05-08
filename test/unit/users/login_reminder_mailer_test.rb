# frozen_string_literal: true

require("test_helper")

module Users
  class LoginReminderMailerTest < ActionMailer::TestCase
    context("The login reminder mailer") do
      setup do
        @user = create(:user)
      end

      should("send the notice") do
        LoginReminderMailer.notice(@user).deliver_now

        assert_not(ActionMailer::Base.deliveries.empty?)
      end
    end
  end
end

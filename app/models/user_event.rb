# frozen_string_literal: true

class UserEvent < ApplicationRecord
  belongs_to_user(:user, ip: true)
  belongs_to(:user_session)
  after_create(:track_telemetry)

  enum(:category, {
    login:                                         0,
    reauthenticate:                                25,
    failed_login:                                  50,
    banned_login:                                  60,
    failed_reauthenticate:                         75,
    logout:                                        100,
    user_creation:                                 200,
    user_deletion:                                 300,
    password_reset:                                400,
    password_change:                               500,
    email_change:                                  600,
    email_verify:                                  650,
    mfa_enable:                                    700,
    mfa_update:                                    710,
    mfa_disable:                                   720,
    mfa_login:                                     730,
    mfa_login_pending_verification:                733,
    mfa_failed_login:                              736,
    mfa_reauthenticate:                            740,
    mfa_reauthenticate_pending_verification:       743,
    mfa_failed_reauthenticate:                     746,
    backup_codes_generate:                         800,
    backup_code_login:                             840,
    backup_code_reauthenticate:                    845,
    linked_account_connect:                        900,
    linked_account_disconnect:                     910,
    linked_account_signup:                         920,
    linked_account_login:                          930,
    mfa_linked_account_login_pending_verification: 933,
  })

  delegate(:session_id, :ip_addr, :user_agent, to: :user_session)

  def track_telemetry
    Telemetry.track(category, user: user, session_id: session_id, ip: ip_addr, user_agent: user_agent)
  end

  module ConstructorMethods
    def create_from_request!(user, category, request, metadata: {})
      # we need to compare directly due to tests using properly created anonymous users
      raise(StandardError, "Anonymous user supplied to UserEvent#create_from_request!") if user == User.anonymous
      ip_addr = request.remote_ip
      user_session = UserSession.new(session_id: request.session[:session_id], ip_addr: ip_addr, user_agent: request.user_agent)
      user.user_events.create!(category: category, user_session: user_session, user_ip_addr: ip_addr, session_id: request.session[:session_id], user_agent: request.user_agent, metadata: metadata)
    end
  end

  module SearchMethods
    def query_dsl
      super
        .field(:category)
        .field(:session_id)
        .field(:user_agent)
        .field(:ip_addr, :user_ip_addr)
        .association(:user)
    end
  end

  extend(SearchMethods)
  extend(ConstructorMethods)
end

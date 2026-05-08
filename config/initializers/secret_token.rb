# frozen_string_literal: true

require(File.expand_path("../state_checker", __dir__))

StateChecker.instance.check!

Rails.application.config.action_dispatch.session = {
  key:    "_gayfurcity_session",
  secret: StateChecker.instance.session_secret_key,
}
Rails.application.config.secret_key_base = StateChecker.instance.secret_token

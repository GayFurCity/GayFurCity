# frozen_string_literal: true

%w[
  query_dsl query_builder query_helper
  helpers routes trace_logger
  user_like user_resolvable user_attribute
  parse_value duration_parser
  attribute_methods concurrency_methods user_methods
  table_builder conditional_includes has_bit_flags attribute_matchers
].each do |name|
  require("yiffspace/include/#{name}")
end

require("yiffspace/core_ext/all")

# user_class/user_like_class/user_resolvable_class all default to ::User/::UserLike/::UserResolvable
# already, which is correct for this app - no explicit configuration needed for those.
YiffSpace.configure do |config|
  config.max_multi_count = -> { AdminConfig.instance.max_multi_count }
  config.redis_url = GayFurCity.config.redis_url

  # "Login with YiffSpace" (Logto-based Discord OAuth). See .env.sample for the GAYFURCITY_LOGTO_*
  # variables this pulls from - only client_id/client_secret are required for basic login.
  config.discord_bot_token          = GayFurCity.config.logto.discord_bot_token
  config.logto_api_client_id        = GayFurCity.config.logto.api_client_id
  config.logto_api_client_secret    = GayFurCity.config.logto.api_client_secret
  config.logto_api_resource         = GayFurCity.config.logto.api_resource
  config.auth.update_discord_images = false

  config.add_default_auth do |client|
    client.client_id            = GayFurCity.config.logto.client_id
    client.client_secret        = GayFurCity.config.logto.client_secret
    client.redirect_uri         = "#{GayFurCity.config.hostname}/auth/yiffspace/cb"
    client.resource             = GayFurCity.config.logto.resource
    client.scopes              += %w[discord]
  end
end

# CurrentUser is autoloaded from app/, which isn't set up yet this early in boot (config/initializers
# run before the main Zeitwerk autoloader's #setup in this app) - defer until the app is ready.
Rails.application.config.after_initialize do
  YiffSpace.config.current_class = CurrentUser # rubocop:disable YiffSpace/CurrentOutsideOfRequests
end

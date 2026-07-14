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
  config.max_multi_count = -> { Config.instance.max_multi_count }
  config.redis_url = GayFurCity.config.redis_url
end

# CurrentUser is autoloaded from app/, which isn't set up yet this early in boot (config/initializers
# run before the main Zeitwerk autoloader's #setup in this app) - defer until the app is ready.
Rails.application.config.after_initialize do
  YiffSpace.config.current_class = CurrentUser
end

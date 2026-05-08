# frozen_string_literal: true

require("sidekiq-unique-jobs")

Sidekiq.configure_server do |config|
  # config.failures_default_mode = :exhausted
  config.redis = { url: GayFurCity.config.redis_url }

  config.client_middleware do |chain|
    chain.add(SidekiqUniqueJobs::Middleware::Client)
  end

  config.server_middleware do |chain|
    chain.add(SidekiqUniqueJobs::Middleware::Server)
  end

  SidekiqUniqueJobs::Server.configure(config)
end

Sidekiq.configure_client do |config|
  config.redis = { url: GayFurCity.config.redis_url }

  config.client_middleware do |chain|
    chain.add(SidekiqUniqueJobs::Middleware::Client)
  end
end

Sidekiq.transactional_push!

# https://github.com/mhfs/sidekiq-failures/issues/146
Sidekiq.failures_max_count = false

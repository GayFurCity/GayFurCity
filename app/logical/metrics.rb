# frozen_string_literal: true

# Whether Yabeda/Prometheus metrics should be collected at all - checked both at the few
# instrumentation call sites (app/jobs/application_job.rb, app/logical/storage_manager/base.rb)
# and by config/initializers/prometheus.rb (which skips defining/collecting metrics entirely when
# disabled, not just leaving them unexposed) and config/puma.rb / config/pitchfork.rb (which decide
# whether to load the exporter).
module Metrics
  TRUTHY = /\A(true|t|yes|y|on|1)\z/i

  def self.enabled?
    explicit = ENV.fetch("METRICS_ENABLED", nil)
    return TRUTHY.match?(explicit) if explicit.present?

    ENV.fetch("COMPOSE_PROFILES", "").split(",").include?("metrics")
  end
end

# frozen_string_literal: true

# This configuration file will be evaluated by Puma. The top-level methods that
# are invoked here are part of Puma's configuration DSL. For more information
# about methods provided by the DSL, see https://puma.io/puma/Puma/DSL.html.

# Puma starts a configurable number of processes (workers) and each process
# serves each request in a thread from an internal thread pool.
#
# The ideal number of threads per worker depends both on how much time the
# application spends waiting for IO operations and on how much you wish to
# to prioritize throughput over latency.
#
# As a rule of thumb, increasing the number of threads will increase how much
# traffic a given process can handle (throughput), but due to CRuby's
# Global VM Lock (GVL) it has diminishing returns and will degrade the
# response time (latency) of the application.
#
# The default is set to 3 threads as it's deemed a decent compromise between
# throughput and latency for the average Rails application.
#
# Any libraries that use a connection pool or another resource pool should
# be configured to provide at least as many connections as the number of
# threads. This includes Active Record's `pool` parameter in `database.yml`.
threads_count = ENV.fetch("RAILS_MAX_THREADS", 3)
threads(threads_count, threads_count)

# Specifies the `port` that Puma will listen on to receive requests; default is 3000.
port(ENV.fetch("PORT", 9000))

# Allow puma to be restarted by `bin/rails restart` command.
plugin(:tmp_restart)

# Specify the PID file. Defaults to tmp/pids/server.pid in development.
# In other environments, only set the PID file if requested.
pidfile(ENV["PIDFILE"]) if ENV["PIDFILE"]

require_relative("../app/logical/metrics")

# Skips loading the exporter entirely when nothing is going to scrape it (i.e. the metrics
# sidecar containers aren't running either) - see app/logical/metrics.rb for the enablement rules.
if Metrics.enabled?
  # Exposes puma's own stats (thread pool usage, backlog, etc.) to Yabeda.
  activate_control_app
  plugin(:yabeda)

  # Serves /metrics on its own internal port instead of the public app port, so
  # it isn't reachable through the same reverse-proxied domains as the app.
  plugin(:yabeda_prometheus)
  prometheus_exporter_url(ENV.fetch("PROMETHEUS_EXPORTER_URL", "tcp://0.0.0.0:9394/metrics"))
end

# frozen_string_literal: true

# Checks each backend service in the stack for reachability, mirroring the endpoints/commands each
# service's own docker-compose healthcheck already uses. Services that speak HTTP report a real
# status code; Postgres/Redis/Memcached don't, so they just report up/down. Checks run in parallel
# (each service gets its own thread) so one slow/hung service doesn't hold up the others - the
# overall check is bounded by TIMEOUT regardless of how many services there are.
class ServiceStatusChecker
  Result = Struct.new(:name, :up, :code, :latency_ms, keyword_init: true)

  TIMEOUT = 3

  def self.check_all
    checks.map { |name, check| [name, Concurrent::Future.execute { run(name, &check) }] }.map { |_, future| future.value! }
  end

  def self.checks
    {
      "PostgreSQL"    => method(:check_postgres),
      "Redis"         => method(:check_redis),
      "Elasticsearch" => method(:check_elasticsearch),
      "Memcached"     => method(:check_memcached),
      "IQDB"          => (method(:check_iqdb) if IqdbProxy.enabled?),
      "Recommender"   => (method(:check_recommender) if Recommender.enabled?),
      "Reports"       => (method(:check_reports) if GayFurCity.config.reports.enabled?),
      "ClickHouse"    => (method(:check_clickhouse) if GayFurCity.config.clickhouse_url.present?),
      "Autocompleted" => (method(:check_autocompleted) if GayFurCity.config.autocompleted_server.present?),
    }.compact
  end
  private_class_method(:checks)

  # Non-HTTP checks (postgres/redis/memcached) return nil on success, meaning "reachable, no status
  # code to report" - only an HTTP response code (2xx/3xx) or an exception determines up/down for them.
  def self.run(name)
    start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    code = yield
    Result.new(name: name, up: code.nil? || code < 400, code: code, latency_ms: elapsed_ms(start))
  rescue StandardError
    Result.new(name: name, up: false, code: nil, latency_ms: elapsed_ms(start))
  end
  private_class_method(:run)

  def self.elapsed_ms(start)
    ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - start) * 1000).round
  end
  private_class_method(:elapsed_ms)

  def self.check_postgres
    ApplicationRecord.connection_pool.with_connection { |conn| conn.execute("SELECT 1") }
    nil
  end
  private_class_method(:check_postgres)

  def self.check_redis
    Cache.redis.ping
    nil
  end
  private_class_method(:check_redis)

  def self.check_memcached
    GayFurCity.config.memcached_servers.each { |server| Dalli::Client.new(server).version }
    nil
  end
  private_class_method(:check_memcached)

  def self.check_elasticsearch
    http_get("http://#{GayFurCity.config.elasticsearch_host}:9200/_cluster/health?timeout=2s")
  end
  private_class_method(:check_elasticsearch)

  def self.check_iqdb
    http_get("#{GayFurCity.config.iqdb_server}/status")
  end
  private_class_method(:check_iqdb)

  def self.check_recommender
    http_get("#{GayFurCity.config.recommender_server}/info")
  end
  private_class_method(:check_recommender)

  def self.check_reports
    http_get("#{GayFurCity.config.reports.server_internal}/up")
  end
  private_class_method(:check_reports)

  def self.check_clickhouse
    http_get("#{GayFurCity.config.clickhouse_url}/ping")
  end
  private_class_method(:check_clickhouse)

  def self.check_autocompleted
    http_get("#{GayFurCity.config.autocompleted_server}/up")
  end
  private_class_method(:check_autocompleted)

  def self.http_get(url)
    Faraday.new(request: { timeout: TIMEOUT, open_timeout: TIMEOUT }).get(url).status
  end
  private_class_method(:http_get)
end

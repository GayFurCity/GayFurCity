# frozen_string_literal: true

require_relative("document_store/model") # due to some fuckery we have to force load the file the client is defined in

class SystemInfo
  def load_all
    reports
    postgres
    redis
    memcached
    elasticsearch
    git
    main
    gems
    self
  end

  def dbsize
    @dbsize ||= DbSize.new
  end

  def reports
    @reports ||= begin
      data = Reports.get_stats
      OpenHash.from(date:    { code: data["date"], db: data["dbDate"] },
                    version: { schema: data["schemaVersion"], db: data["dbVersion"] },
                    health:  { healthy: data["healthy"], error: data["error"] },
                    latency: data["latency"])
    end
  end

  def postgres
    @postgres ||= begin
      sql = <<~SQL.squish
        SELECT TO_CHAR(NOW() AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"') AS date,
            dbstats.numbackends AS connection_count,
            dbstats.deadlocks,
            version(),
            schema_migrations.version as latest_migration,
            schema_migrations_count.count as migration_count
        FROM LATERAL (
            SELECT numbackends, deadlocks
            FROM pg_stat_database
            WHERE datname = '#{ApplicationRecord.connection.current_database}'
        ) dbstats,
        LATERAL (
          SELECT version
          FROM schema_migrations
          ORDER BY version DESC
          LIMIT 1
        ) schema_migrations,
        LATERAL (
          SELECT COUNT(*) as count FROM schema_migrations
        ) schema_migrations_count
      SQL
      data = ApplicationRecord.connection.execute(sql).first
      latency = time { ApplicationRecord.connection.execute("SELECT 1").first }
      pending_migrations = false
      begin
        ActiveRecord::Migration.check_all_pending!
      rescue ActiveRecord::PendingMigrationError
        pending_migrations = true
      end
      OpenHash.from(date: data["date"], connection_count: data["connection_count"], deadlocks: data["deadlocks"], version: data["version"], latency: latency, database: ApplicationRecord.connection.current_database, latest_migration: data["latest_migration"], latest_migration_date: Time.strptime(data["latest_migration"], "%Y%m%d%H%M%S"), migration_count: data["migration_count"], pending_migrations: pending_migrations)
    end
  end

  def redis
    @redis ||= begin
      latency = time { Cache.redis.ping }
      current_db = Cache.redis._client.db.to_s
      info = Cache.redis.info
      version = info["redis_version"]
      connected_clients = info["connected_clients"].to_i
      clients_per_db = Cache.redis._client.call_v(["CLIENT", "LIST"]).split("\n").map { |l| l.match(/db=(\d+)/)[1] }.tally
      keys_per_db = Cache.redis.info("KEYSPACE").to_h { |k, v| [k[2..], v.match(/keys=(\d+)/)[1].to_i] }
      OpenHash.from(latency: latency, current_db: current_db, version: version, connected_clients: connected_clients, clients_per_db: clients_per_db, keys_per_db: keys_per_db, databases: keys_per_db.keys)
    end
  end

  def memcached
    @memcached ||= begin
      client = Dalli::Client.new(GayFurCity.config.memcached_servers)
      all_stats = client.stats
      all_stats.keys.to_h do |server|
        stats = all_stats[server]
        latency = time { Dalli::Client.new(server).version }
        [server, OpenHash.from(
          version:     stats["version"],
          connections: stats["curr_connections"].to_i,
          date:        Time.zone.at(stats["time"].to_i).utc.iso8601,
          latency:     latency,
        ),]
      end
    end
  end

  def elasticsearch
    @elasticsearch ||= begin
      info = DocumentStore.client.info
      version = info["version"]["number"]
      latency = time { DocumentStore.client.ping }
      indexes = DocumentStore.client.cat.indices(h: "index,docs.count", format: "json").map do |r|
        { name: r["index"], docs: r["docs.count"].to_i }
      end
      health = DocumentStore.client.cat.health(format: "json").first
      OpenHash.from(version: version, latency: latency, indexes: indexes.pluck(:name), docs_per_index: indexes.to_h { |i| [i[:name], i[:docs]] }, date: Time.at(health["epoch"].to_i).utc.iso8601, status: health["status"])
    end
  end

  def git
    @git ||= GitHelper.instance
  end

  def main
    @main ||= OpenHash.from(ruby_version: RUBY_VERSION, rails_version: Rails.version, node_version: `node --version`.strip, alpine_version: File.read("/etc/alpine-release").strip, environment: Rails.env, hostname: GayFurCity.config.hostname, name: AdminConfig.instance.app_name, url: GayFurCity.config.app_url, description: AdminConfig.instance.app_description, safe_mode: AdminConfig.instance.safe_mode?, version: GayFurCity.config.version, date: Time.now.utc.iso8601, timezone: Time.zone.name, timezone_sys: `date +%Z`[..-1])
  end

  def gems
    @gems ||= Bundler.load.dependencies.map do |dep|
      spec = Bundler.load.specs.find { |s| s.name == dep.name }
      [dep.name.downcase, dep.requirement, (spec.version.to_s if spec)]
    end.sort_by(&:first)
  end

  private

  def time(&block)
    start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    block.call
    ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - start) * 1000).round(2)
  end
end

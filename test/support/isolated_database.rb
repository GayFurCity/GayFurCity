# frozen_string_literal: true

require("pg")
require("digest")
require("open3")

# Gives each test process its own Postgres database (named after its pid, mirroring the storage
# directory and Elasticsearch index) so that separate `bin/rails test` invocations - or parallel
# workers within one - never share (and race on) the same database.
#
# Runs before config/environment is loaded, using the `pg` gem directly (ActiveRecord isn't
# available yet). A "test_template" database is built once (or rebuilt whenever db/structure.sql
# changes) and cloned per-run via `CREATE DATABASE ... TEMPLATE`, which Postgres does near-instantly
# at the filesystem level - much cheaper than replaying structure.sql on every invocation. An
# advisory lock serializes the "check/rebuild the template" step across concurrent processes; the
# actual per-run clone can safely happen concurrently once nobody is mid-rebuild.
module IsolatedDatabase
  TEMPLATE_NAME = "test_template"
  TEMPLATE_LOCK_KEY = 8_423_461_920_318_552 # arbitrary constant, just needs to be consistent
  DB_USER = ENV.fetch("GAYFURCITY_DB_USER", "gayfurcity")
  DB_HOST = "postgres"
  STRUCTURE_SQL = File.expand_path("../../db/structure.sql", __dir__)

  def self.database_name
    # p<pid>/n<TEST_ENV_NUMBER> (n omitted when absent) makes it obvious at a glance in logs what a
    # given database name is - see also DocumentStore::Model, which names test indices the same way.
    # rubocop:disable Rails/Present -- ActiveSupport isn't loaded yet, this runs before Rails boots
    test_env_number = ENV.fetch("TEST_ENV_NUMBER", nil)
    @database_name ||= "test-p#{Process.pid}#{"-n#{test_env_number}" if test_env_number && !test_env_number.empty?}"
    # rubocop:enable Rails/Present
  end

  def self.setup!
    ENV["GAYFURCITY_TEST_DB_NAME"] = database_name

    with_connection("postgres") do |conn|
      ensure_template!(conn)
      conn.exec("CREATE DATABASE #{conn.quote_ident(database_name)} TEMPLATE #{conn.quote_ident(TEMPLATE_NAME)}")
    end

    at_exit do
      with_connection("postgres") do |conn|
        conn.exec("DROP DATABASE IF EXISTS #{conn.quote_ident(database_name)} WITH (FORCE)")
      end
    end
  end

  def self.ensure_template!(conn)
    conn.exec_params("SELECT pg_advisory_lock($1)", [TEMPLATE_LOCK_KEY])
    begin
      return if template_current?(conn)

      conn.exec("DROP DATABASE IF EXISTS #{conn.quote_ident(TEMPLATE_NAME)} WITH (FORCE)")
      conn.exec("CREATE DATABASE #{conn.quote_ident(TEMPLATE_NAME)}")

      load_structure!
      record_structure_hash!
    ensure
      conn.exec_params("SELECT pg_advisory_unlock($1)", [TEMPLATE_LOCK_KEY])
    end
  end

  def self.template_current?(conn)
    exists = conn.exec_params("SELECT 1 FROM pg_database WHERE datname = $1", [TEMPLATE_NAME]).ntuples > 0
    return false unless exists

    with_connection(TEMPLATE_NAME) do |template_conn|
      result = template_conn.exec_params("SELECT value FROM ar_internal_metadata WHERE key = 'structure_sql_hash'")
      result.ntuples > 0 && result[0]["value"] == structure_sql_hash
    end
  rescue PG::UndefinedTable
    false
  end

  def self.load_structure!
    command = ["psql", "-h", DB_HOST, "-U", DB_USER, "-d", TEMPLATE_NAME, "-v", "ON_ERROR_STOP=1", "-q", "-f", STRUCTURE_SQL]
    _, status = Open3.capture2e(*command)
    raise("Failed to load db/structure.sql into #{TEMPLATE_NAME}") unless status.success?
  end

  def self.record_structure_hash!
    with_connection(TEMPLATE_NAME) do |conn|
      conn.exec_params(
        "INSERT INTO ar_internal_metadata (key, value, created_at, updated_at) VALUES ('structure_sql_hash', $1, now(), now()) " \
        "ON CONFLICT (key) DO UPDATE SET value = EXCLUDED.value, updated_at = now()",
        [structure_sql_hash],
      )
    end
  end

  def self.structure_sql_hash
    @structure_sql_hash ||= Digest::SHA256.hexdigest(File.read(STRUCTURE_SQL))
  end

  def self.with_connection(dbname)
    conn = PG.connect(host: DB_HOST, dbname: dbname, user: DB_USER)
    yield(conn)
  ensure
    conn&.close
  end
end

IsolatedDatabase.setup!

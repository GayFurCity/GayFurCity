# frozen_string_literal: true

require("pg")
require("digest")
require("open3")
require("securerandom")

# Gives each test process its own Postgres database (named after its pid, mirroring the storage
# directory and Elasticsearch index) so that separate `bin/rails test` invocations never share (and
# race on) the same database. See test_helper.rb for how this same template is reused to give each
# of Rails' own `parallelize` worker processes its own database too.
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
    # p<pid> makes it obvious at a glance in logs what a given database name is - see also
    # DocumentStore::Model, which names test indices the same way. Rails' own `parallelize` support
    # (see test_helper.rb) forks worker processes from here and suffixes this base name with
    # -n<worker number> for each one, so all of a run's databases are traceable to one pid.
    #
    # The trailing random suffix matters in CI: `docker compose run` starts a brand new container per
    # invocation, and a fresh container's entrypoint process is always pid 1, so Process.pid alone
    # would collide with a previous run's leftover database of the exact same name (e.g. if that run
    # was cancelled/crashed before reaching its own cleanup) - pid_alive?(1) checked from a NEW
    # container also always reports "alive" since it just observes itself, so reap_orphaned! can't
    # tell the old one apart either. The random component sidesteps the collision outright; the pid
    # prefix is kept since reap_orphaned!'s matching only cares about the leading digits.
    @database_name ||= "test-p#{Process.pid}-#{SecureRandom.hex(4)}"
  end

  # worker_number is nil for the (non-parallelized) primary process's own database.
  def self.worker_database_name(worker_number)
    return database_name if worker_number.nil?
    "#{database_name}-n#{worker_number}"
  end

  def self.setup!
    ENV["GAYFURCITY_TEST_DB_NAME"] = database_name
    reap_orphaned!
    clone!(database_name)

    # `at_exit` handlers registered here are inherited by every `parallelize` worker process forked
    # from us (fork() duplicates the whole process, at_exit stack included), so without this guard
    # each of them would also try to drop OUR database on its own exit - harmless (DROP ... IF
    # EXISTS no-ops) but noisy. Only the process that actually registered this should run it.
    owner_pid = Process.pid
    at_exit { drop!(database_name) if Process.pid == owner_pid }
  end

  # at_exit/parallelize_teardown are best-effort: they don't run on SIGKILL, a crashed worker, or a
  # parent killed before it can wait for/clean up its workers. As a safety net, sweep away any
  # test-pNNN[-nN] database whose embedded pid no longer belongs to a live process before creating
  # our own. Safe to run concurrently with other invocations doing the same thing - DROP ... IF
  # EXISTS on an already-gone database is a no-op, not an error.
  def self.reap_orphaned!
    with_connection("postgres") do |conn|
      conn.exec("SELECT datname FROM pg_database WHERE datname ~ '^test-p[0-9]+'").each do |row|
        name = row["datname"]
        pid = name[/^test-p(\d+)/, 1].to_i
        drop!(name) unless pid_alive?(pid)
      end
    end
  end

  def self.pid_alive?(pid)
    Process.kill(0, pid)
    # A live pid alone isn't enough: pids get recycled by the kernel, so a long-dead test
    # process's pid can end up reassigned to an unrelated long-lived process (a container's own
    # entrypoint/foreman, seen in practice with low pids early in a container's life) - which
    # would make an actually-orphaned resource look permanently alive. Confirm the pid still looks
    # like one of ours.
    ruby_process?(pid)
  rescue Errno::ESRCH
    false
  rescue Errno::EPERM
    true # exists, just not signalable by us (so /proc access would fail too) - assume still alive
  end

  def self.ruby_process?(pid)
    cmdline = File.read("/proc/#{pid}/cmdline")
    cmdline.include?("ruby") || cmdline.include?("rails")
  rescue Errno::ENOENT, Errno::ESRCH
    false # process exited between the kill(0) check and reading /proc - treat as dead
  end

  def self.clone!(name)
    with_connection("postgres") do |conn|
      ensure_template!(conn)
      conn.exec("CREATE DATABASE #{conn.quote_ident(name)} TEMPLATE #{conn.quote_ident(TEMPLATE_NAME)}")
    end
  end

  def self.drop!(name)
    with_connection("postgres") do |conn|
      conn.exec("DROP DATABASE IF EXISTS #{conn.quote_ident(name)} WITH (FORCE)")
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

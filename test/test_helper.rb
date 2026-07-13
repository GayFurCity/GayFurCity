# frozen_string_literal: true

ENV["RAILS_ENV"] ||= "test"
ENV["MT_NO_EXPECTATIONS"] = "true"
require_relative("support/isolated_database")
require_relative("../config/environment")
require("rails/test_help")

require("factory_bot_rails")

require("mocha/minitest")
require("shoulda-context")
require("shoulda-matchers")
require("webmock/minitest")
require("simplecov")
SimpleCov.start

require("simplecov-cobertura")
SimpleCov.formatter = SimpleCov::Formatter::CoberturaFormatter

require("sidekiq/testing")
require("redis/namespace")

unless ENV["RM_INFO"]
  require("minitest/reporters")
  reporters = [Minitest::Reporters::DefaultReporter.new]
  reporters << Minitest::Reporters::JUnitReporter.new if ENV["CI"]
  Minitest::Reporters.use!(reporters)
end

Dir["#{__dir__}/test_helpers/**/*.rb"].each { require(it) }

Sidekiq::Testing.fake!
# https://github.com/sidekiq/sidekiq/issues/5907#issuecomment-1536457365
Sidekiq.configure_client do |cfg|
  cfg.logger.level = Logger::WARN
end

Shoulda::Matchers.configure do |config|
  config.integrate do |with|
    with.test_framework(:minitest)
    with.library(:rails)
  end
end

WebMock.disable_net_connect!(allow: [
  GayFurCity.config.elasticsearch_host,
])

FactoryBot::SyntaxRunner.class_eval do
  include(ActiveSupport::Testing::FileFixtures)
  include(ActionDispatch::TestProcess::FixtureFile)

  self.file_fixture_path = ActiveSupport::TestCase.file_fixture_path
end

# Make tests not take ages. Remove the const first to avoid a const redefinition warning.
BCrypt::Engine.send(:remove_const, :DEFAULT_COST)
BCrypt::Engine::DEFAULT_COST = BCrypt::Engine::MIN_COST

# Cache.redis (app/logical/cache.rb) is a single connection shared by every process pointed at the
# same GAYFURCITY_REDIS_URL - Security::Lockdown, UserThrottle, etc. store real keys through it with
# no isolation of their own. Without namespacing, a `parallelize` worker toggling e.g. lockdown state
# in one test races against a completely unrelated test's assertions in another worker. Reopen
# Cache.redis (test env only - app/logical/cache.rb is untouched) so every process gets its own
# key prefix; parallelize_setup (below) re-prefixes it post-fork since Process.pid changes but a
# memoized ivar wouldn't update on its own (same hazard as User.system/.owner).
class Cache
  def self.redis
    @redis ||= Redis::Namespace.new("test-p#{Process.pid}", redis: Redis.new(url: GayFurCity.config.redis_url))
  end
end

# at_exit/parallelize_teardown (below) are best-effort: they don't run on SIGKILL, a crashed
# worker, or a parent killed before it can wait for/clean up its workers. As a safety net, sweep
# away any *_test-pNNN[-nN] index/keys whose embedded pid no longer belongs to a live process,
# mirroring IsolatedDatabase.reap_orphaned!.
raw_redis_for_reaping = Redis.new(url: GayFurCity.config.redis_url)
reap_cursor = "0"
loop do
  reap_cursor, keys = raw_redis_for_reaping.scan(reap_cursor, match: "test-p*:*", count: 1000)
  keys.each do |key|
    key_pid = key[/^test-p(\d+):/, 1]&.to_i
    next unless key_pid
    raw_redis_for_reaping.del(key) unless IsolatedDatabase.pid_alive?(key_pid)
  end
  break if reap_cursor == "0"
end

document_store_client = Post.document_store.client
document_store_client.cat.indices(index: "*_test-p*", format: "json").each do |row|
  index_pid = row["index"][/_test-p(\d+)/, 1]&.to_i
  next unless index_pid
  document_store_client.indices.delete(index: row["index"]) unless IsolatedDatabase.pid_alive?(index_pid)
end

# Same reaping for storage directories left behind the same way.
Rails.root.glob("tmp/test-storage2-p*").each do |dir|
  dir_pid = File.basename(dir)[/-p(\d+)/, 1]&.to_i
  next unless dir_pid
  FileUtils.rm_rf(dir) unless IsolatedDatabase.pid_alive?(dir_pid)
end

# Clear the elasticsearch indicies completly
Post.document_store.create_index!(delete_existing: true)
PostVersion.document_store.create_index!(delete_existing: true)

# Indices are named per-process (see DocumentStore::Model) so concurrent runs don't collide; without
# this they'd never get cleaned up since each process's name is unique. Minitest.after_run (not
# at_exit!) - Minitest itself defers running tests to an at_exit hook, and at_exit callbacks run
# LIFO, so an at_exit registered here would run BEFORE Minitest's, deleting the index before any
# test runs. This only cleans up the primary process's own index/database - `parallelize` worker
# processes (below) run test methods directly rather than going through Minitest.run, so this never
# fires in them; parallelize_teardown is their equivalent.
Minitest.after_run do
  Post.document_store.delete_index!
  PostVersion.document_store.delete_index!
  Cache.redis.keys("*").each { |key| Cache.redis.del(key) }
end

class ActiveSupport::TestCase # rubocop:disable Style/ClassAndModuleChildren
  include(ActionDispatch::TestProcess::FixtureFile)
  include(FactoryBot::Syntax::Methods)
  include(TestHelpers::Common)
  include(TestHelpers::Util)

  # class_attribute (not attr_accessor on the singleton class!) so that subclasses like
  # PostTest < ActiveSupport::TestCase see this value too - plain class-level instance variables
  # don't inherit to subclasses in Ruby.
  class_attribute(:storage_root)

  # Suffixed with the process id so concurrent `bin/rails test` invocations each get their own
  # directory instead of racing to mkdir/rm_rf a shared one out from under each other. Mutated by
  # parallelize_setup below for each `parallelize` worker process, since a worker inherits this
  # same pid-based path (still naming the primary process) unchanged from before it forked.
  self.storage_root = Rails.root.join("tmp/test-storage2-p#{Process.pid}").to_s

  # ChunkedUpload#tempfile_path builds its .partial path from Dir.tmpdir directly, keyed by a
  # database id that isn't globally unique across `parallelize` workers (each has its own
  # independent database sequence) - without this, two workers can end up writing to the exact
  # same /tmp/<model>-<id>.partial path. Dir.tmpdir respects TMPDIR and isn't memoized, so
  # redirecting it here is enough - no changes needed in ChunkedUpload itself. Reuses storage_root
  # (mkdir_p'd/rm_rf'd every test in setup/teardown below) so .partial files get the same
  # per-worker isolation and cleanup for free, and the same reap_orphaned! sweep on crash/SIGKILL.
  ENV["TMPDIR"] = storage_root

  setup do
    host = "example.com"
    Socket.stubs(:gethostname).returns(host)
    Config.any_instance.stubs(:enable_sock_puppet_validation).returns(false)
    GayFurCity.config.stubs(:disable_throttles).returns(true)
    GayFurCity.config.stubs(:reports_enabled).returns(false)
    GayFurCity.config.stubs(:cdn_domain).returns(host)
    GayFurCity.config.stubs(:domain).returns(host)
    GayFurCity.config.stubs(:hostname).returns("https://#{host}")
    GayFurCity.config.stubs(:cdn_hostname).returns("https://#{host}")
    Rails.application.routes.default_url_options = {
      host: host,
    }

    FileUtils.mkdir_p(self.class.storage_root)
    %w[posts replacements mascots].each do |dir|
      FileUtils.mkdir_p(File.join(self.class.storage_root, dir))
    end
    storage_manager = StorageManager::Local.new(base_dir: self.class.storage_root)
    GayFurCity.config.stubs(:storage_manager_instance).returns(storage_manager)
    GayFurCity.config.stubs(:backup_storage_manager_instance).returns(StorageManager::Null.new)
    Config.any_instance.stubs(:flag_ai_posts).returns(false)
    Config.any_instance.stubs(:tag_ai_posts).returns(false)
    Config.any_instance.stubs(:enable_email_verification).returns(false)
  end

  teardown do
    # The below line is only mildly insane and may have resulted in the destruction of my data several times.
    FileUtils.rm_rf(self.class.storage_root)
    Cache.clear
    RequestStore.clear!
  end

  # Only kicks in for large runs (see ActiveSupport.test_parallelization_threshold, default 50
  # tests) or when PARALLEL_WORKERS is set - a single-file `bin/rails test some_test.rb` run stays
  # single-process. Forked workers inherit the primary process's already-computed pid-based
  # database/index/storage names unchanged, since Process.pid et al were evaluated before the fork -
  # parallelize_setup/parallelize_teardown below rename everything per worker so siblings don't
  # collide, mirroring IsolatedDatabase's own single-process setup.
  parallelize(workers: :number_of_processors)

  parallelize_setup do |worker|
    self.storage_root = "#{storage_root}-n#{worker}"
    ENV["TMPDIR"] = storage_root

    [Post, PostVersion].each do |klass|
      klass.document_store.index_name = "#{klass.document_store.index_name}-n#{worker}"
      klass.document_store.create_index!(delete_existing: true)
    end

    # Process.pid changed (fork), but Cache's memoized @redis wasn't recomputed - clear it so the
    # next call re-derives the namespace prefix from this worker's own pid, not the primary process's.
    Cache.remove_instance_variable(:@redis) if Cache.instance_variable_defined?(:@redis)
  end

  parallelize_teardown do |_worker|
    [Post, PostVersion].each { |klass| klass.document_store.delete_index! }
    Cache.redis.keys("*").each { |key| Cache.redis.del(key) }
  end
end

if defined?(ActiveRecord::TestDatabases)
  # rails/test_help wires ActiveRecord::TestDatabases#create_and_load_schema into the same
  # after-fork hook parallelize_setup above uses, to give each worker its own database - but its
  # implementation reloads db/structure.sql from scratch per worker. Override it to reuse
  # IsolatedDatabase's template-clone approach instead, for the same reason that exists at all.
  #
  # The template is built by IsolatedDatabase before Rails (and so Rails.application.load_seed)
  # even exists, so it's schema-only - the primary process's own database gets seeded once, at the
  # very bottom of this file, but a worker's freshly cloned database has none of that. Load seeds
  # again here, now that establish_connection points this worker at its own database: cheap (each
  # worker's database only ever gets seeded once), and Rails.application.load_seed is idempotent.
  #
  # User.system/.owner memoize the actual AR record on the User class itself (class-level, not
  # per-instance), inherited unchanged by every worker forked from the primary process - stale
  # references into a database this worker was never connected to. Clear them so seeding (which
  # uses User.system) and every test after it look them up fresh, against this worker's own
  # database. User.anonymous is excluded: it's a frozen, never-persisted User.new, not tied to any
  # database row, so it's safe as-is.
  #
  # Rails.cache (memory_store in test) is likewise a single in-process object inherited unchanged
  # by every worker - e.g. a cached Config.instance from the primary process's seeding would
  # otherwise leak into a worker's first test, before that test's own teardown (which clears the
  # cache) gets a chance to run.
  module ActiveRecord
    module TestDatabases
      def self.create_and_load_schema(worker, env_name:)
        name = IsolatedDatabase.worker_database_name(worker)
        ActiveRecord::Base.configurations.configs_for(env_name: env_name).each { |db_config| db_config._database = name }
        IsolatedDatabase.clone!(name)
        ActiveRecord::Base.establish_connection
        Rails.cache.clear
        %i[@system @owner].each { |ivar| User.remove_instance_variable(ivar) if User.instance_variable_defined?(ivar) }
        Rails.application.load_seed
      end
    end
  end

  ActiveSupport::TestCase.parallelize_teardown do |worker|
    IsolatedDatabase.drop!(IsolatedDatabase.worker_database_name(worker))
  end
end

class ActionDispatch::IntegrationTest # rubocop:disable Style/ClassAndModuleChildren
  include(TestHelpers::Common)
  include(TestHelpers::AssertMethods)
  include(TestHelpers::AuthMethods)

  def self.better_let(name, &)
    name = name.to_s
    raise(ArgumentError, "would override defined method") if methods.include?(name)
    @_let_defined ||= {}
    @_let_defined[name] = true
    define_method(name) do |*args, **kwargs|
      @_memoized ||= {}
      @_memoized.fetch(name) { |k| @_memoized[k] = instance_eval(*args, **kwargs, &) }
    end
  end

  def self.path(&)
    better_let(:path, &)
  end

  def self.verb(&)
    better_let(:verb, &)
  end

  def self.params(&)
    better_let(:params, &)
  end

  def self.let_defined?(name)
    name = name.to_s
    @_let_defined ||= {}
    @_let_defined.fetch(name, false)
  end

  def self.asserts(&)
    helper = TestHelpers::Asserts.new(self)
    if block_given?
      helper.in_block = true
      helper.instance_exec(&)
      helper.finish_pending!
      helper.in_block = false
    end
    helper
  end
end

module ActionView
  class TestCase
    # Stub webpacker method so these tests don't compile assets
    def asset_pack_path(name, **_options)
      name
    end
  end
end

Rails.application.load_seed

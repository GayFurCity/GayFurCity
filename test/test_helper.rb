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

# Clear the elasticsearch indicies completly
Post.document_store.create_index!(delete_existing: true)
PostVersion.document_store.create_index!(delete_existing: true)

# Indices are named per-process (see DocumentStore::Model) so concurrent runs don't collide; without
# this they'd never get cleaned up since each process's name is unique. Minitest.after_run (not
# at_exit!) - Minitest itself defers running tests to an at_exit hook, and at_exit callbacks run
# LIFO, so an at_exit registered here would run BEFORE Minitest's, deleting the index before any
# test runs.
Minitest.after_run do
  Post.document_store.delete_index!
  PostVersion.document_store.delete_index!
end

class ActiveSupport::TestCase # rubocop:disable Style/ClassAndModuleChildren
  include(ActionDispatch::TestProcess::FixtureFile)
  include(FactoryBot::Syntax::Methods)
  include(TestHelpers::Common)
  include(TestHelpers::Util)

  # Suffixed with the process id (and ENV["TEST_ENV_NUMBER"], set by Rails' thread-based parallel test
  # workers) so concurrent test runs - whether that's two separate `bin/rails test` invocations, or
  # parallel workers within one - each get their own directory instead of racing to mkdir/rm_rf a
  # shared one out from under each other.
  storage_root = Rails.root.join("tmp/test-storage2-#{Process.pid}#{ENV.fetch('TEST_ENV_NUMBER', nil)}").to_s
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

    FileUtils.mkdir_p(storage_root)
    %w[posts replacements mascots].each do |dir|
      FileUtils.mkdir_p(File.join(storage_root, dir))
    end
    storage_manager = StorageManager::Local.new(base_dir: storage_root)
    GayFurCity.config.stubs(:storage_manager_instance).returns(storage_manager)
    GayFurCity.config.stubs(:backup_storage_manager_instance).returns(StorageManager::Null.new)
    Config.any_instance.stubs(:flag_ai_posts).returns(false)
    Config.any_instance.stubs(:tag_ai_posts).returns(false)
    Config.any_instance.stubs(:enable_email_verification).returns(false)
  end

  teardown do
    # The below line is only mildly insane and may have resulted in the destruction of my data several times.
    FileUtils.rm_rf(storage_root)
    Cache.clear
    RequestStore.clear!
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

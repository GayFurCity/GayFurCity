# frozen_string_literal: true

require_relative("boot")

require("rails")
# Pick the frameworks you want:
require("active_model/railtie")
require("active_job/railtie")
require("active_record/railtie")
# require "active_storage/engine"
require("action_controller/railtie")
require("action_mailer/railtie")
# require "action_mailbox/engine"
# require "action_text/engine"
require("action_view/railtie")
# require "action_cable/engine"
require("rails/test_unit/railtie")

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

require_relative("config")
require_relative("local_config")
Dir["#{__dir__}/../lib/middleware/**/*.rb"].each { |f| require(f) }
Dir["#{__dir__}/../lib/logging/**/*.rb"].each { |f| require(f) }

module GayFurCity
  # Config.ensure_required_set!
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults(7.2)

    # Rails 7.2's :default keeps existing behavior for adapters that don't opt in, but the
    # :test adapter opts in by default, deferring every perform_later call until its enclosing
    # DB transaction commits. Since we never designed job call sites around that assumption
    # (and a lot of them ride along inside an in-progress transaction that may still roll back),
    # keep enqueuing immediately everywhere, matching pre-7.2 behavior.
    config.active_job.enqueue_after_transaction_commit = :never

    # https://github.com/rails/rails/issues/50897
    config.active_record.raise_on_assign_to_attr_readonly = false

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    config.autoload_lib(ignore: %w[dtext_rb generators rubocop tasks templates prometheus])

    # Keep the primary log (log/development.log) plain text, but also mirror every line as a JSON
    # object to log/development.json, so a log shipper can ingest it without losing any of the
    # detail a plain-text line would have had - same severity/message/backtrace content, just
    # JSON-escaped onto one line in the sidecar file.
    config.log_formatter = Logging::JsonSidecarFormatter.new(Rails.root.join("log/#{Rails.env}.jsonl"))

    config.active_record.schema_format = :sql
    config.log_tags = [->(_req) { "PID:#{Process.pid}" }]
    config.action_controller.action_on_unpermitted_parameters = :raise
    config.force_ssl = true
    config.active_job.queue_adapter = :good_job

    if Rails.env.production? && GayFurCity.config.ssl_options.present?
      config.ssl_options = GayFurCity.config.ssl_options
    else
      config.ssl_options = {
        hsts:           false,
        secure_cookies: false,
        redirect:       { exclude: ->(_request) { true } },
      }
    end

    config.after_initialize do
      Rails.application.routes.default_url_options = {
        host: GayFurCity.config.hostname,
      }
    end

    config.i18n.enforce_available_locales = false

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    config.time_zone = "Central Time (US & Canada)"
    # config.eager_load_paths << Rails.root.join("extras")

    config.generators.assets = false
    config.generators.helper = false
    config.generators.test_framework = nil
    config.middleware.insert_before(Rails::Rack::Logger, Middleware::JsonLog) unless Rails.env.test?
    config.middleware.insert_before(Rails::Rack::Logger, Middleware::SilenceHealthcheckLogging)
  end
end

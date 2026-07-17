# frozen_string_literal: true

module Telemetry
  module_function

  EVENTS = UserEvent.categories.keys.map(&:to_sym) + %i[]
  EVENT_LEVEL_MAP = {}.freeze

  def enabled?
    GayFurCity.config.telemetry.enabled?
  end

  def conn
    Faraday.new(GayFurCity.config.faraday_options.deep_merge(
                  url:     GayFurCity.config.telemetry.endpoint,
                  headers: { content_type: "application/json" },
                )) do |c|
      c.request(:authorization, :basic, GayFurCity.config.telemetry.username, GayFurCity.config.telemetry.password)
      c.use(Faraday::Response::RaiseError)
    end
  end

  def report!(data)
    return unless enabled?

    conn.post("/api/#{GayFurCity.config.telemetry.organization}/#{GayFurCity.config.telemetry.stream}/_json", [data].to_json)
  rescue Faraday::Error => e
    ExceptionLog.add!(e, source: "Telemetry#report!", report: false)
    TraceLogger.error("Telemetry#exception", "Failed to report: #{e.message}")
    TraceLogger.error(e)
  end

  def track(event, user:, ip: nil, **extra)
    ip = user.ip_addr if ip.nil? && user.is_a?(UserResolvable)
    time = (Time.now.to_f * 1_000_000).to_i
    event = event.to_sym
    return unless enabled?

    raise(ArgumentError, "Invalid event: #{event}") unless EVENTS.include?(event)
    raise(ArgumentError, "ip required") if ip.blank?

    content = {
      _timestamp:  time,
      level:       EVENT_LEVEL_MAP.fetch(event, "info"),
      event:       event,
      user_id:     user.id,
      ip:          ip.to_s,
      environment: Rails.env,
      version:     GayFurCity.config.version,
      server:      GayFurCity.config.server_name,
      **extra,
    }.compact

    ReportTelemetryJob.perform_later(content)
  rescue StandardError => e
    ExceptionLog.add!(e, user_id: user.id, source: "Telemetry#track")
    TraceLogger.error("Telemetry#exception", "Failed to build content: #{e.message}")
    TraceLogger.error(e)
  end

  def exception(exception, source: nil, **extra)
    time = (Time.now.to_f * 1_000_000).to_i
    return unless enabled?

    unwrapped = exception.is_a?(ActionView::Template::Error) ? exception.cause : exception
    if unwrapped.is_a?(ActiveRecord::QueryCanceled)
      extra[:sql_query] = unwrapped&.sql || "[NOT FOUND?]"
      extra[:sql_binds] = unwrapped&.binds&.map(:value_for_database)
    end

    content = {
      _timestamp:  time,
      level:       "error",
      exception:   unwrapped.class.name,
      message:     unwrapped.message,
      backtrace:   Rails.backtrace_cleaner.clean(unwrapped.backtrace || []).join("\n"),
      environment: Rails.env,
      version:     GayFurCity.config.version,
      server:      GayFurCity.config.server_name,
      source:      source,
      **extra,
    }.compact

    ReportTelemetryJob.perform_later(content)
  rescue StandardError => e
    ExceptionLog.add!(e, source: "Telemetry#exception", report: false)
    TraceLogger.error("Telemetry#exception", "Failed to build content: #{e.message}")
    TraceLogger.error(e)
  end
end

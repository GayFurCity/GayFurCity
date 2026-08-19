# frozen_string_literal: true

module Telemetry
  module_function

  EVENTS = UserEvent.categories.keys.map(&:to_sym) + %i[]
  EVENT_LEVEL_MAP = {}.freeze

  # Events are buffered in this Redis list rather than each getting its own ReportTelemetryJob,
  # so bursts of dozens-to-hundreds of events/minute collapse into one bulk request per flush
  # window instead of one HTTP request (and one GoodJob row) per event.
  QUEUE_KEY = "telemetry:pending"
  FLUSH_BATCH_SIZE = 500
  FLUSH_DELAY = 5.seconds

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
    report_bulk!([data])
  end

  def report_bulk!(data)
    return unless enabled?
    return if data.blank?

    conn.post("/api/#{GayFurCity.config.telemetry.organization}/#{GayFurCity.config.telemetry.stream}/_json", data.to_json)
  rescue Faraday::Error => e
    ExceptionLog.add!(e, source: "Telemetry#report_bulk!", report: false)
    TraceLogger.error("Telemetry#exception", "Failed to report: #{e.message}")
    TraceLogger.error(e)
  end

  # Pushes a single event onto the pending queue and (re-)schedules a flush. FlushTelemetryJob
  # caps itself to one enqueued/running instance at a time (see its good_job_control_concurrency_with),
  # so repeated calls within the same FLUSH_DELAY window just no-op instead of scheduling more jobs -
  # the first call in a burst is the only one that actually schedules work, and that one job drains
  # whatever accumulated by the time it runs.
  def enqueue!(content)
    Cache.redis.rpush(QUEUE_KEY, content.to_json)
    FlushTelemetryJob.set(wait: FLUSH_DELAY).perform_later
  end

  # Drains the pending queue in FLUSH_BATCH_SIZE chunks, sending each chunk as a single bulk
  # request. Called from FlushTelemetryJob.
  def flush!
    loop do
      batch = Cache.redis.lpop(QUEUE_KEY, FLUSH_BATCH_SIZE)
      break if batch.blank?

      report_bulk!(batch.map { |json| JSON.parse(json) })
      break if batch.size < FLUSH_BATCH_SIZE
    end
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

    enqueue!(content)
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

    enqueue!(content)
  rescue StandardError => e
    ExceptionLog.add!(e, source: "Telemetry#exception", report: false)
    TraceLogger.error("Telemetry#exception", "Failed to build content: #{e.message}")
    TraceLogger.error(e)
  end
end

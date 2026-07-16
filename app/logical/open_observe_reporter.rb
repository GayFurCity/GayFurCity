# frozen_string_literal: true

module OpenObserveReporter
  module_function

  def enabled?
    GayFurCity.config.openobserve.enabled?
  end

  def conn
    Faraday.new(GayFurCity.config.faraday_options.deep_merge(
                  url:     GayFurCity.config.openobserve.endpoint,
                  headers: { content_type: "application/json" },
                )) do |c|
      c.request(:authorization, :basic, GayFurCity.config.openobserve.username, GayFurCity.config.openobserve.password)
      c.use(Faraday::Response::RaiseError)
    end
  end

  def report!(exception, source: nil, **extra)
    return unless enabled?

    unwrapped = exception.is_a?(ActionView::Template::Error) ? exception.cause : exception
    doc = {
      _timestamp:  (Time.now.to_f * 1_000_000).to_i,
      level:       "error",
      exception:   unwrapped.class.name,
      message:     unwrapped.message,
      backtrace:   Rails.backtrace_cleaner.clean(unwrapped.backtrace || []).join("\n"),
      host:        Socket.gethostname,
      environment: Rails.env,
      version:     GitHelper.instance.local.short_commit,
      source:      source,
      **extra,
    }.compact

    conn.post("/api/#{GayFurCity.config.openobserve.organization}/#{GayFurCity.config.openobserve.stream}/_json", [doc].to_json)
  rescue Faraday::Error => e
    Rails.logger.error("[OpenObserveReporter] failed to report exception: #{e.message}")
  end
end

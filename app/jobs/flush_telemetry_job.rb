# frozen_string_literal: true

class FlushTelemetryJob < ApplicationJob
  queue_as(:low)

  # Only one flush may be enqueued/running at a time - this is what makes Telemetry.enqueue!'s
  # repeated `set(wait:).perform_later` calls act as a debounce instead of scheduling a job per event.
  good_job_control_concurrency_with(
    total_limit: 1,
    key:         -> { "FlushTelemetryJob" },
  )

  def perform
    Telemetry.flush!
  end
end

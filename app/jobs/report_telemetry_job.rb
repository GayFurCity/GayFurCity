# frozen_string_literal: true

class ReportTelemetryJob < ApplicationJob
  queue_as(:low)

  def perform(data)
    Telemetry.report!(data)
  end
end

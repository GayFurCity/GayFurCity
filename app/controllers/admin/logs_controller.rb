# frozen_string_literal: true

module Admin
  class LogsController < ApplicationController
    before_action(:ensure_application_logs_enabled, only: %i[application_logs application_status])
    before_action(:ensure_request_logs_enabled, only: %i[request_logs request_status])

    def application_logs
      load_entries(Admin::ApplicationLog.new, title: "Application Logs", status_path: application_status_admin_logs_path(format: :json))
      render(:show)
    end

    def application_status
      render_status(Admin::ApplicationLog.new)
    end

    def request_logs
      load_entries(Admin::RequestLog.new, title: "Request Logs", status_path: request_status_admin_logs_path(format: :json))
      render(:show)
    end

    def request_status
      render_status(Admin::RequestLog.new)
    end

    private

    def load_entries(log, title:, status_path:)
      @log = authorize(log, :index?)
      @entries = @log.entries(page: params[:page], limit: params[:limit])
      @title = title
      @status_path = status_path
    end

    def render_status(log)
      @log = authorize(log, :index?)
      previous_count = params[:count].to_i
      total_count = @log.total_count

      render(json: {
        total_count: total_count,
        new_lines:   [total_count - previous_count, 0].max,
      })
    end

    def ensure_application_logs_enabled
      access_denied("This feature is disabled") unless GayFurCity.config.enable_application_logs?
    end

    def ensure_request_logs_enabled
      access_denied("This feature is disabled") unless GayFurCity.config.enable_request_logs?
    end
  end
end

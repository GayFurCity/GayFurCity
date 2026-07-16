# frozen_string_literal: true

module Admin
  module LogsHelper
    include(ApplicationLogsHelper)

    def render_log_entry(log, text)
      case log
      when Admin::RequestLog
        render_request_log_entry(text)
      when Admin::PerformanceLog
        render_performance_log_entry(text)
      else
        tag.pre(format_application_log_line(text), class: "log-entry-line")
      end
    end

    private

    def render_request_log_entry(text)
      entry = JSON.parse(text)

      blocks = []
      blocks << tag.pre(format_request_log_summary(entry), class: "log-entry-line")
      blocks << render_header_details("Request Headers", entry["request_headers"])
      blocks << render_header_details("Response Headers", entry["response_headers"])
      blocks.concat(render_exception_section(entry["exception"]))
      tag.div(safe_join(blocks.compact), class: "log-entry")
    rescue JSON::ParserError
      tag.pre(text, class: "log-entry-line")
    end

    def format_request_log_summary(entry)
      lines = []
      lines << safe_join([format_request_log_time(entry["time"]), entry["method"], entry["path"], format_status(entry["status"]), format_duration(entry["duration"])].compact, " ")
      lines << "IP: #{entry['ip']}" if entry["ip"].present?
      lines << "Request ID: #{entry['request_id']}" if entry["request_id"].present?
      lines << "Request Body Size: #{entry['request_body_size']} bytes" unless entry["request_body_size"].nil?
      lines << "Total Request Size: #{entry['total_request_size']} bytes" unless entry["total_request_size"].nil?
      lines << "Response Body Size: #{entry['response_body_size']} bytes" unless entry["response_body_size"].nil?
      lines << "Total Response Size: #{entry['total_response_size']} bytes" unless entry["total_response_size"].nil?
      lines << "Referer: #{entry['referer']}" if entry["referer"].present?
      lines << "User-Agent: #{entry['user_agent']}" if entry["user_agent"].present?
      safe_join(lines, "\n")
    end

    def render_performance_log_entry(text)
      entry = JSON.parse(text)

      blocks = []
      blocks << tag.pre(format_performance_log_summary(entry), class: "log-entry-line")
      blocks << render_performance_table("Queries", entry["queries"], %w[Name SQL Cached Duration Allocations]) { |query| render_query_row(query) }
      blocks << render_performance_table("Renders", entry["renders"], %w[File Type Duration Allocations]) { |render_entry| render_render_row(render_entry) }
      tag.div(safe_join(blocks.compact), class: "log-entry")
    rescue JSON::ParserError
      tag.pre(text, class: "log-entry-line")
    end

    def format_performance_log_summary(entry)
      lines = []
      lines << safe_join([format_request_log_time(entry["time"]), "Request ID: #{entry['request_id']}"].compact, " ")
      lines << "Queries: #{entry['queries']&.size || 0}"
      lines << "Renders: #{entry['renders']&.size || 0}"
      safe_join(lines, "\n")
    end

    def render_performance_table(title, rows, column_names, &)
      return if rows.blank?

      tag.details(class: "log-entry-details", open: true) do
        safe_join([
          tag.summary("#{title} (#{rows.size})"),
          tag.table(class: "striped autofit") do
            safe_join([
              tag.thead do
                tag.tr { safe_join(column_names.map { |name| tag.th(name) }) }
              end,
              tag.tbody do
                safe_join(rows.map(&))
              end,
            ])
          end,
        ])
      end
    end

    def render_query_row(query)
      tag.tr do
        safe_join([
          tag.td(query["name"]),
          tag.td(tag.code(query["sql"])),
          tag.td(query["cached"] ? "Yes" : "No"),
          tag.td("#{query['duration']}ms"),
          tag.td(query["allocations"]),
        ])
      end
    end

    def render_render_row(render_entry)
      tag.tr do
        safe_join([
          tag.td(render_entry["file"]),
          tag.td(render_entry["type"]),
          tag.td("#{render_entry['duration']}ms"),
          tag.td(render_entry["allocations"]),
        ])
      end
    end

    def format_status(status)
      return if status.blank?

      label = [status, Rack::Utils::HTTP_STATUS_CODES[status.to_i]].compact.join(" ")
      safe_join(["-> ", tag.span(label, class: status_class(status))])
    end

    def format_duration(duration)
      return if duration.blank?

      return "(#{duration}ms)" if duration.to_f < default_user_statement_timeout

      safe_join(["(", tag.span("#{duration}ms", class: "text-red"), ")"])
    end

    def render_header_details(title, headers)
      return if headers.blank?

      tag.details(class: "log-entry-details") do
        safe_join([
          tag.summary(title),
          render_header_table(headers),
        ])
      end
    end

    def render_exception_section(exception)
      return [] if exception.blank?

      details = ["Exception:"]
      details << "  Class: #{exception['class']}" if exception["class"].present?
      details << "  Message: #{exception['message']}" if exception["message"].present?
      [tag.pre(details.join("\n"), class: "log-entry-line")]
    end

    def render_header_table(headers)
      rows = headers.sort_by { |key, _value| key.to_s }.map do |key, value|
        tag.tr do
          safe_join([
            tag.td(key),
            tag.td(render_header_value(value)),
          ])
        end
      end

      tag.table(class: "striped autofit") do
        safe_join([
          tag.thead do
            tag.tr do
              safe_join([
                tag.th("Header"),
                tag.th("Value"),
              ])
            end
          end,
          tag.tbody do
            safe_join(rows)
          end,
        ])
      end
    end

    def format_request_log_time(value)
      return value if value.blank?

      compact_time(Time.zone.parse(value))
    rescue ArgumentError
      value
    end

    def render_header_value(value)
      return hint("empty") if value.blank?

      value
    end

    def status_class(status)
      code = status.to_i

      return "text-green" if code.between?(200, 299)
      return "text-red" if code >= 400

      "hint"
    end

    def default_user_statement_timeout
      @default_user_statement_timeout ||= User.new.statement_timeout
    end
  end
end

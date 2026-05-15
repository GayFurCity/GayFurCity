# frozen_string_literal: true

require("test_helper")

module Admin
  class LogsControllerTest < ActionDispatch::IntegrationTest
    context("The admin logs controller") do
      setup do
        @owner = create(:owner_user)
        @application_path = Rails.root.join("tmp/application-log-test.log")
        @request_path = Rails.root.join("tmp/request-log-test.jsonl")
        File.write(@application_path, "oldest line\nmiddle line\nnewest line\n")
        File.write(@request_path, <<~LOGS)
          {"time":"2025-01-01T00:00:00.000000Z","request_id":"oldest","method":"GET","path":"/oldest","ip":"127.0.0.1","user_agent":"Test Agent","referer":"https://example.test/one","status":200,"duration":3200.0,"request_body_size":128,"total_request_size":256,"request_headers":{"Accept":"application/json"},"response_body_size":256,"total_response_size":320,"response_headers":{"Content-Type":"application/json"},"exception":null}
          {"time":"2025-01-01T00:00:01.000000Z","request_id":"middle","method":"POST","path":"/middle","ip":"127.0.0.2","user_agent":"Test Agent","referer":"https://example.test/two","status":302,"duration":8.25,"request_body_size":0,"total_request_size":140,"request_headers":{"Content-Type":"application/json"},"response_body_size":0,"total_response_size":76,"response_headers":{"Location":"/login"},"exception":null}
          {"time":"2025-01-01T00:00:02.000000Z","request_id":"newest","method":"DELETE","path":"/newest","ip":"127.0.0.3","user_agent":"Test Agent","referer":"https://example.test/three","status":500,"duration":1.5,"request_body_size":32,"total_request_size":196,"request_headers":{"X-Test":"1"},"response_body_size":512,"total_response_size":584,"response_headers":{"Content-Type":"text/html"},"exception":{"class":"RuntimeError","message":"boom"}}
        LOGS
        Admin::ApplicationLog.stubs(:path_for).returns(@application_path)
        Admin::RequestLog.stubs(:path_for).returns(@request_path)
        stub_env_config(:enable_application_logs, true)
        stub_env_config(:enable_request_logs, true)
      end

      teardown do
        FileUtils.rm_f(@application_path)
        FileUtils.rm_f(@request_path)
      end

      context("application action") do
        should("render the log lines from newest to oldest") do
          get_auth(application_admin_logs_path, @owner)

          assert_response(:success)
          assert_operator(@response.body.index("newest line"), :<, @response.body.index("middle line"))
          assert_operator(@response.body.index("middle line"), :<, @response.body.index("oldest line"))
          assert_includes(@response.body, @application_path.to_s)
        end

        should("render ansi colored output") do
          File.write(@application_path, "plain\n␛[1m␛[36mcyan bold␛[0m\n")

          get_auth(application_admin_logs_path, @owner)

          assert_response(:success)
          assert_includes(@response.body, "cyan bold")
          assert_includes(@response.body, "font-weight: bold; color: #66d9ef")
          assert_not_includes(@response.body, "␛[36m")
        end

        should("only respond to html") do
          get_auth(application_admin_logs_path(format: :json), @owner)

          assert_response(:not_acceptable)
        end

        should("not work when disabled") do
          stub_env_config(:enable_application_logs, false)
          get_auth(application_admin_logs_path, @owner)

          assert_response(:forbidden)
        end

        context("access control") do
          asserts do
            access.gte(User::Levels::OWNER).get(application_admin_logs_path)
          end
        end
      end

      context("application_status action") do
        should("report how many new lines were added") do
          get_auth(application_status_admin_logs_path(format: :json), @owner, params: { count: 2 })

          assert_response(:success)
          assert_equal(3, @response.parsed_body["total_count"])
          assert_equal(1, @response.parsed_body["new_lines"])
        end

        should("not work when disabled") do
          stub_env_config(:enable_application_logs, false)
          get_auth(application_status_admin_logs_path(format: :json), @owner)

          assert_response(:forbidden)
        end

        context("access control") do
          asserts do
            access.gte(User::Levels::OWNER).json.get(application_status_admin_logs_path)
          end
        end
      end

      context("request action") do
        should("render the log lines from newest to oldest") do
          get_auth(request_admin_logs_path, @owner)

          assert_response(:success)
          assert_operator(@response.body.index("/newest"), :<, @response.body.index("/middle"))
          assert_operator(@response.body.index("/middle"), :<, @response.body.index("/oldest"))
          assert_includes(@response.body, "<time ")
          assert_includes(@response.body, "title=\"2024-12-31 18:00:02 -0600\"")
          assert_includes(@response.body, "DELETE /newest -&gt; <span class=\"text-red\">500 Internal Server Error</span> (1.5ms)")
          assert_includes(@response.body, "<span class=\"hint\">302 Found</span>")
          assert_includes(@response.body, "<span class=\"text-green\">200 OK</span>")
          assert_includes(@response.body, "(<span class=\"text-red\">3200.0ms</span>)")
          assert_includes(@response.body, "Request Body Size: 0 bytes")
          assert_includes(@response.body, "Total Request Size: 140 bytes")
          assert_includes(@response.body, "Response Body Size: 0 bytes")
          assert_includes(@response.body, "Total Response Size: 76 bytes")
          assert_includes(@response.body, "<summary>Request Headers</summary>")
          assert_includes(@response.body, "<summary>Response Headers</summary>")
          assert_includes(@response.body, "<details")
          assert_not_includes(@response.body, "<details open")
          assert_includes(@response.body, "Exception:")
          assert_includes(@response.body, "<th>Header</th>")
          assert_includes(@response.body, "<th>Value</th>")
          assert_includes(@response.body, "<td>X-Test</td>")
          assert_includes(@response.body, "<td>text/html</td>")
          assert_not_includes(@response.body, "{\"time\":")
          assert_includes(@response.body, @request_path.to_s)
        end

        should("only respond to html") do
          get_auth(request_admin_logs_path(format: :json), @owner)

          assert_response(:not_acceptable)
        end

        should("not work when disabled") do
          stub_env_config(:enable_request_logs, false)
          get_auth(request_admin_logs_path, @owner)

          assert_response(:forbidden)
        end

        context("access control") do
          asserts do
            access.gte(User::Levels::OWNER).get(request_admin_logs_path)
          end
        end
      end

      context("request_status action") do
        should("report how many new lines were added") do
          get_auth(request_status_admin_logs_path(format: :json), @owner, params: { count: 2 })

          assert_response(:success)
          assert_equal(3, @response.parsed_body["total_count"])
          assert_equal(1, @response.parsed_body["new_lines"])
        end

        should("not work when disabled") do
          stub_env_config(:enable_request_logs, false)
          get_auth(request_status_admin_logs_path(format: :json), @owner)

          assert_response(:forbidden)
        end

        context("access control") do
          asserts do
            access.gte(User::Levels::OWNER).json.get(request_status_admin_logs_path)
          end
        end
      end
    end
  end
end

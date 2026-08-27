# frozen_string_literal: true

require("test_helper")

class DbExportsControllerTest < ActionDispatch::IntegrationTest
  context("The db exports controller") do
    context("index action") do
      context("when disabled") do
        setup do
          AdminConfig.any_instance.stubs(:db_exports_enabled).returns(false)
        end

        should("respond with 501") do
          get(db_exports_path)

          assert_response(:not_implemented)
        end
      end

      context("when enabled") do
        setup do
          AdminConfig.any_instance.stubs(:db_exports_enabled).returns(true)
        end

        should("render for anonymous users") do
          get(db_exports_path)

          assert_response(:success)
        end

        should("list the available exports") do
          create(:db_export, name: "posts", date: "2026-08-18")
          get(db_exports_path)

          assert_select("body", /posts/)
        end

        # TableBuilder columns defined with a single-expression block (as opposed to a do...end
        # block with an embedded ERB output tag) never render - see app/views/db_exports/index.html.erb.
        should("render the date, size, and updated columns") do
          create(:db_export, name: "posts", date: "2026-08-18", file_size: 2048)
          get(db_exports_path)

          assert_select("body", /2026-08-18/)
          assert_select("body", /2 KB/)
          assert_select("td.updated-column time")
        end

        should("group exports into a details section per date, with only the most recent expanded") do
          create(:db_export, name: "posts", date: "2026-08-18")
          create(:db_export, name: "posts", date: "2026-08-17")
          get(db_exports_path)

          assert_select("details.db-export-date-section", count: 2)
          assert_select("details.db-export-date-section[open]", count: 1) do
            assert_select("summary", "2026-08-18")
          end
        end

        should("render a columns table for exports that have column metadata") do
          create(:db_export, name: "posts", date: "2026-08-18", columns: { "id" => "bigint", "title" => "text" })
          get(db_exports_path)

          assert_select("details.db-export-columns table.db-export-columns-table") do
            assert_select("td code", "id")
            assert_select("td code", "bigint")
          end
        end

        should("not render a columns toggle for exports without column metadata") do
          create(:db_export, name: "posts", date: "2026-08-18", columns: {})
          get(db_exports_path)

          assert_select("details.db-export-columns", count: 0)
        end

        should("render a JSON array with export metadata") do
          export = create(:db_export, name: "posts", date: "2026-08-18", file_size: 2048, checksum: "a" * 64)
          get(db_exports_path(format: :json))

          assert_response(:success)

          body = response.parsed_body
          entry = body.find { |e| e["name"] == "posts" }

          assert_equal("2026-08-18/posts.csv.gz", entry["file_name"])
          assert_equal(2048, entry["file_size"])
          assert_equal("a" * 64, entry["checksum"])
          assert_equal(export.url, entry["url"])
        end
      end
    end
  end
end

# frozen_string_literal: true

require("test_helper")

class DbExportJobTest < ActiveSupport::TestCase
  def read_export(name)
    export = DbExport.find_by(name: name)
    export.storage_manager.open(export.storage_manager.db_export_path(export.file_name)) do |file|
      Zlib::GzipReader.new(file).read
    end
  end

  context("#perform") do
    should("do nothing when disabled") do
      Config.any_instance.stubs(:db_exports_enabled).returns(false)

      assert_no_difference(-> { DbExport.count }) do
        DbExportJob.perform_now
      end
    end

    context("when enabled") do
      setup do
        Config.any_instance.stubs(:db_exports_enabled).returns(true)
      end

      should("record a DbExport row for each configured export") do
        assert_difference(-> { DbExport.count }, DbExportJob::EXPORTS.size) do
          DbExportJob.perform_now
        end
      end

      should("record the file size, checksum, and columns") do
        DbExportJob.perform_now

        export = DbExport.find_by(name: "tags")

        assert_operator(export.file_size, :>, 0)
        assert_equal(64, export.checksum.length)
        # jsonb doesn't preserve key insertion order, so compare as a set.
        assert_equal(
          %w[id name post_count category related_tags related_tags_updated_at created_at updated_at is_locked].sort,
          export.columns.keys.sort,
        )
        assert_equal("bigint", export.columns["id"])
        assert_equal("character varying", export.columns["name"])
      end

      should("reuse the existing row for the same day on a subsequent run") do
        DbExportJob.perform_now

        assert_no_difference(-> { DbExport.count }) do
          DbExportJob.perform_now
        end
      end

      should("continue generating other exports when one fails") do
        ActiveRecord::Base.connection.stubs(:reconnect!)

        # Mocha's `returns`/`raises` only take static values, not a block to compute a per-call
        # result - reopen the method directly instead, so every export but posts still runs through
        # the real implementation, and restore it afterwards regardless of outcome.
        original_write_csv_gz = DbExportJob.instance_method(:write_csv_gz)
        DbExportJob.send(:define_method, :write_csv_gz) do |query, file|
          raise(StandardError, "boom") if query.include?("public.posts")
          original_write_csv_gz.bind(self).call(query, file)
        end

        begin
          DbExportJob.perform_now
        ensure
          DbExportJob.send(:define_method, :write_csv_gz, original_write_csv_gz)
        end

        assert_not(DbExport.exists?(name: "posts"))
        assert(DbExport.exists?(name: "tags"))
      end

      should("export tag data") do
        create(:tag, name: "test_export_tag")
        DbExportJob.perform_now

        assert_includes(read_export("tags"), "test_export_tag")
      end

      should("export pool data") do
        create(:pool, name: "test_export_pool")
        DbExportJob.perform_now

        assert_includes(read_export("pools"), "test_export_pool")
      end
    end
  end
end

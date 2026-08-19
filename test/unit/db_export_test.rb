# frozen_string_literal: true

require("test_helper")

class DbExportTest < ActiveSupport::TestCase
  context("validations") do
    should("require a name") do
      assert_not(build(:db_export, name: nil).valid?)
    end

    should("require a date") do
      assert_not(build(:db_export, date: nil).valid?)
    end

    should("require a unique name scoped to date") do
      create(:db_export, name: "posts", date: "2026-08-18")

      assert_not(build(:db_export, name: "posts", date: "2026-08-18").valid?)
      assert_predicate(build(:db_export, name: "posts", date: "2026-08-17"), :valid?)
    end
  end

  context("#file_name") do
    should("nest the gzipped csv file name under a directory for its date") do
      export = build(:db_export, name: "posts", date: "2026-08-18")

      assert_equal("2026-08-18/posts.csv.gz", export.file_name)
    end
  end

  context("#url") do
    should("delegate to the storage manager with the file name") do
      export = build(:db_export, name: "posts", date: "2026-08-18")

      assert_equal(export.storage_manager.db_export_url(export.file_name), export.url)
    end
  end

  context("#archived?") do
    should("be true for the 1st of the month") do
      assert_predicate(build(:db_export, date: "2026-08-01"), :archived?)
    end

    should("be false for any other day") do
      assert_not(build(:db_export, date: "2026-08-02").archived?)
    end
  end

  context(".expired") do
    should("include exports older than MAX_AGE") do
      export = create(:db_export, date: (DbExport::MAX_AGE + 1.day).ago.to_date)

      assert_includes(DbExport.expired, export)
    end

    should("exclude exports within MAX_AGE") do
      export = create(:db_export, date: Date.current)

      assert_not_includes(DbExport.expired, export)
    end

    should("exclude 1st-of-the-month exports even when older than MAX_AGE") do
      export = create(:db_export, date: (DbExport::MAX_AGE + 1.month).ago.to_date.beginning_of_month)

      assert_not_includes(DbExport.expired, export)
    end
  end

  context(".prune_expired!") do
    should("delete expired rows and their stored files") do
      export = create(:db_export, date: (DbExport::MAX_AGE + 1.day).ago.to_date)
      export.storage_manager.store_db_export(StringIO.new("data"), export.file_name)

      DbExport.prune_expired!

      assert_not(DbExport.exists?(export.id))
      assert_not(export.storage_manager.exists?(export.storage_manager.db_export_path(export.file_name)))
    end

    should("remove the now-empty date directory") do
      date = (DbExport::MAX_AGE + 1.day).ago.to_date
      export = create(:db_export, date: date)
      export.storage_manager.store_db_export(StringIO.new("data"), export.file_name)
      dir = export.storage_manager.db_export_dir_path(date.iso8601)

      DbExport.prune_expired!

      assert_not(Dir.exist?(dir))
    end

    should("leave the date directory alone if something else still lives there") do
      date = (DbExport::MAX_AGE + 1.day).ago.to_date
      expired = create(:db_export, name: "posts", date: date)
      expired.storage_manager.store_db_export(StringIO.new("data"), expired.file_name)
      dir = expired.storage_manager.db_export_dir_path(date.iso8601)
      FileUtils.touch("#{dir}/unrelated-file")

      DbExport.prune_expired!

      assert(Dir.exist?(dir))
    end

    should("leave unexpired and archived rows alone") do
      kept = create(:db_export, date: Date.current)
      archived = create(:db_export, name: "archived", date: (DbExport::MAX_AGE + 1.month).ago.to_date.beginning_of_month)

      DbExport.prune_expired!

      assert(DbExport.exists?(kept.id))
      assert(DbExport.exists?(archived.id))
    end
  end
end

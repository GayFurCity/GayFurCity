# frozen_string_literal: true

# A row per (table, day) that DbExportJob has generated a public CSV export for. Rows/files older
# than MAX_AGE are pruned by DbExportJob after each run, except the 1st-of-the-month row for a
# given table, which is kept indefinitely as a permanent monthly snapshot.
class DbExport < ApplicationRecord
  MAX_AGE = 4.days

  validates(:name, presence: true)
  validates(:date, presence: true)
  validates(:name, uniqueness: { scope: :date })

  def self.expired
    where(date: ...MAX_AGE.ago.to_date).where("EXTRACT(DAY FROM date) != 1")
  end

  def self.prune_expired!
    dates = Set.new
    expired.find_each do |export|
      export.storage_manager.delete_db_export(export.file_name)
      dates << export.date
      export.destroy!
    end

    # Every export for a given date expires together (day-of-month is a property of the date
    # itself, not the individual row), so once its rows are gone the date directory is empty -
    # delete_db_export_dir is a no-op if anything else still lives there.
    dates.each { |date| GayFurCity.config.storage_manager.instance.delete_db_export_dir(date.iso8601) }
  end

  def file_name
    "#{date.iso8601}/#{name}.csv.gz"
  end

  def url
    storage_manager.db_export_url(file_name)
  end

  def archived?
    date.day == 1
  end

  def storage_manager
    GayFurCity.config.storage_manager.instance
  end
end

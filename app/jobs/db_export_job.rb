# frozen_string_literal: true

class DbExportJob < ApplicationJob
  queue_as(:low)

  EXPORTS = Rails.root.glob("db/export/*.sql").to_h do |path|
    [File.basename(path, ".sql"), File.read(path)]
  end.freeze

  # These are read from eris' database instead of ours
  ERIS_EXPORTS = Rails.root.glob("db/export/eris/*.sql").to_h do |path|
    ["eris_#{File.basename(path, '.sql')}", File.read(path)]
  end.freeze

  def perform
    return unless AdminConfig.db_exports_enabled?

    date = Date.current
    EXPORTS.each do |name, query|
      generate_export(name, query, date)
    end
    generate_eris_exports(date)

    DbExport.prune_expired!
  end

  private

  def generate_eris_exports(date)
    return if GayFurCity.config.eris_database_url.blank? || eris_exports.empty?

    conn = PG.connect(GayFurCity.config.eris_database_url)
    eris_exports.each do |name, query|
      generate_export(name, query, date, conn)
    end
  rescue PG::Error => e
    Rails.logger.error("DbExportJob: Failed to connect to the eris database: #{e.message}")
  ensure
    conn&.close
  end

  def eris_exports
    ERIS_EXPORTS
  end

  def generate_export(name, query, date, conn = nil)
    Rails.logger.info("DbExportJob: Generating #{name} export")
    conn ||= ActiveRecord::Base.connection.raw_connection

    export = DbExport.find_or_initialize_by(name: name, date: date)
    columns = export_columns(conn, query)

    file = Tempfile.new(["#{name}-export", ".csv.gz"], binmode: true)
    write_csv_gz(conn, query, file)
    file.rewind

    checksum = Digest::SHA256.file(file.path).hexdigest
    storage_manager.store_db_export(file, export.file_name)
    export.update!(file_size: file.size, checksum: checksum, columns: columns)

    Rails.logger.info("DbExportJob: Finished #{name} export (#{ActiveSupport::NumberHelper.number_to_human_size(file.size)})")
  rescue StandardError => e
    Rails.logger.error("DbExportJob: Failed to generate #{name} export: #{e.message}")
    ActiveRecord::Base.connection.reconnect!
  ensure
    file&.close!
  end

  def export_columns(conn, query)
    result = conn.exec("SELECT * FROM (#{query}) db_export_columns LIMIT 0")
    oids = result.nfields.times.map { |i| result.ftype(i) }
    type_names = resolve_type_names(conn, oids)
    result.fields.each_with_index.to_h { |field, i| [field, type_names[oids[i]]] }
  ensure
    result&.clear
  end

  def resolve_type_names(conn, oids)
    return {} if oids.empty?

    types = conn.exec_params("SELECT oid, format_type(oid, NULL) AS type_name FROM pg_type WHERE oid = ANY($1::oid[])", ["{#{oids.uniq.join(',')}}"])
    types.to_h { |row| [row["oid"].to_i, row["type_name"]] }
  ensure
    types&.clear
  end

  def write_csv_gz(conn, query, file)
    gz = Zlib::GzipWriter.new(file)
    conn.exec("SET statement_timeout = 0")
    conn.copy_data("COPY (#{query}) TO STDOUT WITH CSV HEADER") do
      while (row = conn.get_copy_data)
        gz.write(row)
      end
    end
  ensure
    conn&.exec("RESET statement_timeout")
    gz&.finish
  end

  def storage_manager
    GayFurCity.config.storage_manager.instance
  end
end

# frozen_string_literal: true

require("pg")

class SystemInfo
  class DbSize
    Row = Struct.new(:schema, :table, :size) do
      def pretty_size
        Helpers.number_to_human_size(size)
      end
    end

    attr_reader(:results, :skipped)

    def initialize
      @results = {}.to_open_hash
      @skipped = []
    end

    def sorted_results
      @sorted_results ||= results.sort_by { |_k, v| -v.first.size }.to_h { |k, v| [k, v.sort_by(&:size).reverse] }
    end

    def connect(database)
      raise(LocalJumpError, "block required") unless block_given?
      config = ActiveRecord::Base.connection_db_config.configuration_hash
      connection = PG.connect(host: config[:host], port: config[:port], user: config[:username], password: config[:password], dbname: database)
      begin
        yield(connection)
      ensure
        connection&.close
      end
    end

    def databases
      @databases ||= connect("postgres") do |conn|
        conn.exec("SELECT datname FROM pg_database WHERE datistemplate = false").pluck("datname")
      end
    end

    def load
      databases.each do |name|
        connect(name) do |conn|
          rows = conn.exec("SELECT schemaname, relname, pg_total_relation_size(relid) AS size FROM pg_catalog.pg_statio_user_tables ORDER BY pg_total_relation_size(relid) DESC").map do |row|
            Row.new(row["schemaname"], row["relname"], row["size"].to_i)
          end
          if rows.empty?
            @skipped << [name, "no tables"]
          else
            @results[name] = [Row.new(nil, "total", rows.sum(&:size)), *rows]
          end
        rescue PG::Error => e
          @skipped << [name, "#{e.name}: #{e.message}"]
        end
      end
      self
    end
  end
end

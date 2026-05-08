# frozen_string_literal: true

module ActiveRecordExtensions
  extend(ActiveSupport::Concern)

  module ClassMethods
    def without_timeout
      original = get_statement_timeout
      connection.execute("SET STATEMENT_TIMEOUT = 0") unless Rails.env.test?
      yield
    ensure
      connection.execute("SET STATEMENT_TIMEOUT = #{original}") unless Rails.env.test?
    end

    def with_timeout(time, default_value = nil)
      original = get_statement_timeout
      connection.execute("SET STATEMENT_TIMEOUT = #{time}") unless Rails.env.test?
      yield
    rescue ::ActiveRecord::StatementInvalid => e
      GayFurCity::Logger.log(e, expected: true)
      default_value
    ensure
      connection.execute("SET STATEMENT_TIMEOUT = #{original}") unless Rails.env.test?
    end

    def get_statement_timeout
      ApplicationRecord.connection.select_one("SELECT setting FROM pg_settings WHERE name = 'statement_timeout'")["setting"].to_i
    end

    # CrossJoinLateral, LeftJoinLateral, nil
    def unnest(column, name: column.singularize, type: Arel::Nodes::LeftJoinLateral)
      function = Arel::Nodes::NamedFunction.new("unnest", [arel(column)], name)
      return function if type.nil?
      joins(type.new(
              function,
              Arel::Nodes::On.new(Arel.sql("TRUE")),
            ))
    end
  end
end

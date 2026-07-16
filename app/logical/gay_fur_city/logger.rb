# frozen_string_literal: true

module GayFurCity
  class Logger
    def self.log(exception, expected: false, **params)
      if expected
        Rails.logger.info("#{exception.class}: #{exception.message}")
      else
        backtrace = Rails.backtrace_cleaner.clean(exception.backtrace).join("\n")
        Rails.logger.error("#{exception.class}: #{exception.message}\n#{backtrace}")
      end

      OpenObserveReporter.report!(exception, **params) unless expected
    end

    def self.initialize(user)
      add_attributes("user.id" => user.id, "user.name" => user.name)
    end

    def self.add_attributes(**)
      return unless defined?(::NewRelic)

      ::NewRelic::Agent.add_custom_attributes(**)
    end
  end
end

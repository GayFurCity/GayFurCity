# frozen_string_literal: true

module Sources
  module Bad
    class Local < Base
      def bad?
        return false if ENV.fetch("SEEDING", false).to_s.truthy? || Rails.env.development? # everything will be sourced to the production instance
        true
      end

      def self.match?(url)
        url.domain == GayFurCity.config.domain
      end
    end
  end
end

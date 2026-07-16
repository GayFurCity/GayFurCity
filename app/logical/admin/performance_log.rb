# frozen_string_literal: true

module Admin
  class PerformanceLog < ApplicationLog
    def self.path_for(environment = Rails.env)
      Rails.root.join("log", "performance.#{environment}.jsonl")
    end
  end
end

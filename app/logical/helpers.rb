# frozen_string_literal: true

module Helpers
  def self.method_missing
    include(Singleton)
    include(ActionController::Base.helpers)

    class << self
      delegate_missing_to(:instance)
    end
  end
end

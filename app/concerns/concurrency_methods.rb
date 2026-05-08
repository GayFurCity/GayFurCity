# frozen_string_literal: true

module ConcurrencyMethods
  extend(ActiveSupport::Concern)

  module ClassMethods
    def parallel_find_each(**, &)
      # XXX We may deadlock if a transaction is open; do a non-parallel each.
      return find_each(&) if connection.transaction_open?

      find_in_batches(error_on_ignore: true, **) do |batch|
        batch.parallel_each(&)
      end
    end
  end
end

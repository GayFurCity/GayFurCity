# frozen_string_literal: true

class AddReasonToBulkUpdateRequests < ExtendedMigration[8.1]
  def change
    add_column(:bulk_update_requests, :reason, :text)
  end
end

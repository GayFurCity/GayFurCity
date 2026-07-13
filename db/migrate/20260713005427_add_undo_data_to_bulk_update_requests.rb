# frozen_string_literal: true

class AddUndoDataToBulkUpdateRequests < ExtendedMigration[7.1]
  def change
    add_column(:bulk_update_requests, :undo_data, :jsonb, null: false, default: [])
  end
end

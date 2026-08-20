# frozen_string_literal: true

class BulkUpdateRequestImportJob < ApplicationJob
  queue_as(:tags)

  def perform(import_id)
    import = BulkUpdateRequestImport.find_by(id: import_id)
    return unless import

    import.process!
  end
end

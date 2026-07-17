# frozen_string_literal: true

class BulkUpdateRequestUndoJob < ApplicationJob
  queue_as(:tags)
  good_job_control_concurrency_with(total_limit: 1, key: -> { "BulkUpdateRequestUndoJob-#{arguments[0].id}" })

  def perform(bur, user)
    bur.process_undo!(user)
  end
end

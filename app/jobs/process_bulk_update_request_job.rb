# frozen_string_literal: true

class ProcessBulkUpdateRequestJob < ApplicationJob
  queue_as(:tags)
  good_job_control_concurrency_with(total_limit: 1, key: -> { "ProcessBulkUpdateRequestJob-#{arguments[0].id}" })

  def perform(bur, approver, update_topic)
    bur.process!(approver, update_topic: update_topic)
  end
end

# frozen_string_literal: true

class IndexUpdateJob < ApplicationJob
  queue_as(:high)
  good_job_control_concurrency_with(enqueue_limit: 1, key: -> { "IndexUpdateJob-#{arguments[0]}-#{arguments[1]}" })

  def perform(klass, id)
    obj = klass.constantize.find(id)
    obj.document_store.update_index
  rescue ActiveRecord::RecordNotFound
    # Do nothing
  end
end

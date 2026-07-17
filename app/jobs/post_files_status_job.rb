# frozen_string_literal: true

class PostFilesStatusJob < ApplicationJob
  queue_as(:default)

  good_job_control_concurrency_with(total_limit: 1)
  retry_on(StandardError, attempts: 4)

  def perform
    PostFilesStatus.clear_cache
    PostFilesStatus.load!
  end
end

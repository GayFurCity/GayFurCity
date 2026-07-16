# frozen_string_literal: true

class ApplicationJob < ActiveJob::Base
  class JobError < StandardError; end
  # Automatically retry jobs that encountered a deadlock
  retry_on(ActiveRecord::Deadlocked)

  # Most jobs are safe to ignore if the underlying records are no longer available
  # discard_on ActiveJob::DeserializationError

  around_perform do |job, block|
    tags = { job_class: job.class.name }
    Yabeda.jobs.executions.increment(tags)
    Yabeda.jobs.runtime.measure(tags) do
      block.call
    rescue StandardError => e
      Yabeda.jobs.failures.increment(tags)
      GayFurCity::Logger.log(e, source: "Job: #{job.class.name}")
      raise
    end
  end
end

# frozen_string_literal: true

class ApplicationJob < ActiveJob::Base
  include(GoodJob::ActiveJobExtensions::Concurrency)

  # Rails 7.2+'s :default enqueue_after_transaction_commit keeps existing behavior for adapters
  # that don't opt in, but the :test adapter opts in by default, deferring every perform_later
  # call until its enclosing DB transaction commits. Since job call sites here weren't designed
  # around that assumption (many ride along inside an in-progress transaction that may still
  # roll back), keep enqueuing immediately everywhere, matching pre-7.2 behavior.
  self.enqueue_after_transaction_commit = false

  class JobError < StandardError; end
  # Automatically retry jobs that encountered a deadlock
  retry_on(ActiveRecord::Deadlocked)

  # Most jobs are safe to ignore if the underlying records are no longer available
  # discard_on ActiveJob::DeserializationError

  # GoodJob orders jobs by `priority ASC NULLS LAST` (lower number = runs first), unlike Sidekiq's
  # weighted-queue random selection. This approximates the old queue weights
  # (low/variants/iqdb/followers: 1, tags: 2, default: 3, high: 5) as a fixed priority ordering.
  QUEUE_PRIORITIES = { high: -20, default: 0, tags: 10 }.freeze

  before_enqueue do |job|
    job.priority ||= QUEUE_PRIORITIES.fetch(job.queue_name.to_sym, 20)
  end

  around_perform do |job, block|
    metrics = Metrics.enabled?
    tags = { job_class: job.class.name }
    Yabeda.jobs.executions.increment(tags) if metrics

    perform = -> do
      block.call
    rescue StandardError => e
      Yabeda.jobs.failures.increment(tags) if metrics
      GayFurCity::Logger.log(e, source: "Job: #{job.class.name}")
      raise
    end

    metrics ? Yabeda.jobs.runtime.measure(tags, &perform) : perform.call
  end
end

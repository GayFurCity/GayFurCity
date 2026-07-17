# frozen_string_literal: true

class TagImplicationJob < ApplicationJob
  queue_as(:tags)
  good_job_control_concurrency_with(total_limit: 1, key: -> { "TagImplicationJob-#{arguments[0]}" })

  def perform(*args)
    ti = TagImplication.find(args[0])
    ti.process!(args[2], update_topic: args[1])
  end
end

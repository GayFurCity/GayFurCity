# frozen_string_literal: true

class TagAliasJob < ApplicationJob
  queue_as(:tags)
  good_job_control_concurrency_with(total_limit: 1, key: -> { "TagAliasJob-#{arguments[0]}" })

  def perform(*args)
    ta = TagAlias.find(args[0])
    ta.process!(args[2], update_topic: args[1])
  end
end

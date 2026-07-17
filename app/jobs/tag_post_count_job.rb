# frozen_string_literal: true

class TagPostCountJob < ApplicationJob
  queue_as(:tags)
  good_job_control_concurrency_with(total_limit: 1, key: -> { "TagPostCountJob-#{arguments[0]}" })

  def perform(*args)
    tag = Tag.find(args[0])

    tag.fix_post_count
  end
end

# frozen_string_literal: true

class AiCheckJob < ApplicationJob
  queue_as(:high)
  good_job_control_concurrency_with(enqueue_limit: 1, key: -> { "AiCheckJob-#{arguments[0].id}" })

  def perform(post)
    post.ai_check!
  end
end

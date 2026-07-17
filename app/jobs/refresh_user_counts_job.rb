# frozen_string_literal: true

class RefreshUserCountsJob < ApplicationJob
  queue_as(:default)

  good_job_control_concurrency_with(total_limit: 1, key: -> { "RefreshUserCountsJob-#{arguments[0].id}" })

  def perform(user)
    user.refresh_counts!
  end
end

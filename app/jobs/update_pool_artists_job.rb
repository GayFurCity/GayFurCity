# frozen_string_literal: true

class UpdatePoolArtistsJob < ApplicationJob
  queue_as(:tags)
  good_job_control_concurrency_with(total_limit: 1, key: -> { "UpdatePoolArtistsJob-#{arguments[0]}" })

  def perform(*args)
    post = Post.find(args[0])

    post.update_pool_artists!
  end
end

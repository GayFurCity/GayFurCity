# frozen_string_literal: true

class ErisUpdateJob < ApplicationJob
  queue_as(:eris)

  # ErisProxy::Error covers both a transient upstream outage (worth retrying) and a post whose
  # file can never produce a thumbnail (not worth retrying) - there's no way to tell them apart
  # here, so retry with backoff a bounded number of times rather than forever.
  retry_on(ErisProxy::Error, wait: :polynomially_longer, attempts: 10)

  def perform(post_id)
    post = Post.find_by(id: post_id)
    return unless post

    ErisProxy.update_post(post)
  end
end

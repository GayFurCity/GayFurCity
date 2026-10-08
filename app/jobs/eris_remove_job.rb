# frozen_string_literal: true

class ErisRemoveJob < ApplicationJob
  queue_as(:eris)

  def perform(post_id)
    ErisProxy.remove_post(post_id)
  end
end

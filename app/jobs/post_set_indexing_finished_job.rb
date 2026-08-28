# frozen_string_literal: true

class PostSetIndexingFinishedJob < ApplicationJob
  queue_as(:default)

  def perform(batch, _params)
    PostSet.where(id: batch.properties[:post_set_id]).update_all(is_indexing: false)
  end
end

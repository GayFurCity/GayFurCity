# frozen_string_literal: true

class PoolIndexingFinishedJob < ApplicationJob
  queue_as(:default)

  def perform(batch, _params)
    Pool.where(id: batch.properties[:pool_id]).update_all(is_indexing: false)
  end
end

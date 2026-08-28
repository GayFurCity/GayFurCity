# frozen_string_literal: true

class PoolSyncJob < ApplicationJob
  queue_as(:default)

  def perform(pool_id, updater, added_ids: [], removed_ids: [])
    pool = Pool.find(pool_id)

    GoodJob::Batch.enqueue(on_finish: PoolIndexingFinishedJob, pool_id: pool_id) do
      Post.where(id: added_ids).find_each do |post|
        post.add_pool!(pool, updater)
        post.save
      end

      Post.where(id: removed_ids).find_each do |post|
        post.remove_pool!(pool, updater)
        post.save
      end
    end

    pool.update_artists!
  rescue ActiveRecord::RecordNotFound
    # Pool was deleted; nothing to do.
  end
end

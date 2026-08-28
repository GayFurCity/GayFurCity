# frozen_string_literal: true

class PostSetSyncJob < ApplicationJob
  queue_as(:default)

  def perform(post_set_id, updater, added_ids: [], removed_ids: [])
    post_set = PostSet.find(post_set_id)

    GoodJob::Batch.enqueue(on_finish: PostSetIndexingFinishedJob, post_set_id: post_set_id) do
      Post.where(id: added_ids).find_each do |post|
        post.add_set!(post_set, updater, force: true)
        post.save
      end

      Post.where(id: removed_ids).find_each do |post|
        post.remove_set!(post_set, updater)
        post.save
      end
    end
  rescue ActiveRecord::RecordNotFound
    # Set was deleted; nothing to do.
  end
end

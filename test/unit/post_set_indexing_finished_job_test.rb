# frozen_string_literal: true

require("test_helper")

class PostSetIndexingFinishedJobTest < ActiveSupport::TestCase
  context("#perform") do
    setup do
      @set = create(:post_set)
      @set.update_column(:is_indexing, true)

      batch = GoodJob::Batch.new(post_set_id: @set.id)
      batch.save

      # Reload so this goes through the same serialize/deserialize round-trip as a real callback.
      @batch = GoodJob::Batch.find(batch.id)
    end

    should("clear is_indexing on the referenced set") do
      PostSetIndexingFinishedJob.perform_now(@batch, { event: :finish })

      assert_not(@set.reload.is_indexing?)
    end

    should("do nothing when the set no longer exists") do
      missing_batch = GoodJob::Batch.new(post_set_id: PostSet.maximum(:id).to_i + 1)
      missing_batch.save

      assert_nothing_raised { PostSetIndexingFinishedJob.perform_now(GoodJob::Batch.find(missing_batch.id), { event: :finish }) }
    end
  end
end

# frozen_string_literal: true

require("test_helper")

class PoolIndexingFinishedJobTest < ActiveSupport::TestCase
  context("#perform") do
    setup do
      @pool = create(:pool)
      @pool.update_column(:is_indexing, true)

      batch = GoodJob::Batch.new(pool_id: @pool.id)
      batch.save

      # Reload so this goes through the same serialize/deserialize round-trip as a real callback.
      @batch = GoodJob::Batch.find(batch.id)
    end

    should("clear is_indexing on the referenced pool") do
      PoolIndexingFinishedJob.perform_now(@batch, { event: :finish })

      assert_not(@pool.reload.is_indexing?)
    end

    should("do nothing when the pool no longer exists") do
      missing_batch = GoodJob::Batch.new(pool_id: Pool.maximum(:id).to_i + 1)
      missing_batch.save

      assert_nothing_raised { PoolIndexingFinishedJob.perform_now(GoodJob::Batch.find(missing_batch.id), { event: :finish }) }
    end
  end
end

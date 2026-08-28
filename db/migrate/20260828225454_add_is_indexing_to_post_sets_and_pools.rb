# frozen_string_literal: true

class AddIsIndexingToPostSetsAndPools < ExtendedMigration[8.1]
  def change
    add_column(:post_sets, :is_indexing, :boolean, null: false, default: false)
    add_column(:pools, :is_indexing, :boolean, null: false, default: false)
  end
end

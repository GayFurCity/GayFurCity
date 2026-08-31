# frozen_string_literal: true

class RemovePoolIsDeleted < ActiveRecord::Migration[6.1]
  def change
    remove_column(:pools, :is_deleted, :boolean, default: false, null: false)
    remove_column(:pool_versions, :is_deleted, :boolean,default: false, null: false)
  end
end

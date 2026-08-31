# frozen_string_literal: true

class DropUserStatuses < ActiveRecord::Migration[7.1]
  def change
    drop_table(:user_statuses) do |t|
      t.integer(:user_id, null: false)
      t.integer(:post_count, default: 0, null: false)
      t.integer(:post_deleted_count, default: 0, null: false)
      t.integer(:post_update_count, default: 0, null: false)
      t.integer(:post_flag_count, default: 0, null: false)
      t.integer(:favorite_count, default: 0, null: false)
      t.integer(:wiki_edit_count, default: 0, null: false)
      t.integer(:note_count, default: 0, null: false)
      t.integer(:forum_post_count, default: 0, null: false)
      t.integer(:comment_count, default: 0, null: false)
      t.integer(:pool_edit_count, default: 0, null: false)
      t.integer(:set_count, default: 0, null: false)
      t.integer(:artist_edit_count, default: 0, null: false)
      t.integer(:own_post_replaced_count, default: 0)
      t.integer(:own_post_replaced_penalize_count, default: 0)
      t.integer(:post_replacement_rejected_count, default: 0)
      t.integer(:ticket_count, default: 0, null: false)
      t.timestamps
      t.index(:user_id, unique: true)
    end
  end
end

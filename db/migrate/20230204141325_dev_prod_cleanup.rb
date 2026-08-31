# frozen_string_literal: true

class DevProdCleanup < ActiveRecord::Migration[7.0]
  disable_ddl_transaction!

  def change
    drop_table(:janitor_trials, id: :integer) do |t|
      t.integer(:creator_id, null: false)
      t.integer(:user_id, null: false, index: true)
      t.integer(:original_level)
      t.timestamps(null: true)
      t.string(:status, null: false, default: "active")
    end

    reversible do |r|
      r.up { execute("DROP TYPE IF EXISTS post_status") } # no info to reconstruct type
    end
    remove_index(:users, "(lower(name)) gin_trgm_ops", using: :gin, algorithm: :concurrently, name: "index_users_on_name_trgm")
  end
end

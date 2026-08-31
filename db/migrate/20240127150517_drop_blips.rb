# frozen_string_literal: true

class DropBlips < ActiveRecord::Migration[7.0]
  def change
    drop_table(:blips) do |t|
      t.inet(:creator_ip_addr, null: false)
      t.integer(:creator_id, null: false)
      t.string(:body, null: false)
      t.integer(:response_to)
      t.boolean(:is_hidden, default: false)
      t.timestamps
      t.integer(:warning_type)
      t.integer(:warning_user_id)
      t.integer(:updater_id)
      t.foreign_key(:users, column: :updater_id)
      t.index("lower((body)::text) gin_trgm_ops", name: "index_blips_on_lower_body_trgm", using: :gin)
      t.index("to_tsvector('english'::regconfig, (body)::text)", name: "index_blips_on_to_tsvector_english_body", using: :gin)
    end

    remove_column(:user_statuses, :blip_count, :integer, default: 0)
  end
end

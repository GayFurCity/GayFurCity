# frozen_string_literal: true

class CreateBulkUpdateRequestImports < ExtendedMigration[8.1]
  def change
    create_table(:bulk_update_request_imports) do |t|
      t.references(:creator, foreign_key: { to_table: :users }, null: false)
      t.inet(:creator_ip_addr, null: false)
      t.references(:updater, foreign_key: { to_table: :users }, null: false)
      t.inet(:updater_ip_addr, null: false)
      t.references(:forum_topic, foreign_key: true)
      t.text(:script, null: false)
      t.string(:status, null: false, default: "pending", index: true)
      t.text(:status_message)
      t.timestamps
    end
  end
end

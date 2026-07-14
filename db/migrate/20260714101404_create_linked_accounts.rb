# frozen_string_literal: true

class CreateLinkedAccounts < ActiveRecord::Migration[7.1]
  def change
    create_table(:linked_accounts) do |t|
      t.references(:user, foreign_key: true, null: false)
      t.string(:provider, null: false)
      t.string(:uid, null: false)
      t.string(:display_name)
      t.jsonb(:data, null: false, default: {})
      t.timestamps
    end

    add_index(:linked_accounts, %i[provider uid], unique: true)
    add_index(:linked_accounts, %i[user_id provider], unique: true)
  end
end

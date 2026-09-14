# frozen_string_literal: true

class CreateTicketMessages < ActiveRecord::Migration[8.1]
  def change
    create_table(:ticket_messages) do |t|
      t.references(:ticket, foreign_key: true, null: false)
      t.references(:creator, foreign_key: { to_table: :users }, null: false)
      t.inet(:creator_ip_addr, null: false)
      t.text(:body, null: false)
      t.timestamps
    end
  end
end

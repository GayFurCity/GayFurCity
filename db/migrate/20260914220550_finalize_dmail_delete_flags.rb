# frozen_string_literal: true

class FinalizeDmailDeleteFlags < ActiveRecord::Migration[8.1]
  requires_fix(240)

  def up
    change_column(:dmails, :is_deleted_by_sender, :boolean, null: false, default: false)
    change_column(:dmails, :is_deleted_by_recipient, :boolean, null: false, default: false)
    remove_column(:dmails, :owner_id, :bigint, null: false)
    remove_column(:dmails, :is_deleted, :boolean, default: false, null: false)
  end

  def down
    add_column(:dmails, :owner_id, :bigint, null: false)
    add_foreign_key(:dmails, :users, column: :owner_id)
    add_column(:dmails, :is_deleted, :boolean, default: false, null: false)
    change_column(:dmails, :is_deleted_by_sender, :boolean, null: true, default: nil)
    change_column(:dmails, :is_deleted_by_recipient, :boolean, null: true, default: nil)
  end
end

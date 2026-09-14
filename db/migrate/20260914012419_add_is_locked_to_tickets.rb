# frozen_string_literal: true

class AddIsLockedToTickets < ActiveRecord::Migration[8.1]
  def change
    add_column(:tickets, :is_locked, :boolean, default: false, null: false)
  end
end

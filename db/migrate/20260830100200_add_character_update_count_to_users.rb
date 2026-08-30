# frozen_string_literal: true

class AddCharacterUpdateCountToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column(:users, :character_update_count, :integer, default: 0, null: false)
  end
end

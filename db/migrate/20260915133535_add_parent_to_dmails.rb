# frozen_string_literal: true

class AddParentToDmails < ActiveRecord::Migration[8.1]
  def change
    add_reference(:dmails, :parent, foreign_key: { to_table: :dmails }, index: true, null: true)
  end
end

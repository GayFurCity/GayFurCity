# frozen_string_literal: true

class DropResponseFromTickets < ActiveRecord::Migration[8.1]
  requires_fix(239)

  def change
    remove_column(:tickets, :response, :string, default: "", null: false)
  end
end

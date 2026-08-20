# frozen_string_literal: true

class AddSequenceNumberToPostReplacements < ActiveRecord::Migration[7.1]
  def change
    add_column(:post_replacements, :sequence_number, :integer, null: true)
  end
end

# frozen_string_literal: true

class AddReferenceDataToDmails < ActiveRecord::Migration[8.1]
  def change
    # Arbitrary info about where an automated/system dmail came from (e.g. {"type" => "ticket",
    # "ticket_id" => 5}), shown on the show page - deliberately unstructured (jsonb, no fixed
    # keys) since the set of things that can generate a dmail keeps growing.
    add_column(:dmails, :reference_data, :jsonb, null: false, default: {})
  end
end

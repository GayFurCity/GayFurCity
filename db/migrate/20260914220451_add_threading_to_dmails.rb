# frozen_string_literal: true

class AddThreadingToDmails < ActiveRecord::Migration[8.1]
  def change
    # Independent per party - the recipient clearing their inbox must not remove the sender's
    # sent-record, and vice versa. Nullable for now, backfilled by a fixer that also merges each
    # sender/recipient row pair down to one row, then tightened to NOT NULL in a follow-up
    # migration once every row has both flags set.
    add_column(:dmails, :is_deleted_by_sender, :boolean, null: true) # rubocop:disable Rails/ThreeStateBooleanColumn -- backfilled by a fixer, tightened to NOT NULL after
    add_column(:dmails, :is_deleted_by_recipient, :boolean, null: true) # rubocop:disable Rails/ThreeStateBooleanColumn -- backfilled by a fixer, tightened to NOT NULL after
  end
end

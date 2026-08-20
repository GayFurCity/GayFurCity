# frozen_string_literal: true

# Important:
#
# 232_backfill_post_replacement_sequence_number.rb MUST be run before this migration,
# or the NOT NULL constraint will fail.
#
# e621ng pairs this with a check constraint tying sequence_number = 0 to status =
# 'original'. We don't: "Reset To" here lets the original-backup row itself become the
# `approved` replacement in place (PostReplacement#approve!), so a row can carry
# sequence_number = 0 with a non-original status as a normal, permanent steady state.
# sequence_number is assigned once at creation and never reused, so uniqueness alone is
# the invariant that actually holds.

class EnforcePostReplacementSequenceNumber < ActiveRecord::Migration[7.1]
  def change
    PostReplacement.without_timeout do
      change_column_null(:post_replacements, :sequence_number, false)

      add_index(:post_replacements, %i[post_id sequence_number],
                unique: true,
                name:   :index_post_replacements_on_post_id_and_sequence_number)
    end
  end
end

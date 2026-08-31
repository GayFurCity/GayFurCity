# frozen_string_literal: true

class UserFeedbackAddUpdaterId < ActiveRecord::Migration[7.0]
  def change
    add_column(:user_feedback, :updater_id, :integer)
    reversible do |dir|
      dir.up { add_foreign_key(:user_feedback, :users, column: :updater_id) }
      # if_exists: a later migration's column-type change on updater_id drops this FK as a side
      # effect without recreating it, so by the time this runs on rollback it may already be gone.
      dir.down { remove_foreign_key(:user_feedback, :users, column: :updater_id, if_exists: true) }
    end
  end
end

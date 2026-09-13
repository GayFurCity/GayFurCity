# frozen_string_literal: true

# db/migrate/20240614223206_rename_user_feedback_table.rb renamed the table, but Postgres doesn't
# rename constraints along with it - created_at/updated_at's NOT NULL constraints are still named
# after "user_feedback".
class RenameUserFeedbacksNotNullConstraints < ActiveRecord::Migration[8.1]
  def change
    reversible do |dir|
      dir.up do
        rename_constraint_if_exists(:user_feedbacks, "user_feedback_created_at_not_null", "user_feedbacks_created_at_not_null")
        rename_constraint_if_exists(:user_feedbacks, "user_feedback_updated_at_not_null", "user_feedbacks_updated_at_not_null")
      end
      dir.down do
        rename_constraint_if_exists(:user_feedbacks, "user_feedbacks_created_at_not_null", "user_feedback_created_at_not_null")
        rename_constraint_if_exists(:user_feedbacks, "user_feedbacks_updated_at_not_null", "user_feedback_updated_at_not_null")
      end
    end
  end
end

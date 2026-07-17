# frozen_string_literal: true

class AddIsUnlistedToPosts < ExtendedMigration[7.1]
  def change
    add_column(:posts, :is_unlisted, :boolean, null: false, default: false)
    update_change_seq(add: :is_unlisted)
  end
end

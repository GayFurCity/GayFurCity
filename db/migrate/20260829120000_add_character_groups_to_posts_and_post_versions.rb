# frozen_string_literal: true

class AddCharacterGroupsToPostsAndPostVersions < ExtendedMigration[8.1]
  def change
    add_column(:posts, :character_groups, :jsonb, null: false, default: [])
    add_column(:post_versions, :character_groups, :jsonb, null: false, default: [])
    update_change_seq(add: %i[character_groups])
  end
end

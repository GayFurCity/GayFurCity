# frozen_string_literal: true

class AddFlagAiPostsToConfig < ExtendedMigration[7.1]
  def change
    add_column(:config, :flag_ai_posts, :boolean, null: false, default: true)
    add_column(:config, :tag_ai_posts, :boolean, null: false, default: true)
    add_column(:config, :ai_confidence_threshold, :integer, null: false, default: 50)
    AdminConfig.delete_cache
  end
end

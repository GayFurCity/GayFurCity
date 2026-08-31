# frozen_string_literal: true

class AddBlacklistedTagsToConfig < ExtendedMigration[7.1]
  with_config_override!

  def change
    add_column(:config, :default_blacklist, :string, null: false, default: "")
    add_column(:config, :safeblocked_tags, :string, null: false, default: "")
    Config.delete_cache
  end
end

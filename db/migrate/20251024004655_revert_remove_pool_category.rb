# frozen_string_literal: true

class RevertRemovePoolCategory < ExtendedMigration[7.1]
  with_config_override!

  def change
    add_column(:pools, :category, :string, null: false, default: "series")
    add_column_with_value(:pool_versions, :category, :string, null: false, value: "series")
    add_column(:pool_versions, :category_changed, :boolean, null: false, default: false)
    add_column(:config, :pool_category_change_cutoff, :integer, null: false, default: 30)
    add_column(:config, :pool_category_change_cutoff_bypass, :integer, null: false, default: User::Levels::JANITOR)
    add_column(:config, :pool_name_max_size, :integer, null: false, default: 250)
    Config.delete_cache
  end
end

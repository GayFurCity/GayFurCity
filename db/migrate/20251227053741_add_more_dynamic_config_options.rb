# frozen_string_literal: true

class AddMoreDynamicConfigOptions < ExtendedMigration[7.1]
  with_config_override!

  def change
    add_column(:config, :enable_autotagging, :boolean, null: false, default: true)
    add_column(:config, :enable_image_cropping, :boolean, null: false, default: true)
    add_column(:config, :enable_bad_sources, :boolean, null: false, default: true)
    add_column(:config, :safe_mode, :boolean, null: false, default: false)
    add_column(:config, :show_tag_scripting, :integer, null: false, default: User::Levels::TRUSTED)
    add_column(:config, :show_backtrace, :integer, null: false, default: User::Levels::JANITOR)
    add_column(:config, :bur_nuke, :integer, null: false, default: User::Levels::ADMIN)
    add_column(:config, :app_name, :string, null: false, default: "Femboy Fans")
    add_column(:config, :canonical_app_name, :string, null: false, default: "Femboy Fans")
    add_column(:config, :app_description, :string, null: false, default: "Your one-stop shop for femboy furries.")
    add_column(:config, :anonymous_user_name, :string, null: false, default: "Anonymous")
    add_column(:config, :system_user_name, :string, null: false, default: "System")
    Config.delete_cache
  end
end

# frozen_string_literal: true

# db_exports_path used to be an admin-editable URL/path pointing at wherever exports were served
# from externally (e.g. an nginx-served directory). Now that exports are served through our own
# DbExportsController, only an on/off toggle is needed - the destination is fixed.
class ReplaceDbExportsPathWithEnabledInConfig < ExtendedMigration[7.1]
  def change
    remove_column(:config, :db_exports_path, :string, default: "/db_exports")
    add_column(:config, :db_exports_enabled, :boolean, null: false, default: false)

    Config.delete_cache
  end
end

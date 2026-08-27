# frozen_string_literal: true

class AddDbExportsPathToConfig < ExtendedMigration[7.1]
  def change
    add_column(:config, :db_exports_path, :string, default: "/db_exports")
    AdminConfig.delete_cache
  end
end

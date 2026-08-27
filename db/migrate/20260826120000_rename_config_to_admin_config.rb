# frozen_string_literal: true

class RenameConfigToAdminConfig < ExtendedMigration[8.1]
  def change
    rename_table(:config, :admin_config)
    AdminConfig.delete_cache
  end
end

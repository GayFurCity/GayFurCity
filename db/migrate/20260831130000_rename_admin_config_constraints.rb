# frozen_string_literal: true

# db/migrate/20260826120000_rename_config_to_admin_config.rb renamed the table, but Postgres
# doesn't rename constraints along with it - they're still named after "config".
class RenameAdminConfigConstraints < ExtendedMigration[8.1]
  def up
    rename_admin_config_constraints(from: "config", to: "admin_config")
  end

  def down
    rename_admin_config_constraints(from: "admin_config", to: "config")
  end

  private

  def rename_admin_config_constraints(from:, to:)
    names = select_values(<<~SQL)
      SELECT conname FROM pg_constraint
      WHERE conrelid = 'admin_config'::regclass AND conname LIKE '#{from}\\_%' ESCAPE '\\'
    SQL

    names.each do |name|
      rename_constraint(:admin_config, name, name.sub(/\A#{from}_/, "#{to}_"))
    end
  end
end

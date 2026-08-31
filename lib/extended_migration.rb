# frozen_string_literal: true

module ExtendedMigration
  def self.[](version)
    Class.new(ActiveRecord::Migration[version]) do
      include(MigrationHelpers)

      def self.with_config_override!
        const_set(:Config, Class.new(ApplicationRecord) do
          self.table_name = "config"

          def self.config_id
            GayFurCity.config.config_id
          end

          def self.get
            find_or_create_by!(id: config_id)
          end

          def self.delete_cache
            Cache.delete("admin_config:#{config_id}")
            Cache.delete("admin_config:hash_columns")
          end
        end)
      end
    end
  end
end

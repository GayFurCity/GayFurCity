# frozen_string_literal: true

class AddUpdaterToVariousModels < ExtendedMigration[8.1]
  def change
    add_updater(:artists)
    add_updater(:bans, :banner)

    add_column(:takedowns, :approver_ip_addr, :inet)
    reversible do |r|
      r.up { execute("UPDATE takedowns SET approver_ip_addr = updater_ip_addr WHERE approver_id IS NOT NULL") }
    end
  end

  def add_updater(table, data_column = :creator)
    add_reference(table, :updater, foreign_key: { to_table: :users }, null: true)
    add_column(table, :updater_ip_addr, :inet, null: true)
    reversible do |r|
      r.up { execute("UPDATE #{table} SET updater_id = #{data_column}_id, updater_ip_addr = #{data_column}_ip_addr") }
    end
    change_column_null(table, :updater_id, false)
    change_column_null(table, :updater_ip_addr, false)
  end
end

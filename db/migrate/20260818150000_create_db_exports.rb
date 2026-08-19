# frozen_string_literal: true

class CreateDbExports < ExtendedMigration[7.1]
  def change
    create_table(:db_exports) do |t|
      t.string(:name, null: false)
      t.date(:date, null: false)
      t.bigint(:file_size, null: false, default: 0)
      t.string(:checksum)
      t.jsonb(:columns, null: false, default: {})

      t.timestamps
    end

    add_index(:db_exports, %i[name date], unique: true)
    add_index(:db_exports, :date)
  end
end

# frozen_string_literal: true

module MigrationHelpers
  DEFAULT_ID = User.system.id
  DEFAULT_IP = "127.0.0.1"

  def add_ip_addr(table, name, null: false)
    options = { null: null }
    options[:default] = DEFAULT_IP unless null
    add_column(table, :"#{name}_ip_addr", :inet, **options)
    change_column_default(table, :"#{name}_ip_addr", from: DEFAULT_IP, to: nil) unless null
  end

  def add_user_column(table, column, null: false)
    useroptions = { null: null }
    useroptions[:default] = DEFAULT_ID unless null
    ipoptions = { null: null }
    ipoptions[:default] = DEFAULT_IP unless null
    add_reference_with_type(table, column, foreign_key: { to_table: :users }, **useroptions)
    add_column(table, :"#{column}_ip_addr", :inet, **ipoptions)
    change_column_default(table, :"#{column}_id", from: DEFAULT_ID, to: nil) unless null
    change_column_default(table, :"#{column}_ip_addr", from: DEFAULT_IP, to: nil) unless null
  end

  def add_defaulted_user_column(table, column, default, null: false)
    add_reference_with_type(table, column, foreign_key: { to_table: :users })
    add_column(table, :"#{column}_ip_addr", :inet)
    reversible do |r|
      r.up do
        ip_default = connection.column_exists?(table, "#{default}_ip_addr") ? "#{default}_ip_addr" : connection.quote(DEFAULT_IP)
        execute("UPDATE #{table} SET #{column}_id = #{default}_id, #{column}_ip_addr = #{ip_default}")
      end
    end
    change_column_null(table, :"#{column}_id", false) unless null
    change_column_null(table, :"#{column}_ip_addr", false) unless null
  end

  def add_creator_column(table, null: false)
    add_user_column(table, :creator, null: null)
  end

  def add_updater_column(table, default = :creator, **)
    return add_user_column(table, :updater, **) if default.blank?
    add_defaulted_user_column(table, :updater, default, **)
  end

  def add_counter_column(name)
    add_column(:users, name, :integer, default: 0, null: false)
  end

  def get_column_type(table, column)
    type = connection.columns(table).find { |c| c.name == column }.try(:sql_type)
    raise("Failed to get column type for #{table}.#{column}") if type.nil?
    type
  end

  def add_reference_with_type(table, column, **)
    foreign_table = ActiveRecord::ConnectionAdapters::ReferenceDefinition.new(column, **).send(:foreign_table_name)
    foreign_primary = connection.primary_key(foreign_table)
    add_reference(table, column, **, type: get_column_type(foreign_table, foreign_primary))
  end

  def change_column_type(table, column, from:, to:, **)
    reversible do |r|
      r.up { change_column_and_sequence(table, column, to, **) }
      r.down { change_column_and_sequence(table, column, from, **) }
    end
  end

  def change_column_and_sequence(table, column, type, **)
    sequence = connection.serial_sequence(table, column)
    change_column(table, column, type, **)
    if sequence
      execute("ALTER SEQUENCE #{sequence} AS #{to_native_type(type)}")
    end
  end

  def to_native_type(type)
    connection.native_database_types.fetch(type, { name: type })[:name].upcase
  end

  def bulk_change_column_types(list, from:, to:, **)
    list.each do |table, columns|
      columns = Array(columns)
      columns.each do |column|
        change_column_type(table, column, from: from, to: to, **)
        yield(table, column) if block_given?
      end
    end
  end

  def add_column_with_value(table, name, *, value:, **)
    add_column(table, name, *, **, default: value)
    change_column_default(table, name, from: value, to: nil)
  end

  # Reads back the columns currently tracked by the live posts_trigger_change_seq
  # function, so callers can add/remove a column without respecifying the full list.
  def existing_change_seq_columns
    row = connection.select_one("SELECT prosrc FROM pg_proc WHERE proname = $1", nil, ["posts_trigger_change_seq"])
    return [] if row.nil?
    row["prosrc"].scan(/NEW\.([a-z_]+) IS DISTINCT FROM OLD\.([a-z_]+)/).flatten.uniq
  end

  def update_change_seq_sql(columns = nil, add: [], remove: [])
    columns = (columns || existing_change_seq_columns).map(&:to_s)
    columns = (columns | Array(add).map(&:to_s)) - Array(remove).map(&:to_s)

    ctext = ""
    columns.each do |name|
      ctext += "\n    OR NEW.#{name} IS DISTINCT FROM OLD.#{name}"
    end
    ctext = ctext[8..]
    <<~SQL.squish
      CREATE OR REPLACE FUNCTION public.posts_trigger_change_seq() RETURNS trigger
        LANGUAGE plpgsql
      AS $$
      DECLARE
        old_md5 text;
        new_md5 text;
      BEGIN
        SELECT md5 INTO old_md5 FROM upload_media_assets WHERE id = OLD.upload_media_asset_id;
        SELECT md5 INTO new_md5 FROM upload_media_assets WHERE id = NEW.upload_media_asset_id;

        IF #{ctext}
          OR old_md5 IS DISTINCT FROM new_md5
        THEN
          NEW.change_seq = nextval('public.posts_change_seq_seq');
        END IF;
        RETURN NEW;
      END;
      $$;
    SQL
  end

  def update_change_seq(columns = nil, add: [], remove: [])
    if add.blank? && remove.blank? # use execute directly so migration is marked as irreversible
      execute(update_change_seq_sql(columns, add: [], remove: []))
    else
      reversible do |dir|
        dir.up   { execute(update_change_seq_sql(columns, add: add, remove: remove)) }
        dir.down { execute(update_change_seq_sql(columns, add: remove, remove: add)) }
      end
    end
  end
end

# frozen_string_literal: true

module MigrationHelpers
  DEFAULT_IP = "127.0.0.1"

  def add_ip_addr(table, name, null: false)
    options = { null: null }
    options[:default] = DEFAULT_IP unless null
    add_column(table, :"#{name}_ip_addr", :inet, **options)
    change_column_default(table, :"#{name}_ip_addr", from: DEFAULT_IP, to: nil) unless null
  end

  def add_user_column(table, column, null: false)
    useroptions = { null: null }
    useroptions[:default] = default_id unless null
    ipoptions = { null: null }
    ipoptions[:default] = DEFAULT_IP unless null
    add_reference_with_type(table, column, foreign_key: { to_table: :users }, **useroptions)
    add_column(table, :"#{column}_ip_addr", :inet, **ipoptions)
    change_column_default(table, :"#{column}_id", from: default_id, to: nil) unless null
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
    row = ActiveRecord::Base.connection.select_one("SELECT prosrc FROM pg_proc WHERE proname = $1", nil, ["posts_trigger_change_seq"])
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
    <<~SQL # rubocop:disable Rails/SquishedSQLHeredocs
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

  def with_renamed_table(table, name)
    raise(LocalJumpError, "block required") unless block_given?
    rename_table(table, name)
    yield
    rename_table(name, table)
  end

  def add_gin_index(table, index)
    add_index(table, "(#{index})", using: :gin, algorithm: :concurrently)
  end

  # rename_column/rename_table don't rename constraints named after the old column/table name -
  # Postgres leaves them as-is. Not reversible on its own; wrap in `reversible` at the call site
  # with `from`/`to` swapped, same as add_foreign_key/remove_foreign_key pairs elsewhere.
  def rename_constraint(table, from, to)
    execute("ALTER TABLE #{quote_table_name(table)} RENAME CONSTRAINT #{quote_column_name(from)} TO #{quote_column_name(to)}")
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

  # `remove_column(table, column, type, index: {...})` records itself for auto-inversion, but the
  # inverse it generates is `add_column(table, column, type, index: {...})`, and add_column has no
  # `index:` option - it raises "Unknown key: :index" on rollback. Splits the down direction into
  # add_column + a separate add_index instead.
  def remove_column_with_index(table, column, type, index:, **options)
    reversible do |dir|
      dir.up { remove_column(table, column, type, **options) }
      dir.down do
        add_column(table, column, type, **options)
        add_index(table, column, **(index.is_a?(Hash) ? index : {}))
      end
    end
  end

  private

  # Deliberately lazy (not a module-level constant) - `include(MigrationHelpers)` runs for every
  # migration via ExtendedMigration.[], so a constant here would eagerly load User/AdminConfig
  # while merely *defining* a migration class, before its `change` method (and any schema changes
  # it makes) has actually run. That bit us when a migration renaming AdminConfig's own table ran:
  # the eager load tried to query the not-yet-renamed table before the rename in `change` executed.
  #
  # Raw SQL rather than User.system: that goes through AdminConfig.instance for the system user's
  # name, which is unusable here for the same reason - migrations older than db/migrate/*create_config*
  # run before any config table exists at all, so there's no table name to point AdminConfig at.
  def default_id
    existing = connection.select_value("SELECT id FROM users WHERE level = #{User::Levels::SYSTEM} LIMIT 1")
    return existing.to_i if existing

    connection.select_value(<<~SQL.squish)
      INSERT INTO users (name, password_hash, level, email, created_at)
      VALUES (#{connection.quote("System")}, '', #{User::Levels::SYSTEM}, #{connection.quote("system@#{GayFurCity.config.domain}")}, NOW())
      RETURNING id
    SQL
  end
end

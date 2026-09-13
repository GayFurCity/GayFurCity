# frozen_string_literal: true

require("test_helper")

# Reverts every migration (oldest last) and reapplies them all (oldest first), then confirms the
# resulting schema is byte-for-byte what db/structure.sql says it should be - i.e. nobody's `down`
# (hand-written or auto-inverted from `change`) has quietly drifted from what `up` actually produces.
#
# Needs real, committed DDL: only a committed schema is visible to the `pg_dump` used for the
# comparison, so transactional test wrapping (which would just roll the whole thing back invisibly)
# has to be off. The `ensure` re-migrates to head regardless of outcome, so a failure here still
# leaves this process's database usable for every test that runs after it.
class MigrationsTest < ActiveSupport::TestCase
  self.use_transactional_tests = false

  should("revert and reapply every migration with no schema drift") do
    migration_context = ActiveRecord::Base.connection.pool.migration_context
    versions = migration_context.migrations.map(&:version).sort

    begin
      versions.reverse_each { |version| migration_context.run(:down, version) }
      versions.each { |version| migration_context.run(:up, version) }

      Tempfile.create(["migrations_test_structure", ".sql"]) do |file|
        ActiveRecord::Tasks::DatabaseTasks.structure_dump(ActiveRecord::Base.connection_db_config, file.path)

        assert_equal(normalized_structure_sql(Rails.root.join("db/structure.sql")), normalized_structure_sql(file.path))
      end
    ensure
      migration_context.migrate
    end
  end

  private

  # Two things about db/structure.sql aren't reproduced by replaying migrations from scratch, and
  # neither is actually a schema difference:
  #
  # - `INSERT INTO` blocks: `pg_dump --schema-only` never includes table data, but `db:schema:dump`
  #   separately appends schema_migrations' own rows - and this file also carries a stale, no-longer
  #   -maintained data dump for `fixes` (its `lib/fix_tracker.rb` tooling is long gone). Both are
  #   bookkeeping data, not schema, and dropping a table via `down` legitimately can't bring back
  #   rows that were never inserted by a migration in the first place.
  # - Column order inside a table: a migration's timestamp doesn't always match the order it was
  #   really run in production (a rebased/squashed history), so reapplying today's files in filename
  #   order can add a column at a different physical position than history did. Postgres addresses
  #   columns by name everywhere, so this has no behavioral effect - sort each table's column list
  #   before comparing, so a pure reordering doesn't fail the test while every other difference still
  #   does.
  def normalized_structure_sql(path)
    sql = File.read(path)
    sql = sql.gsub(/^INSERT INTO .*?\);\n/m, "").gsub(/\n{3,}/, "\n\n")
    sql.gsub(/^CREATE TABLE ([\w.]+) \(\n(.*?)\n\);/m) do
      "CREATE TABLE #{Regexp.last_match(1)} (\n#{Regexp.last_match(2).split(",\n").sort.join(",\n")}\n);"
    end
  end
end

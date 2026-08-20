# frozen_string_literal: true

# Keep structure.sql's fixes rows in sync with the database on every schema dump, the same way
# ActiveRecord keeps schema_migrations rows in sync - not just when `fixes:migrate` runs.
Rake::Task["db:schema:dump"].enhance do
  FixTracker.dump_structure_sql!
end

namespace(:fixes) do
  desc("List available fix scripts in db/fixes, marking which have already been applied")
  task(list: :environment) do
    applied = FixTracker.applied
    FixTracker.all_fixes.each do |name|
      puts("#{applied.include?(FixTracker.key_for(name)) ? '[x]' : '[ ]'} #{name}")
    end
  end

  desc("Run a fix script from db/fixes by id or name, e.g. `rake fixes:run[208]` - re-runs even if already recorded as applied")
  task(:run, [:name] => :environment) do |_task, args|
    name = args[:name].to_s.delete_suffix(".rb")
    abort("Usage: rake fixes:run[id_or_name] (see `rake fixes:list`)") if name.blank?

    candidates = Dir["db/fixes/*.rb"]
    exact = candidates.find { |path| File.basename(path, ".rb") == name }
    matches = exact ? [exact] : candidates.select { |path| File.basename(path, ".rb").start_with?("#{name}_") || File.basename(path, ".rb").include?(name) }

    if matches.empty?
      abort("No fix matches \"#{name}\". Run `rake fixes:list` to see available fixes.")
    elsif matches.size > 1
      abort("Multiple fixes match \"#{name}\", be more specific:\n#{matches.map { |m| "  #{File.basename(m, '.rb')}" }.join("\n")}")
    end

    FixTracker.run!(matches.first)
  end

  desc("Apply all fix scripts not yet recorded as applied, in order, then dump the schema like db:migrate does")
  task(migrate: :environment) do
    pending = FixTracker.pending

    if pending.empty?
      puts("No pending fixes.")
    else
      pending.each { |name| FixTracker.run!(FixTracker.fix_path(name)) }
    end

    Rake::Task["db:_dump"].invoke
  end
end

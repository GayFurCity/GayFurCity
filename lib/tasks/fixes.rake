# frozen_string_literal: true

namespace(:fixes) do
  desc("List available fix scripts in db/fixes")
  task(:list) do
    Dir["db/fixes/*.rb"].sort.each { |f| puts(File.basename(f, ".rb")) }
  end

  desc("Run a fix script from db/fixes by id or name, e.g. `rake fixes:run[208]`")
  task(:run, [:name] => :environment) do |_task, args|
    name = args[:name].to_s.delete_suffix(".rb")
    abort("Usage: rake fixes:run[id_or_name] (see `rake fixes:list`)") if name.blank?

    candidates = Dir["db/fixes/*.rb"].sort
    exact = candidates.find { |path| File.basename(path, ".rb") == name }
    matches = exact ? [exact] : candidates.select { |path| File.basename(path, ".rb").start_with?("#{name}_") || File.basename(path, ".rb").include?(name) }

    if matches.empty?
      abort("No fix matches \"#{name}\". Run `rake fixes:list` to see available fixes.")
    elsif matches.size > 1
      abort("Multiple fixes match \"#{name}\", be more specific:\n#{matches.map { |m| "  #{File.basename(m, '.rb')}" }.join("\n")}")
    end

    path = matches.first
    puts("Running #{File.basename(path)}...")
    load(File.expand_path(path))
  end
end

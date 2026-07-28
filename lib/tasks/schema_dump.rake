# frozen_string_literal: true

# the ruby schema cannot be depended on to actually load the schema due to it missing certain features like functions,
# but we still dump it for use with rubocop rules
Rake::Task["db:schema:dump"].enhance do
  Rails.root.join("db/schema.rb").open("w") do |stream|
    ActiveRecord::SchemaDumper.dump(ActiveRecord::Base.connection_pool, stream)
  end
end

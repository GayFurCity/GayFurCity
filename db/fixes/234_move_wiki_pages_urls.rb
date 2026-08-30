#!/usr/bin/env ruby
# frozen_string_literal: true

require(File.expand_path(File.join(File.dirname(__FILE__), "..", "..", "config", "environment")))

# /wiki_pages was moved to /wiki; rewrite any literal links left over in existing dtext bodies.
updater = User.system
pattern = %r{/wiki_pages(?=\z|[^\w])}

[WikiPage, ForumPost].each do |klass|
  klass.without_timeout do
    fixed = 0
    klass.find_in_batches(batch_size: 500) do |batch|
      klass.transaction do
        batch.each do |record|
          next unless record.body =~ pattern
          record.body = record.body.gsub(pattern, "/wiki")
          record.updater = updater
          record.save(validate: false)
          fixed += 1
        end
      end
    end
    puts("#{klass.name}: fixed #{fixed}")
  end
end

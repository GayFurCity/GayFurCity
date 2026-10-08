#!/usr/bin/env ruby
# frozen_string_literal: true

require(File.expand_path(File.join(File.dirname(__FILE__), "..", "..", "config", "environment")))

renames = { "posts/iqdb:show" => "posts/eris:show", "posts:update_iqdb" => "posts:update_eris" }

ApiKey.where("permissions && ARRAY[?]::varchar[]", renames.keys).find_each do |key|
  key.update_columns(permissions: key.permissions.map { |perm| renames.fetch(perm, perm) })
end

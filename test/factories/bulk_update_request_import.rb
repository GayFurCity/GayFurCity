# frozen_string_literal: true

FactoryBot.define do
  factory(:bulk_update_request_import) do
    creator(factory: %i[user])
    sequence(:script) { |n| "category bulk_update_request_import_tag_#{n} -> general" }
  end
end

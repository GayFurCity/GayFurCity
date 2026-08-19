# frozen_string_literal: true

FactoryBot.define do
  factory(:db_export) do
    sequence(:name) { |n| "db_export_#{n}" }
    date { Date.current }
    file_size { 1024 }
  end
end

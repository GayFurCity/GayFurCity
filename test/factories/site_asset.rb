# frozen_string_literal: true

FactoryBot.define do
  factory(:site_asset) do
    creator(factory: %i[owner_user])
    name { "icon" }
    file { fixture_file_upload("test-square.png") }
  end
end

# frozen_string_literal: true

FactoryBot.define do
  factory(:domain_icon) do
    creator(factory: %i[admin_user])
    sequence(:domain) { |n| "site#{n}.example.net" }
    file { fixture_file_upload("test-icon-32.png") }
  end
end

# frozen_string_literal: true

FactoryBot.define do
  factory(:bulk_update_request) do
    creator(factory: %i[user])
    script { "alias aaa -> bbb" }
    sequence(:title) { |n| "bulk_update_request_#{n}" }
    sequence(:reason) { |n| "bulk_update_request_reason_#{n}" }
  end
end

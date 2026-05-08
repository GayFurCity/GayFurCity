# frozen_string_literal: true

FactoryBot.define do
  factory(:takedown) do
    creator(factory: %i[user])
    email { "takedown@example.com" }
    source { "example.com" }
    reason { "foo" }
    instructions { "bar" }
  end
end

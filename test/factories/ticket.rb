# frozen_string_literal: true

FactoryBot.define do
  factory(:ticket) do
    creator(factory: %i[user])
    reason { "test" }
  end
end

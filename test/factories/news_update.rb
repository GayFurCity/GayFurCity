# frozen_string_literal: true

FactoryBot.define do
  factory(:news_update) do
    creator(factory: %i[user])
    message { "xxx" }
  end
end

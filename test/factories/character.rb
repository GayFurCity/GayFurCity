# frozen_string_literal: true

FactoryBot.define do
  factory(:character) do
    creator(factory: %i[user])
    sequence(:name) { |n| "character_#{n}" }
  end
end

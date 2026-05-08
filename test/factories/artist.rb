# frozen_string_literal: true

FactoryBot.define do
  factory(:artist) do
    creator(factory: %i[user])
    sequence(:name) { |n| "artist_#{n}" }
  end
end

# frozen_string_literal: true

FactoryBot.define do
  factory(:avoid_posting) do
    creator(factory: %i[owner_user])
    artist
  end
end

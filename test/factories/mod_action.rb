# frozen_string_literal: true

FactoryBot.define do
  factory(:mod_action) do
    creator(factory: %i[user])
    action { "test" }
  end
end

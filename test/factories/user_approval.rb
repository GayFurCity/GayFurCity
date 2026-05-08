# frozen_string_literal: true

FactoryBot.define do
  factory(:user_approval) do
    user(factory: %i[restricted_user])
  end
end

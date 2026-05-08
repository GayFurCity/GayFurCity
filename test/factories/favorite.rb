# frozen_string_literal: true

FactoryBot.define do
  factory(:favorite) do
    user
    post
  end
end

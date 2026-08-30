# frozen_string_literal: true

FactoryBot.define do
  factory(:character_url) do
    character
    sequence(:url) { |n| "character_domain_#{n}.com" }
  end
end

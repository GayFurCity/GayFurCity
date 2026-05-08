# frozen_string_literal: true

FactoryBot.define do
  factory(:rule) do
    creator(factory: %i[user])
    category(factory: %i[rule_category])
    sequence(:name) { |n| "rule_#{n}" }
    sequence(:description) { |n| "rule_description_#{n}" }
  end
end

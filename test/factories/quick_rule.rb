# frozen_string_literal: true

FactoryBot.define do
  factory(:quick_rule) do
    creator(factory: %i[user])
    rule
    sequence(:reason) { |n| "quick_rule_#{n}" }
  end
end

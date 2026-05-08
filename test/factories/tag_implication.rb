# frozen_string_literal: true

FactoryBot.define do
  factory(:tag_implication) do
    creator(factory: %i[user])
    antecedent_name { "aaa" }
    consequent_name { "bbb" }
    status { "active" }
  end
end

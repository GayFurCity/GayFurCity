# frozen_string_literal: true

FactoryBot.define do
  factory(:post_set) do
    creator(factory: %i[user])
    sequence(:name) { |n| "post_set_name_#{n}" }
    sequence(:shortname) { |n| "post_set_shortname_#{n}" }
  end
end

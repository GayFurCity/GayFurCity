# frozen_string_literal: true

FactoryBot.define do
  factory(:post_replacement_rejection_reason) do
    creator(factory: %i[admin_user])
    sequence(:reason) { |n| "reason_#{n}" }
  end
end

# frozen_string_literal: true

FactoryBot.define do
  factory(:ban) do |_f|
    creator(factory: %i[admin_user])
    user
    sequence(:reason) { |n| "ban_reason_#{n}" }
    duration { 60 }
  end
end

# frozen_string_literal: true

FactoryBot.define do
  factory(:ticket_message) do
    ticket
    creator(factory: %i[user])
    sequence(:body) { |n| "ticket_message_body_#{n}" }
  end
end

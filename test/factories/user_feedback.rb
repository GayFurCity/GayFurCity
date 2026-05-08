# frozen_string_literal: true

FactoryBot.define do
  factory(:user_feedback) do
    user
    creator(factory: %i[moderator_user])
    category { "positive" }
    sequence(:body) { |n| "user_feedback_body_#{n}" }
  end
end

# frozen_string_literal: true

FactoryBot.define do
  factory(:user_event) do
    user
    user_session
  end
end

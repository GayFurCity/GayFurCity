# frozen_string_literal: true

FactoryBot.define do
  factory(:upload_whitelist) do
    creator(factory: %i[admin_user])
  end
end

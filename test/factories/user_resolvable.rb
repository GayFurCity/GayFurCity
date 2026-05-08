# frozen_string_literal: true

FactoryBot.define do
  factory(:user_resolvable) do
    user
    ip_addr { "127.0.0.1" }

    initialize_with { new(user, ip_addr) }
    to_create { |instance| instance.user.save! }
  end
end

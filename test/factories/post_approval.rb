# frozen_string_literal: true

FactoryBot.define do
  factory(:post_approval) do
    user(factory: %i[janitor_user])
    post { create(:post, is_pending: true) }
  end
end

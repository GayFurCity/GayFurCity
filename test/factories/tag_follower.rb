# frozen_string_literal: true

FactoryBot.define do
  factory(:tag_follower) do
    user
    tag
    last_post(factory: %i[post])
  end
end

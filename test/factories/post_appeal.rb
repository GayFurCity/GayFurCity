# frozen_string_literal: true

FactoryBot.define do
  factory(:post_appeal) do
    creator(factory: %i[user])
    post { create(:post, is_deleted: true) }
  end
end

# frozen_string_literal: true

FactoryBot.define do
  factory(:post_flag) do
    creator(factory: %i[user])
    post
    reason_name { "dnp_artist" }
    note { "Some explanation" }
    is_resolved { false }
  end
end

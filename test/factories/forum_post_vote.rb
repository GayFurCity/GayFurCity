# frozen_string_literal: true

FactoryBot.define do
  factory(:forum_post_vote) do
    user
    score { 1 }
  end
end

# frozen_string_literal: true

FactoryBot.define do
  factory(:comment_vote) do
    user
    score { 1 }
  end
end

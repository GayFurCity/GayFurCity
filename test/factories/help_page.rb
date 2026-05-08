# frozen_string_literal: true

FactoryBot.define do
  factory(:help_page) do
    creator(factory: %i[admin_user])
    wiki_page
    sequence(:name) { |n| "help_page_#{n}" }
  end
end

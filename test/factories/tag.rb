# frozen_string_literal: true

FactoryBot.define do
  factory(:tag) do
    creator(factory: %i[user])
    sequence(:name) { |n| "tag_name_#{n}" }
    post_count { 0 }
    category { TagCategory.general }
    related_tags { "" }
    related_tags_updated_at { Time.now }

    factory(:artist_tag) do
      category { TagCategory.artist }
    end

    factory(:copyright_tag) do
      category { TagCategory.copyright }
    end

    factory(:character_tag) do
      category { TagCategory.character }
    end
  end
end

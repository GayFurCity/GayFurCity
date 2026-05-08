# frozen_string_literal: true

FactoryBot.define do
  factory(:mascot) do
    creator(factory: %i[admin_user])
    sequence(:display_name) { |n| "mascot_#{n}" }
    background_color { "FFFFFF" }
    artist_url { "http://localhost" }
    artist_name { "artist" }
    mascot_media_asset { build(:jpg_mascot_media_asset, :pending, creator: creator) }
    file { |rec| rec.mascot_media_asset&.file }
  end
end

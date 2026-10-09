# frozen_string_literal: true

FactoryBot.define do
  factory(:site_media_asset) do
    creator { association(:user, created_at: 2.weeks.ago) }
    name { "icon" }
    checksum { "7d16a6f5eda5494bdd4499e14c9efdab" }
    md5 { "7d16a6f5eda5494bdd4499e14c9efdab" }
    file_ext { "png" }
    is_animated_png { false }
    is_animated_gif { false }
    is_animated_webp { false }
    file_size { 125_019 }
    image_width { 710 }
    image_height { 710 }
    pixel_hash { "01cb481ec7730b7cfced57ffa5abd196" }
    status { "active" }
    skip_files { true }
  end
end

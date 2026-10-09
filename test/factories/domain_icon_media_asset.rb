# frozen_string_literal: true

FactoryBot.define do
  factory(:domain_icon_media_asset) do
    creator { association(:user, created_at: 2.weeks.ago) }
    checksum { "806609ce65935234107058cbd3cbad11" }
    md5 { "806609ce65935234107058cbd3cbad11" }
    file_ext { "png" }
    is_animated_png { false }
    is_animated_gif { false }
    is_animated_webp { false }
    file_size { 1_000 }
    image_width { 32 }
    image_height { 32 }
    pixel_hash { "01cb481ec7730b7cfced57ffa5abd196" }
    status { "active" }
    skip_files { true }
  end
end

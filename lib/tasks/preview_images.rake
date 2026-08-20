# frozen_string_literal: true

namespace(:preview_images) do
  desc("Regenerate the placeholder preview images under public/images/ (deleted/blacklisted/download/missing/placeholder)")
  task(generate: :environment) do
    system(Rails.root.join("bin/generate_preview_images").to_s, exception: true)
  end
end

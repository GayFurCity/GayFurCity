# frozen_string_literal: true

# Preview placeholder URLs used to be fixed at deploy time (config/config.rb); moving them into
# the DB-backed config makes them admin-editable like everything else in DynamicConfig.
#
# blacklisted_preview_url is added for consistency (config/dynamic_config.rb) but isn't wired up
# to anything yet - blacklists.scss references the file directly since it's a static
# background-image, not server-rendered.
#
# deleted_preview_url's env default was "/images/delete-preview.png", but the actual asset on
# disk is "deleted-preview.png" - fixed here rather than carrying the typo into the DB default.
class MovePreviewUrlsToDynamicConfig < ExtendedMigration[8.1]
  with_config_override!

  def change
    add_column(:config, :blacklisted_preview_url, :string, null: false, default: "/images/blacklisted-preview.png")
    add_column(:config, :deleted_preview_url, :string, null: false, default: "/images/deleted-preview.png")
    add_column(:config, :download_preview_url, :string, null: false, default: "/images/download-preview.png")
    add_column(:config, :missing_preview_url, :string, null: false, default: "/images/missing-preview.png")
    add_column(:config, :placeholder_preview_url, :string, null: false, default: "/images/placeholder-preview.png")

    Config.delete_cache
  end
end

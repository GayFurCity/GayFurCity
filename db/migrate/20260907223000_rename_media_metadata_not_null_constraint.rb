# frozen_string_literal: true

# db/migrate/20250923161649_media_assets_are_vegan.rb renamed meatadata -> metadata, but Postgres
# doesn't rename the column's NOT NULL constraint along with it - it's still named after "meatadata".
class RenameMediaMetadataNotNullConstraint < ActiveRecord::Migration[8.1]
  def change
    reversible do |dir|
      dir.up   { rename_constraint_if_exists(:media_metadata, "media_metadata_meatadata_not_null", "media_metadata_metadata_not_null") }
      dir.down { rename_constraint_if_exists(:media_metadata, "media_metadata_metadata_not_null", "media_metadata_meatadata_not_null") }
    end
  end
end

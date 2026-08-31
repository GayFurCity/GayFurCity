# frozen_string_literal: true

class FinalizeMediaAssetChanges < ExtendedMigration[7.1]
  def change
    remove_column_with_index(:posts, :md5, :string, null: false, index: { unique: true })
    remove_column(:posts, :file_ext, :string, null: false)
    remove_column(:posts, :file_size, :integer, null: false)
    remove_column(:posts, :image_width, :integer, null: false)
    remove_column(:posts, :image_height, :integer, null: false)
    remove_column(:posts, :generated_samples, :string, null: false, array: true, default: [])
    remove_column(:posts, :duration, :integer)
    remove_column(:posts, :framecount, :integer)
    remove_column(:posts, :samples_data, :string, null: false, array: true, default: [])
    remove_column(:uploads, :status, :string, null: false, default: "pending")
    remove_column(:uploads, :md5, :string)
    remove_column(:uploads, :file_ext, :string)
    remove_column(:uploads, :file_size, :integer)
    remove_column(:uploads, :image_width, :integer)
    remove_column(:uploads, :image_height, :integer)
    remove_column(:post_replacements, :file_ext, :string, null: false)
    remove_column(:post_replacements, :file_size, :integer, null: false)
    remove_column(:post_replacements, :image_width, :integer, null: false)
    remove_column(:post_replacements, :image_height, :integer, null: false)
    remove_column(:post_replacements, :md5, :string, null: false)
    remove_column(:post_replacements, :storage_id, :string, null: false)
    remove_column(:post_replacements, :protected, :boolean, null: false, default: false)
    remove_column(:mascots, :md5, :string, null: false)
    remove_column(:mascots, :file_ext, :string, null: false)
  end
end

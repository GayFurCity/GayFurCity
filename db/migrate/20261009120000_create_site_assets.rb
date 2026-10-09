# frozen_string_literal: true

class CreateSiteAssets < ActiveRecord::Migration[8.1]
  with_admin_config_override!

  def change
    create_table(:site_media_assets) do |t|
      # the site asset this was uploaded for, decides which variants are generated
      t.string(:name, null: false)
      t.references(:creator, foreign_key: { to_table: :users }, null: false)
      t.references(:media_metadata, foreign_key: true, null: false)
      t.inet(:creator_ip_addr, null: false)
      t.string(:checksum, limit: 32, null: true, index: true)
      # not unique, the same image can be used for more than one site asset
      t.string(:md5, limit: 32, null: true, index: true) # only set when completed
      t.string(:file_ext, limit: 4, null: true) # only set when completed
      t.boolean(:is_animated_png, null: true) # rubocop:disable Rails/ThreeStateBooleanColumn -- only set when completed
      t.boolean(:is_animated_gif, null: true) # rubocop:disable Rails/ThreeStateBooleanColumn -- only set when completed
      t.boolean(:is_animated_webp, null: true) # rubocop:disable Rails/ThreeStateBooleanColumn -- only set when completed
      t.integer(:file_size, null: true) # only set when completed
      t.integer(:image_width, null: true) # only set when completed
      t.integer(:image_height, null: true) # only set when completed
      t.numeric(:duration) # only set when completed
      t.integer(:framecount) # only set when completed
      t.string(:pixel_hash, limit: 32, null: true, index: true) # only set when completed
      t.string(:status, default: "pending", null: false)
      t.string(:status_message, null: true)
      t.integer(:last_chunk_id, null: false, default: 0)
      t.jsonb(:generated_variants, null: false, default: [])
      t.jsonb(:variants_data, null: false, default: [])
      t.timestamps
    end

    create_table(:site_assets) do |t|
      t.string(:name, null: false, index: { unique: true })
      t.references(:site_media_asset, foreign_key: true, null: false)
      t.references(:creator, foreign_key: { to_table: :users }, null: false)
      t.inet(:creator_ip_addr, null: false)
      t.references(:updater, foreign_key: { to_table: :users }, null: false)
      t.inet(:updater_ip_addr, null: false)
      t.timestamps
    end

    add_column(:admin_config, :site_icon_size, :jsonb, null: false, default: { min: 512, max: 10_000 })
    add_column(:admin_config, :max_site_asset_file_sizes, :jsonb, null: false, default: { png: 10_240, jpg: 10_240, webp: 10_240 })
    AdminConfig.delete_cache
  end
end

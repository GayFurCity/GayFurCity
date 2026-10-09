# frozen_string_literal: true

class CreateDomainIcons < ActiveRecord::Migration[8.1]
  with_admin_config_override!

  def change
    create_table(:domain_icon_media_assets) do |t|
      t.references(:creator, foreign_key: { to_table: :users }, null: false)
      t.references(:media_metadata, foreign_key: true, null: false)
      t.inet(:creator_ip_addr, null: false)
      t.string(:checksum, limit: 32, null: true, index: true)
      # not unique, the same icon can be used for more than one domain
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
      t.timestamps
    end

    create_table(:domain_icons) do |t|
      t.string(:domain, null: false, index: { unique: true })
      t.string(:aliases, array: true, null: false, default: [])
      t.references(:domain_icon_media_asset, foreign_key: true, null: false)
      t.references(:creator, foreign_key: { to_table: :users }, null: false)
      t.inet(:creator_ip_addr, null: false)
      t.references(:updater, foreign_key: { to_table: :users }, null: false)
      t.inet(:updater_ip_addr, null: false)
      t.timestamps
    end

    add_column(:admin_config, :domain_icon_size, :jsonb, null: false, default: { min: 16, max: 256 })
    add_column(:admin_config, :max_domain_icon_file_sizes, :jsonb, null: false, default: { png: 256, jpg: 256, gif: 256, webp: 256 })
    AdminConfig.delete_cache
  end
end

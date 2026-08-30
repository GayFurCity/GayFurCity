# frozen_string_literal: true

class CreateCharacters < ActiveRecord::Migration[8.1]
  def change
    create_table(:characters) do |t|
      t.string(:name, null: false, index: { unique: true })
      t.boolean(:is_locked, default: false, null: false)
      t.bigint(:owner_user_id, index: true)
      t.bigint(:cover_post_id, index: true)
      t.string(:cover_caption)
      t.jsonb(:custom_attributes, default: [], null: false)
      t.bigint(:creator_id, null: false)
      t.inet(:creator_ip_addr, null: false)
      t.bigint(:updater_id, null: false, index: true)
      t.inet(:updater_ip_addr, null: false)
      t.timestamps(precision: nil, null: false)
    end
    add_index(:characters, :name, name: "index_characters_on_name_trgm", opclass: :gin_trgm_ops, using: :gin)

    create_table(:character_urls) do |t|
      t.bigint(:character_id, null: false, index: true)
      t.text(:url, null: false, index: { name: "index_character_urls_on_url_trgm", opclass: :gin_trgm_ops, using: :gin })
      t.text(:normalized_url, null: false, index: { name: "index_character_urls_on_normalized_url_pattern", opclass: :text_pattern_ops })
      t.boolean(:is_active, default: true, null: false)
      t.timestamps(precision: nil, null: false)
    end
    add_index(:character_urls, %i[character_id url], unique: true)
    add_index(:character_urls, :normalized_url, name: "index_character_urls_on_normalized_url_trgm", opclass: :gin_trgm_ops, using: :gin)

    create_table(:character_versions) do |t|
      t.bigint(:character_id, null: false, index: true)
      t.string(:name, null: false, index: true)
      t.text(:urls, default: [], null: false, array: true)
      t.boolean(:notes_changed, default: false, null: false)
      t.boolean(:cover_post_changed, default: false, null: false)
      t.boolean(:cover_caption_changed, default: false, null: false)
      t.jsonb(:custom_attributes, default: [], null: false)
      t.boolean(:custom_attributes_changed, default: false, null: false)
      t.bigint(:owner_user_id, index: true)
      t.bigint(:updater_id, null: false, index: true)
      t.inet(:updater_ip_addr, null: false, index: true)
      t.datetime(:created_at, precision: nil, null: false, index: true)
      t.datetime(:updated_at, precision: nil, null: false)
    end
  end
end

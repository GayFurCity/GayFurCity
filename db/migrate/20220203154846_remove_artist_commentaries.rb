# frozen_string_literal: true

class RemoveArtistCommentaries < ActiveRecord::Migration[6.1]
  def change
    remove_column(:uploads, :artist_commentary_title, :text)
    remove_column(:uploads, :artist_commentary_desc, :text)
    remove_column(:uploads, :include_artist_commentary, :boolean)

    drop_table(:artist_commentaries, id: :integer) do |t|
      t.integer(:post_id, null: false, index: { unique: true })
      t.text(:original_title, default: "", null: false)
      t.text(:original_description, default: "", null: false)
      t.text(:translated_title, default: "", null: false)
      t.text(:translated_description, default: "", null: false)
      t.timestamps(null: true)
    end
    drop_table(:artist_commentary_versions, id: :integer) do |t|
      t.integer(:post_id, null: false, index: true)
      t.integer(:updater_id, null: false)
      t.inet(:updater_ip_addr, null: false, index: true)
      t.text(:original_title)
      t.text(:original_description)
      t.text(:translated_title)
      t.text(:translated_description)
      t.timestamps(null: true)
      t.index(%i[updater_id post_id])
    end
  end
end

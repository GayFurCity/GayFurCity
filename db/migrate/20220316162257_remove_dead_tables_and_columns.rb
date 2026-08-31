# frozen_string_literal: true

class RemoveDeadTablesAndColumns < ExtendedMigration[6.1]
  disable_ddl_transaction!

  def change
    User.without_timeout do
      drop_table(:post_appeals, id: :integer) do |t|
        t.integer(:post_id, null: false, index: true)
        t.integer(:creator_id, null: false, index: true)
        t.inet(:creator_ip_addr, index: true)
        t.text(:reason)
        t.timestamps(null: true, index: true)
        t.index("(to_tsvector('english', reason))", using: :gin, algorithm: :concurrently, name: "index_post_appeals_on_reason_tsvector")
      end

      drop_table(:favorite_groups, id: :integer) do |t|
        t.text(:name, null: false)
        t.integer(:creator_id, null: false, index: true)
        t.text(:post_ids, null: false, default: "")
        t.integer(:post_count, null: false, default: 0)
        t.timestamps(null: true)
        t.boolean(:is_public, null: false, default: false)
        t.index("lower(name)", name: "index_favorite_groups_on_lower_name")
      end

      drop_table(:post_image_hashes, id: :bigint) do |t|
        t.references(:post, null: false, index: true, foreign_key: true)
        t.float(:nw, null: false)
        t.float(:ne, null: false)
        t.float(:sw, null: false)
        t.float(:se, null: false)
        t.binary(:phash)
        t.index(%i[nw ne sw se], name: "post_image_hashes_index")
      end

      drop_table(:post_replacements, id: :integer) do |t|
        t.integer(:post_id, null: false, index: true)
        t.integer(:creator_id, null: false, index: true)
        t.timestamps(null: true)
        t.string(:file_ext)
        t.integer(:file_size)
        t.integer(:image_width)
        t.integer(:image_height)
        t.string(:md5)
        t.integer(:old_image_width)
        t.integer(:old_image_height)
        t.string(:old_md5)
        t.integer(:old_file_size)
        t.string(:old_file_ext)
        t.text(:replacement_url)
        t.text(:original_url)
      end

      drop_table(:saved_searches, id: :integer) do |t|
        t.integer(:user_id, index: true)
        t.text(:query, index: true)
        t.timestamps(null: true)
        t.text(:labels, array: true, null: false, default: [], index: true)
      end

      drop_table(:user_blacklisted_tags, id: :integer) do |t|
        t.integer(:user_id, null: false)
        t.text(:tags, null: false)
      end

      reversible do |r|
        r.up { drop_table(:post_updates) }
        r.down do
          create_table(:post_updates, id: nil) do |t| # rubocop:disable Rails/CreateTableWithTimestamps
            t.integer(:post_id)
          end
          execute("ALTER TABLE post_updates SET UNLOGGED")
        end
      end

      drop_table(:pixiv_ugoira_frame_data, id: :integer) do |t|
        t.integer(:post_id, index: { unique: true })
        t.text(:data)
        t.string(:content_type, null: false)
      end

      remove_column(:artists, :is_banned, :boolean, null: false, default: false)
      remove_column(:artist_versions, :is_banned, :boolean, null: false, default: false)
      remove_column(:forum_topics, :min_level, :integer, null: false, default: 0)
      remove_column(:dmails, :is_spam, :boolean, default: false)
      remove_column_with_index(:posts, :pixiv_id, :integer, index: { where: "pixiv_id IS NOT NULL" })
      remove_column_with_index(:uploads, :referer_url, :text, index: true)
      remove_column(:uploads, :context, :text)
      remove_column(:uploads, :content_type, :varchar)
      remove_column(:uploads, :file_path, :varchar)
      remove_column(:uploads, :server, :text)
      change_column_null(:users, :profile_about, false)
      change_column_null(:users, :profile_artinfo, false)
    end
  end
end

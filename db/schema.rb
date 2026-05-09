# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[7.1].define(version: 2026_05_09_060732) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_trgm"
  enable_extension "plpgsql"

  create_table "api_keys", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "key", null: false
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.string "name", default: "", null: false
    t.string "permissions", default: [], null: false, array: true
    t.inet "permitted_ip_addresses", default: [], null: false, array: true
    t.integer "uses", default: 0, null: false
    t.datetime "last_used_at"
    t.inet "last_ip_address"
    t.index ["key"], name: "index_api_keys_on_key", unique: true
    t.index ["name", "user_id"], name: "index_api_keys_on_name_and_user_id", unique: true
  end

  create_table "artist_urls", force: :cascade do |t|
    t.bigint "artist_id", null: false
    t.text "url", null: false
    t.text "normalized_url", null: false
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.boolean "is_active", default: true, null: false
    t.index ["artist_id", "url"], name: "index_artist_urls_on_artist_id_and_url", unique: true
    t.index ["artist_id"], name: "index_artist_urls_on_artist_id"
    t.index ["normalized_url"], name: "index_artist_urls_on_normalized_url_pattern", opclass: :text_pattern_ops
    t.index ["normalized_url"], name: "index_artist_urls_on_normalized_url_trgm", opclass: :gin_trgm_ops, using: :gin
    t.index ["url"], name: "index_artist_urls_on_url_trgm", opclass: :gin_trgm_ops, using: :gin
  end

  create_table "artist_versions", force: :cascade do |t|
    t.bigint "artist_id", null: false
    t.string "name", null: false
    t.bigint "updater_id", null: false
    t.inet "updater_ip_addr", null: false
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.text "other_names", default: [], null: false, array: true
    t.text "urls", default: [], null: false, array: true
    t.boolean "notes_changed", default: false
    t.bigint "linked_user_id"
    t.index ["artist_id"], name: "index_artist_versions_on_artist_id"
    t.index ["created_at"], name: "index_artist_versions_on_created_at"
    t.index ["linked_user_id"], name: "index_artist_versions_on_linked_user_id"
    t.index ["name"], name: "index_artist_versions_on_name"
    t.index ["updater_id"], name: "index_artist_versions_on_updater_id"
    t.index ["updater_ip_addr"], name: "index_artist_versions_on_updater_ip_addr"
  end

  create_table "artists", force: :cascade do |t|
    t.string "name", null: false
    t.bigint "creator_id", null: false
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.text "other_names", default: [], null: false, array: true
    t.bigint "linked_user_id"
    t.boolean "is_locked", default: false
    t.inet "creator_ip_addr", null: false
    t.index ["linked_user_id"], name: "index_artists_on_linked_user_id"
    t.index ["name"], name: "index_artists_on_name", unique: true
    t.index ["name"], name: "index_artists_on_name_trgm", opclass: :gin_trgm_ops, using: :gin
    t.index ["other_names"], name: "index_artists_on_other_names", using: :gin
  end

  create_table "avoid_posting_versions", force: :cascade do |t|
    t.bigint "updater_id", null: false
    t.bigint "avoid_posting_id", null: false
    t.inet "updater_ip_addr", null: false
    t.string "details", default: "", null: false
    t.string "staff_notes", default: "", null: false
    t.boolean "is_active", default: true, null: false
    t.datetime "updated_at", null: false
    t.index ["avoid_posting_id"], name: "index_avoid_posting_versions_on_avoid_posting_id"
    t.index ["updater_id"], name: "index_avoid_posting_versions_on_updater_id"
  end

  create_table "avoid_postings", force: :cascade do |t|
    t.bigint "creator_id", null: false
    t.bigint "updater_id", null: false
    t.inet "creator_ip_addr", null: false
    t.inet "updater_ip_addr", null: false
    t.string "details", default: "", null: false
    t.string "staff_notes", default: "", null: false
    t.boolean "is_active", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "artist_id", null: false
    t.index ["artist_id"], name: "index_avoid_postings_on_artist_id", unique: true
    t.index ["creator_id"], name: "index_avoid_postings_on_creator_id"
    t.index ["updater_id"], name: "index_avoid_postings_on_updater_id"
  end

  create_table "bans", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.text "reason", null: false
    t.bigint "banner_id", null: false
    t.datetime "expires_at", precision: nil
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.inet "banner_ip_addr", null: false
    t.index ["banner_id"], name: "index_bans_on_banner_id"
    t.index ["expires_at"], name: "index_bans_on_expires_at"
    t.index ["user_id"], name: "index_bans_on_user_id"
  end

  create_table "bulk_update_request_versions", force: :cascade do |t|
    t.bigint "bulk_update_request_id", null: false
    t.bigint "updater_id", null: false
    t.inet "updater_ip_addr", null: false
    t.string "script", null: false
    t.boolean "script_changed", default: false, null: false
    t.string "status", null: false
    t.boolean "status_changed", default: false, null: false
    t.string "title", null: false
    t.boolean "title_changed", default: false, null: false
    t.integer "version", default: 1, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["bulk_update_request_id"], name: "index_bulk_update_request_versions_on_bulk_update_request_id"
    t.index ["updater_id"], name: "index_bulk_update_request_versions_on_updater_id"
  end

  create_table "bulk_update_requests", force: :cascade do |t|
    t.bigint "creator_id", null: false
    t.bigint "forum_topic_id"
    t.text "script", null: false
    t.string "status", default: "pending", null: false
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.bigint "approver_id"
    t.bigint "forum_post_id"
    t.text "title", default: "", null: false
    t.inet "creator_ip_addr", default: "127.0.0.1", null: false
    t.bigint "updater_id", null: false
    t.inet "updater_ip_addr", null: false
    t.index ["forum_post_id"], name: "index_bulk_update_requests_on_forum_post_id"
    t.index ["updater_id"], name: "index_bulk_update_requests_on_updater_id"
  end

  create_table "comment_votes", force: :cascade do |t|
    t.bigint "comment_id", null: false
    t.bigint "user_id", null: false
    t.integer "score", null: false
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.inet "user_ip_addr", null: false
    t.boolean "is_locked", default: false, null: false
    t.index ["comment_id", "user_id"], name: "index_comment_votes_on_comment_id_and_user_id", unique: true
    t.index ["comment_id"], name: "index_comment_votes_on_comment_id"
    t.index ["created_at"], name: "index_comment_votes_on_created_at"
    t.index ["user_id"], name: "index_comment_votes_on_user_id"
  end

  create_table "comments", force: :cascade do |t|
    t.bigint "post_id", null: false
    t.bigint "creator_id", null: false
    t.text "body", null: false
    t.inet "creator_ip_addr", null: false
    t.integer "score", default: 0, null: false
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.bigint "updater_id", null: false
    t.inet "updater_ip_addr", null: false
    t.boolean "do_not_bump_post", default: false, null: false
    t.boolean "is_hidden", default: false, null: false
    t.boolean "is_sticky", default: false, null: false
    t.integer "warning_type"
    t.bigint "warning_user_id"
    t.bigint "notified_mentions", default: [], null: false, array: true
    t.boolean "is_spam", default: false, null: false
    t.index "lower(body) gin_trgm_ops", name: "index_comments_on_lower_body_trgm", using: :gin
    t.index "to_tsvector('english'::regconfig, body)", name: "index_comments_on_to_tsvector_english_body", using: :gin
    t.index ["creator_id", "post_id"], name: "index_comments_on_creator_id_and_post_id"
    t.index ["creator_id"], name: "index_comments_on_creator_id"
    t.index ["creator_ip_addr"], name: "index_comments_on_creator_ip_addr"
    t.index ["post_id", "is_hidden"], name: "index_comments_on_post_id_and_is_hidden"
    t.index ["post_id"], name: "index_comments_on_post_id"
  end

  create_table "config", id: :text, default: "config", force: :cascade do |t|
    t.text "contributor_suffixes", default: "va, modeler", null: false
    t.integer "comment_bump_threshold", default: 40, null: false
    t.integer "pending_uploads_limit", default: 3, null: false
    t.integer "comment_limit", default: 15, null: false
    t.integer "comment_limit_bypass", default: 15, null: false
    t.integer "comment_vote_limit", default: 25, null: false
    t.integer "comment_vote_limit_bypass", default: 15, null: false
    t.integer "post_vote_limit", default: 1000, null: false
    t.integer "post_vote_limit_bypass", default: 15, null: false
    t.integer "dmail_minute_limit", default: 2, null: false
    t.integer "dmail_minute_limit_bypass", default: 20, null: false
    t.integer "dmail_hour_limit", default: 30, null: false
    t.integer "dmail_hour_limit_bypass", default: 20, null: false
    t.integer "dmail_day_limit", default: 60, null: false
    t.integer "dmail_day_limit_bypass", default: 20, null: false
    t.integer "dmail_restricted_day_limit", default: 5, null: false
    t.integer "tag_suggestion_limit", default: 15, null: false
    t.integer "tag_suggestion_limit_bypass", default: 15, null: false
    t.integer "forum_vote_limit", default: 25, null: false
    t.integer "forum_vote_limit_bypass", default: 15, null: false
    t.integer "artist_edit_limit", default: 25, null: false
    t.integer "artist_edit_limit_bypass", default: 15, null: false
    t.integer "wiki_edit_limit", default: 60, null: false
    t.integer "wiki_edit_limit_bypass", default: 15, null: false
    t.integer "note_edit_limit", default: 50, null: false
    t.integer "note_edit_limit_bypass", default: 15, null: false
    t.integer "pool_limit", default: 2, null: false
    t.integer "pool_limit_bypass", default: 15, null: false
    t.integer "pool_edit_limit", default: 10, null: false
    t.integer "pool_edit_limit_bypass", default: 15, null: false
    t.integer "pool_post_edit_limit", default: 30, null: false
    t.integer "pool_post_edit_limit_bypass", default: 15, null: false
    t.integer "post_edit_limit", default: 150, null: false
    t.integer "post_edit_limit_bypass", default: 15, null: false
    t.integer "post_appeal_limit", default: 5, null: false
    t.integer "post_appeal_limit_bypass", default: 15, null: false
    t.integer "post_flag_limit", default: 20, null: false
    t.integer "post_flag_limit_bypass", default: 15, null: false
    t.integer "hourly_upload_limit", default: 30, null: false
    t.integer "ticket_limit", default: 30, null: false
    t.integer "ticket_limit_bypass", default: 15, null: false
    t.integer "pool_category_change_limit", default: 30, null: false
    t.integer "post_replacement_per_day_limit", default: 2, null: false
    t.integer "post_replacement_per_day_limit_bypass", default: 20, null: false
    t.integer "post_replacement_per_post_limit", default: 5, null: false
    t.integer "post_replacement_per_post_limit_bypass", default: 20, null: false
    t.integer "compact_uploader_minimum_posts", default: 10, null: false
    t.integer "tag_query_limit", default: 40, null: false
    t.jsonb "bur_entry_limit", default: {"10" => 50, "40" => -1}, null: false
    t.integer "max_numbered_pages", default: 1000, null: false
    t.integer "max_per_page", default: 500, null: false
    t.integer "comment_max_size", default: 10000, null: false
    t.integer "dmail_max_size", default: 50000, null: false
    t.integer "forum_post_max_size", default: 50000, null: false
    t.integer "forum_category_description_max_size", default: 250, null: false
    t.integer "note_max_size", default: 1000, null: false
    t.integer "pool_description_max_size", default: 10000, null: false
    t.integer "post_description_max_size", default: 50000, null: false
    t.integer "ticket_max_size", default: 5000, null: false
    t.integer "user_about_max_size", default: 50000, null: false
    t.integer "blacklisted_tags_max_size", default: 150000, null: false
    t.integer "custom_style_max_size", default: 500000, null: false
    t.integer "wiki_page_max_size", default: 250000, null: false
    t.integer "user_feedback_max_size", default: 20000, null: false
    t.integer "news_update_max_size", default: 50000, null: false
    t.integer "pool_post_limit", default: 1000, null: false
    t.integer "pool_post_limit_bypass", default: 40, null: false
    t.integer "set_post_limit", default: 10000, null: false
    t.integer "set_post_limit_bypass", default: 40, null: false
    t.integer "disapproval_message_max_size", default: 250, null: false
    t.integer "max_upload_per_request", default: 75, null: false
    t.integer "max_file_size", default: 200, null: false
    t.jsonb "max_file_sizes", default: {"gif" => 30, "jpg" => 100, "mp4" => 200, "png" => 100, "apng" => 30, "webm" => 200, "webp" => 100}, null: false
    t.jsonb "max_mascot_file_sizes", default: {"jpg" => 1000, "png" => 1000, "webp" => 1000}, null: false
    t.integer "max_video_duration", default: 1800, null: false
    t.integer "max_image_resolution", default: 441, null: false
    t.integer "max_tags_per_post", default: 2000, null: false
    t.boolean "enable_signups", default: true, null: false
    t.boolean "user_approvals_enabled", default: true, null: false
    t.boolean "enable_email_verification", default: false, null: false
    t.boolean "enable_stale_forum_topics", default: true, null: false
    t.boolean "enable_sock_puppet_validation", default: false, null: false
    t.integer "forum_topic_stale_window", default: 180, null: false
    t.integer "forum_topic_aibur_stale_window", default: 365, null: false
    t.string "flag_notice_wiki_page", default: "internal:flag_notice", null: false
    t.string "replacement_notice_wiki_page", default: "internal:replacement_notice", null: false
    t.string "avoid_posting_notice_wiki_page", default: "internal:avoid_posting_notice", null: false
    t.string "discord_notice_wiki_page", default: "internal:discord_notice", null: false
    t.string "rules_body_wiki_page", default: "internal:rules_body", null: false
    t.string "restricted_notice_wiki_page", default: "internal:restricted_notice", null: false
    t.string "rejected_notice_wiki_page", default: "internal:rejected_notice", null: false
    t.string "appeal_notice_wiki_page", default: "internal:appeal_notice", null: false
    t.string "ban_notice_wiki_page", default: "internal:ban_notice", null: false
    t.string "user_approved_wiki_page", default: "internal:user_approved", null: false
    t.string "user_rejected_wiki_page", default: "internal:user_rejected", null: false
    t.integer "records_per_page", default: 100, null: false
    t.jsonb "tag_change_request_update_limit", default: {"15" => 500, "20" => 1000, "30" => 10000, "40" => 100000, "50" => -1}, null: false
    t.jsonb "followed_tag_limit", default: {"10" => 100, "15" => 500, "20" => 1000}, null: false
    t.jsonb "tag_type_edit_limit", default: {"10" => 100, "15" => 1000, "20" => 10000, "40" => -1}, null: false
    t.jsonb "tag_type_edit_implicit_limit", default: {"10" => 100, "15" => 1000}, null: false
    t.integer "alias_category_change_cutoff", default: 10000, null: false
    t.integer "max_multi_count", default: 100, null: false
    t.string "takedown_email", default: "admin@gayfur.city", null: false
    t.string "contact_email", default: "admin@gayfur.city", null: false
    t.string "default_user_timezone", default: "Central Time (US & Canada)"
    t.integer "alias_and_implication_forum_category", default: 1, null: false
    t.integer "default_forum_category", default: 1, null: false
    t.integer "upload_whitelists_forum_topic", default: 0, null: false
    t.integer "post_sample_size", default: 300, null: false
    t.datetime "updated_at"
    t.text "lore_suffixes", default: "lore", null: false
    t.text "artist_exclusion_tags", default: "avoid_posting, conditional_dnp, epilepsy_warning, sound_warning", null: false
    t.boolean "flag_ai_posts", default: true, null: false
    t.boolean "tag_ai_posts", default: true, null: false
    t.integer "ai_confidence_threshold", default: 50, null: false
    t.integer "post_flag_note_max_size", default: 10000, null: false
    t.string "db_exports_path", default: "/db_exports"
    t.integer "pool_category_change_cutoff", default: 30, null: false
    t.integer "pool_category_change_cutoff_bypass", default: 20, null: false
    t.integer "pool_name_max_size", default: 250, null: false
    t.string "default_blacklist", default: "", null: false
    t.string "safeblocked_tags", default: "", null: false
    t.boolean "enable_autotagging", default: true, null: false
    t.boolean "enable_image_cropping", default: true, null: false
    t.boolean "enable_bad_sources", default: true, null: false
    t.boolean "safe_mode", default: false, null: false
    t.integer "show_tag_scripting", default: 15, null: false
    t.integer "show_backtrace", default: 20, null: false
    t.integer "bur_nuke", default: 40, null: false
    t.string "app_name", default: "GayFur City", null: false
    t.string "canonical_app_name", default: "GayFur City", null: false
    t.string "app_description", default: "Your one-stop shop for gay furries.", null: false
    t.string "anonymous_user_name", default: "Anonymous", null: false
    t.string "system_user_name", default: "System", null: false
    t.jsonb "image_width", default: {"max" => 40000, "min" => 300}, null: false
    t.jsonb "image_height", default: {"max" => 40000, "min" => 300}, null: false
    t.jsonb "mascot_width", default: {"max" => 1000, "min" => 250}, null: false
    t.jsonb "mascot_height", default: {"max" => 1000, "min" => 250}, null: false
  end

  create_table "destroyed_posts", force: :cascade do |t|
    t.bigint "post_id", null: false
    t.string "md5", null: false
    t.bigint "destroyer_id", null: false
    t.inet "destroyer_ip_addr", null: false
    t.bigint "uploader_id", null: false
    t.inet "uploader_ip_addr", null: false
    t.datetime "upload_date", precision: nil
    t.json "post_data", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "reason", default: "", null: false
    t.boolean "notify", default: true, null: false
  end

  create_table "dmail_filters", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.text "words", null: false
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.index ["user_id"], name: "index_dmail_filters_on_user_id", unique: true
  end

  create_table "dmails", force: :cascade do |t|
    t.bigint "owner_id", null: false
    t.bigint "from_id", null: false
    t.bigint "to_id", null: false
    t.text "title", null: false
    t.text "body", null: false
    t.boolean "is_read", default: false, null: false
    t.boolean "is_deleted", default: false, null: false
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.inet "from_ip_addr", null: false
    t.string "key", default: "", null: false
    t.bigint "respond_to_id"
    t.boolean "is_spam", default: false, null: false
    t.index "lower(body) gin_trgm_ops", name: "index_dmails_on_lower_body_trgm", using: :gin
    t.index "to_tsvector('english'::regconfig, body)", name: "index_dmails_on_to_tsvector_english_body", using: :gin
    t.index ["from_ip_addr"], name: "index_dmails_on_from_ip_addr"
    t.index ["is_deleted"], name: "index_dmails_on_is_deleted"
    t.index ["is_read"], name: "index_dmails_on_is_read"
    t.index ["owner_id"], name: "index_dmails_on_owner_id"
    t.index ["respond_to_id"], name: "index_dmails_on_respond_to_id"
  end

  create_table "dtext_links", force: :cascade do |t|
    t.string "model_type", null: false
    t.bigint "model_id", null: false
    t.integer "link_type", null: false
    t.string "link_target", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["link_target", "model_type", "model_id"], name: "index_dtext_links_on_link_target_and_model_type_and_model_id", unique: true
    t.index ["link_target"], name: "index_dtext_links_on_link_target", opclass: :text_pattern_ops
    t.index ["link_type"], name: "index_dtext_links_on_link_type"
    t.index ["model_type", "model_id"], name: "index_dtext_links_on_model"
  end

  create_table "edit_histories", force: :cascade do |t|
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.text "body", null: false
    t.text "subject"
    t.string "versionable_type", limit: 100, null: false
    t.bigint "versionable_id", null: false
    t.integer "version", null: false
    t.inet "updater_ip_addr", null: false
    t.bigint "updater_id", null: false
    t.text "edit_type", default: "original", null: false
    t.jsonb "extra_data", default: {}, null: false
    t.index ["updater_id"], name: "index_edit_histories_on_updater_id"
    t.index ["versionable_id", "versionable_type"], name: "index_edit_histories_on_versionable_id_and_versionable_type"
  end

  create_table "email_blacklists", force: :cascade do |t|
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.string "domain", null: false
    t.bigint "creator_id", null: false
    t.string "reason", null: false
    t.inet "creator_ip_addr", null: false
    t.index "lower((domain)::text)", name: "index_email_blacklists_on_lower_domain", unique: true
  end

  create_table "exception_logs", force: :cascade do |t|
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.string "class_name", null: false
    t.inet "ip_addr", null: false
    t.string "version", null: false
    t.text "extra_params", default: "{}", null: false
    t.text "message", null: false
    t.text "trace", null: false
    t.uuid "code", null: false
    t.bigint "user_id"
  end

  create_table "favorites", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "post_id", null: false
    t.datetime "created_at", precision: nil, default: -> { "now()" }, null: false
    t.index ["post_id"], name: "index_favorites_on_post_id"
    t.index ["user_id", "post_id"], name: "index_favorites_on_user_id_and_post_id", unique: true
    t.index ["user_id"], name: "index_favorites_on_user_id"
  end

  create_table "forum_categories", force: :cascade do |t|
    t.string "name", null: false
    t.integer "order", null: false
    t.integer "can_view", default: 0, null: false
    t.integer "can_create", default: 10, null: false
    t.text "description", default: "", null: false
    t.integer "topic_count", default: 0, null: false
    t.integer "post_count", default: 0, null: false
    t.bigint "creator_id", null: false
    t.inet "creator_ip_addr", null: false
    t.bigint "updater_id", null: false
    t.inet "updater_ip_addr", null: false
    t.index "lower((name)::text)", name: "index_forum_categories_on_lower_name", unique: true
    t.index ["creator_id"], name: "index_forum_categories_on_creator_id"
    t.index ["updater_id"], name: "index_forum_categories_on_updater_id"
  end

  create_table "forum_category_visits", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "forum_category_id", null: false
    t.datetime "last_read_at", default: -> { "CURRENT_TIMESTAMP" }, null: false
    t.index ["forum_category_id"], name: "index_forum_category_visits_on_forum_category_id"
    t.index ["last_read_at"], name: "index_forum_category_visits_on_last_read_at"
    t.index ["user_id"], name: "index_forum_category_visits_on_user_id"
  end

  create_table "forum_post_votes", force: :cascade do |t|
    t.bigint "forum_post_id", null: false
    t.bigint "user_id", null: false
    t.integer "score", null: false
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.inet "user_ip_addr", null: false
    t.index ["forum_post_id", "user_id"], name: "index_forum_post_votes_on_forum_post_id_and_user_id", unique: true
    t.index ["forum_post_id"], name: "index_forum_post_votes_on_forum_post_id"
  end

  create_table "forum_posts", force: :cascade do |t|
    t.bigint "topic_id", null: false
    t.bigint "creator_id", null: false
    t.bigint "updater_id", null: false
    t.text "body", null: false
    t.boolean "is_hidden", default: false, null: false
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.inet "creator_ip_addr", null: false
    t.integer "warning_type"
    t.bigint "warning_user_id"
    t.bigint "tag_change_request_id"
    t.string "tag_change_request_type"
    t.bigint "notified_mentions", default: [], null: false, array: true
    t.boolean "is_spam", default: false, null: false
    t.bigint "original_topic_id"
    t.datetime "merged_at"
    t.boolean "allow_voting", default: false, null: false
    t.integer "total_score", default: 0, null: false
    t.decimal "percentage_score", default: "0.0", null: false
    t.integer "total_votes", default: 0, null: false
    t.integer "up_votes", default: 0, null: false
    t.integer "down_votes", default: 0, null: false
    t.integer "meh_votes", default: 0, null: false
    t.inet "updater_ip_addr", null: false
    t.index "lower(body) gin_trgm_ops", name: "index_forum_posts_on_lower_body_trgm", using: :gin
    t.index "to_tsvector('english'::regconfig, body)", name: "index_forum_posts_on_to_tsvector_english_body", using: :gin
    t.index ["creator_id"], name: "index_forum_posts_on_creator_id"
    t.index ["original_topic_id"], name: "index_forum_posts_on_original_topic_id"
    t.index ["topic_id"], name: "index_forum_posts_on_topic_id"
  end

  create_table "forum_topic_statuses", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "forum_topic_id", null: false
    t.datetime "subscription_last_read_at"
    t.boolean "subscription", default: false, null: false
    t.boolean "mute", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["forum_topic_id"], name: "index_forum_topic_statuses_on_forum_topic_id"
    t.index ["user_id"], name: "index_forum_topic_statuses_on_user_id"
  end

  create_table "forum_topics", force: :cascade do |t|
    t.bigint "creator_id", null: false
    t.bigint "updater_id", null: false
    t.string "title", null: false
    t.integer "response_count", default: 0, null: false
    t.boolean "is_sticky", default: false, null: false
    t.boolean "is_locked", default: false, null: false
    t.boolean "is_hidden", default: false, null: false
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.bigint "category_id", default: 0, null: false
    t.inet "creator_ip_addr", null: false
    t.datetime "last_post_created_at", default: -> { "CURRENT_TIMESTAMP" }, null: false
    t.bigint "merge_target_id"
    t.datetime "merged_at"
    t.inet "updater_ip_addr", null: false
    t.index "lower((title)::text) gin_trgm_ops", name: "index_forum_topics_on_lower_title_trgm", using: :gin
    t.index "to_tsvector('english'::regconfig, (title)::text)", name: "index_forum_topics_on_to_tsvector_english_title", using: :gin
    t.index ["creator_id"], name: "index_forum_topics_on_creator_id"
    t.index ["is_sticky", "updated_at"], name: "index_forum_topics_on_is_sticky_and_updated_at"
    t.index ["merge_target_id"], name: "index_forum_topics_on_merge_target_id"
    t.index ["updated_at"], name: "index_forum_topics_on_updated_at"
  end

  create_table "help_pages", force: :cascade do |t|
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.string "name", null: false
    t.string "related", default: "", null: false
    t.string "title", default: "", null: false
    t.bigint "wiki_page_id", null: false
    t.bigint "creator_id", null: false
    t.inet "creator_ip_addr", null: false
    t.bigint "updater_id", null: false
    t.inet "updater_ip_addr", null: false
    t.index ["creator_id"], name: "index_help_pages_on_creator_id"
    t.index ["updater_id"], name: "index_help_pages_on_updater_id"
    t.index ["wiki_page_id"], name: "index_help_pages_on_wiki_page_id"
  end

  create_table "ip_bans", force: :cascade do |t|
    t.bigint "creator_id", null: false
    t.inet "ip_addr", null: false
    t.text "reason", null: false
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.inet "creator_ip_addr", null: false
    t.index ["ip_addr"], name: "index_ip_bans_on_ip_addr", unique: true
  end

  create_table "mascot_media_assets", force: :cascade do |t|
    t.bigint "creator_id", null: false
    t.bigint "media_metadata_id", null: false
    t.inet "creator_ip_addr", null: false
    t.string "checksum", limit: 32
    t.string "md5", limit: 32
    t.string "file_ext", limit: 4
    t.boolean "is_animated_png"
    t.boolean "is_animated_gif"
    t.integer "file_size"
    t.integer "image_width"
    t.integer "image_height"
    t.decimal "duration"
    t.integer "framecount"
    t.string "pixel_hash", limit: 32
    t.string "status", default: "pending", null: false
    t.string "status_message"
    t.integer "last_chunk_id", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "is_animated_webp"
    t.index ["checksum"], name: "index_mascot_media_assets_on_checksum"
    t.index ["creator_id"], name: "index_mascot_media_assets_on_creator_id"
    t.index ["md5"], name: "index_mascot_media_assets_on_md5", unique: true, where: "((status)::text = 'active'::text)"
    t.index ["media_metadata_id"], name: "index_mascot_media_assets_on_media_metadata_id"
    t.index ["pixel_hash"], name: "index_mascot_media_assets_on_pixel_hash"
  end

  create_table "mascots", force: :cascade do |t|
    t.bigint "creator_id", null: false
    t.string "display_name", null: false
    t.string "background_color", null: false
    t.string "artist_url", null: false
    t.string "artist_name", null: false
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "available_on", default: [], null: false, array: true
    t.boolean "hide_anonymous", default: false, null: false
    t.bigint "mascot_media_asset_id"
    t.inet "creator_ip_addr", null: false
    t.bigint "updater_id", null: false
    t.inet "updater_ip_addr", null: false
    t.index "lower((display_name)::text)", name: "index_mascots_on_lower_display_name", unique: true
    t.index ["creator_id"], name: "index_mascots_on_creator_id"
    t.index ["mascot_media_asset_id"], name: "index_mascots_on_mascot_media_asset_id"
    t.index ["updater_id"], name: "index_mascots_on_updater_id"
  end

  create_table "media_metadata", force: :cascade do |t|
    t.jsonb "metadata", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "mod_actions", force: :cascade do |t|
    t.bigint "creator_id", null: false
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.text "action", null: false
    t.json "values", default: {}, null: false
    t.bigint "subject_id"
    t.string "subject_type"
    t.inet "creator_ip_addr", null: false
    t.index ["action"], name: "index_mod_actions_on_action"
  end

  create_table "news_updates", force: :cascade do |t|
    t.text "message", null: false
    t.bigint "creator_id", null: false
    t.bigint "updater_id", null: false
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.inet "creator_ip_addr", null: false
    t.inet "updater_ip_addr", null: false
    t.index ["created_at"], name: "index_news_updates_on_created_at"
  end

  create_table "note_versions", force: :cascade do |t|
    t.bigint "note_id", null: false
    t.bigint "post_id", null: false
    t.bigint "updater_id", null: false
    t.inet "updater_ip_addr", null: false
    t.integer "x", null: false
    t.integer "y", null: false
    t.integer "width", null: false
    t.integer "height", null: false
    t.boolean "is_active", default: true, null: false
    t.text "body", null: false
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.integer "version", null: false
    t.index ["created_at"], name: "index_note_versions_on_created_at"
    t.index ["note_id"], name: "index_note_versions_on_note_id"
    t.index ["post_id"], name: "index_note_versions_on_post_id"
    t.index ["updater_id", "post_id"], name: "index_note_versions_on_updater_id_and_post_id"
    t.index ["updater_ip_addr"], name: "index_note_versions_on_updater_ip_addr"
  end

  create_table "notes", force: :cascade do |t|
    t.bigint "creator_id", null: false
    t.bigint "post_id", null: false
    t.integer "x", null: false
    t.integer "y", null: false
    t.integer "width", null: false
    t.integer "height", null: false
    t.boolean "is_active", default: true, null: false
    t.text "body", null: false
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.integer "version", default: 0, null: false
    t.inet "creator_ip_addr", null: false
    t.index "lower(body) gin_trgm_ops", name: "index_notes_on_lower_body_trgm", using: :gin
    t.index "to_tsvector('english'::regconfig, body)", name: "index_notes_on_to_tsvector_english_body", using: :gin
    t.index ["creator_id", "post_id"], name: "index_notes_on_creator_id_and_post_id"
    t.index ["post_id", "is_active"], name: "index_notes_on_post_id_and_is_active"
    t.index ["post_id"], name: "index_notes_on_post_id"
  end

  create_table "notifications", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.integer "category", default: 0, null: false
    t.json "data", default: {}, null: false
    t.boolean "is_read", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_notifications_on_user_id"
  end

  create_table "pool_versions", force: :cascade do |t|
    t.bigint "pool_id", null: false
    t.bigint "post_ids", default: [], null: false, array: true
    t.bigint "added_post_ids", default: [], null: false, array: true
    t.bigint "removed_post_ids", default: [], null: false, array: true
    t.bigint "updater_id", null: false
    t.inet "updater_ip_addr", null: false
    t.text "description", null: false
    t.boolean "description_changed", default: false, null: false
    t.text "name", default: "", null: false
    t.boolean "name_changed", default: false, null: false
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.boolean "is_ongoing", default: true, null: false
    t.integer "version", default: 1, null: false
    t.boolean "is_ongoing_changed", default: false, null: false
    t.string "category", null: false
    t.boolean "category_changed", default: false, null: false
    t.index ["pool_id"], name: "index_pool_versions_on_pool_id"
    t.index ["updater_id"], name: "index_pool_versions_on_updater_id"
    t.index ["updater_ip_addr"], name: "index_pool_versions_on_updater_ip_addr"
  end

  create_table "pools", force: :cascade do |t|
    t.string "name", null: false
    t.bigint "creator_id", null: false
    t.text "description", default: "", null: false
    t.boolean "is_ongoing", default: true, null: false
    t.bigint "post_ids", default: [], null: false, array: true
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.string "artist_names", default: [], null: false, array: true
    t.bigint "cover_post_id"
    t.inet "creator_ip_addr", null: false
    t.string "category", default: "series", null: false
    t.index "lower((name)::text) gin_trgm_ops", name: "index_pools_on_name_trgm", using: :gin
    t.index "lower((name)::text)", name: "index_pools_on_lower_name"
    t.index ["cover_post_id"], name: "index_pools_on_cover_post_id"
    t.index ["creator_id"], name: "index_pools_on_creator_id"
    t.index ["name"], name: "index_pools_on_name"
    t.index ["post_ids"], name: "index_pools_on_post_ids", using: :gin
    t.index ["updated_at"], name: "index_pools_on_updated_at"
  end

  create_table "post_appeals", force: :cascade do |t|
    t.bigint "post_id", null: false
    t.bigint "creator_id", null: false
    t.inet "creator_ip_addr", null: false
    t.string "reason", default: "", null: false
    t.integer "status", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "updater_id", null: false
    t.inet "updater_ip_addr", null: false
    t.index ["creator_id"], name: "index_post_appeals_on_creator_id"
    t.index ["post_id", "status"], name: "index_post_appeals_on_post_id_and_status"
    t.index ["post_id"], name: "index_post_appeals_on_post_id"
    t.index ["updater_id"], name: "index_post_appeals_on_updater_id"
  end

  create_table "post_approvals", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "post_id", null: false
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.inet "user_ip_addr", null: false
    t.index ["post_id"], name: "index_post_approvals_on_post_id"
    t.index ["user_id"], name: "index_post_approvals_on_user_id"
  end

  create_table "post_deletion_reasons", force: :cascade do |t|
    t.bigint "creator_id", null: false
    t.string "reason", null: false
    t.string "title"
    t.string "prompt"
    t.integer "order", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.inet "creator_ip_addr", null: false
    t.bigint "updater_id", null: false
    t.inet "updater_ip_addr", null: false
    t.index "lower((prompt)::text)", name: "index_post_deletion_reasons_on_lower_prompt", unique: true, where: "((title)::text <> ''::text)"
    t.index "lower((reason)::text)", name: "index_post_deletion_reasons_on_lower_reason", unique: true
    t.index "lower((title)::text)", name: "index_post_deletion_reasons_on_lower_title", unique: true, where: "((title)::text <> ''::text)"
    t.index ["creator_id"], name: "index_post_deletion_reasons_on_creator_id"
    t.index ["order"], name: "index_post_deletion_reasons_on_order", unique: true
    t.index ["updater_id"], name: "index_post_deletion_reasons_on_updater_id"
  end

  create_table "post_disapprovals", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "post_id", null: false
    t.string "reason", null: false
    t.text "message", default: "", null: false
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.inet "user_ip_addr", null: false
    t.index ["post_id", "user_id"], name: "index_post_disapprovals_on_post_id_and_user_id", unique: true
    t.index ["post_id"], name: "index_post_disapprovals_on_post_id"
    t.index ["user_id"], name: "index_post_disapprovals_on_user_id"
  end

  create_table "post_events", force: :cascade do |t|
    t.bigint "creator_id", null: false
    t.bigint "post_id", null: false
    t.integer "action", null: false
    t.jsonb "extra_data", null: false
    t.datetime "created_at", precision: nil, null: false
    t.inet "creator_ip_addr", null: false
    t.index ["creator_id"], name: "index_post_events_on_creator_id"
    t.index ["post_id"], name: "index_post_events_on_post_id"
  end

  create_table "post_flags", force: :cascade do |t|
    t.bigint "post_id", null: false
    t.bigint "creator_id", null: false
    t.inet "creator_ip_addr", null: false
    t.text "reason", null: false
    t.boolean "is_resolved", default: false, null: false
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.boolean "is_deletion", default: false, null: false
    t.string "note"
    t.index "to_tsvector('english'::regconfig, reason)", name: "index_post_flags_on_reason_tsvector", using: :gin
    t.index ["creator_id"], name: "index_post_flags_on_creator_id"
    t.index ["creator_ip_addr"], name: "index_post_flags_on_creator_ip_addr"
    t.index ["post_id", "is_resolved", "is_deletion"], name: "index_post_flags_on_post_id_and_is_resolved_and_is_deletion"
    t.index ["post_id"], name: "index_post_flags_on_post_id"
  end

  create_table "post_replacement_media_assets", force: :cascade do |t|
    t.bigint "creator_id", null: false
    t.bigint "media_metadata_id", null: false
    t.inet "creator_ip_addr", null: false
    t.string "checksum", limit: 32
    t.string "md5", limit: 32
    t.string "file_ext", limit: 4
    t.boolean "is_animated_png"
    t.boolean "is_animated_gif"
    t.integer "file_size"
    t.integer "image_width"
    t.integer "image_height"
    t.decimal "duration"
    t.integer "framecount"
    t.string "pixel_hash", limit: 32
    t.string "status", default: "pending", null: false
    t.string "status_message"
    t.string "storage_id", null: false
    t.integer "last_chunk_id", default: 0, null: false
    t.jsonb "generated_variants", default: [], null: false
    t.jsonb "variants_data", default: [], null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "is_animated_webp"
    t.index ["checksum"], name: "index_post_replacement_media_assets_on_checksum"
    t.index ["creator_id"], name: "index_post_replacement_media_assets_on_creator_id"
    t.index ["md5"], name: "index_post_replacement_media_assets_on_md5"
    t.index ["media_metadata_id"], name: "index_post_replacement_media_assets_on_media_metadata_id"
    t.index ["pixel_hash"], name: "index_post_replacement_media_assets_on_pixel_hash"
    t.index ["storage_id"], name: "index_post_replacement_media_assets_on_storage_id", unique: true
  end

  create_table "post_replacement_rejection_reasons", force: :cascade do |t|
    t.bigint "creator_id", null: false
    t.string "reason", null: false
    t.integer "order", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.inet "creator_ip_addr", null: false
    t.bigint "updater_id", null: false
    t.inet "updater_ip_addr", null: false
    t.index "lower((reason)::text)", name: "index_post_replacement_rejection_reasons_on_lower_reason", unique: true
    t.index ["creator_id"], name: "index_post_replacement_rejection_reasons_on_creator_id"
    t.index ["order"], name: "index_post_replacement_rejection_reasons_on_order", unique: true
    t.index ["updater_id"], name: "index_post_replacement_rejection_reasons_on_updater_id"
  end

  create_table "post_replacements", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "post_id", null: false
    t.bigint "creator_id", null: false
    t.inet "creator_ip_addr", null: false
    t.bigint "approver_id"
    t.string "source", default: "", null: false
    t.string "file_name"
    t.string "status", default: "uploading", null: false
    t.string "reason", null: false
    t.bigint "uploader_id_on_approve"
    t.boolean "penalize_uploader_on_approve"
    t.bigint "rejector_id"
    t.string "rejection_reason", default: "", null: false
    t.jsonb "previous_details"
    t.bigint "post_replacement_media_asset_id"
    t.index ["creator_id"], name: "index_post_replacements_on_creator_id"
    t.index ["post_id", "status"], name: "index_post_replacements_on_post_id_and_status"
    t.index ["post_id"], name: "index_post_replacements_on_post_id"
    t.index ["post_replacement_media_asset_id"], name: "index_post_replacements_on_post_replacement_media_asset_id"
    t.index ["rejector_id"], name: "index_post_replacements_on_rejector_id"
  end

  create_table "post_set_maintainers", force: :cascade do |t|
    t.bigint "post_set_id", null: false
    t.bigint "user_id", null: false
    t.string "status", default: "pending", null: false
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
  end

  create_table "post_sets", force: :cascade do |t|
    t.string "name", null: false
    t.string "shortname", null: false
    t.text "description", default: "", null: false
    t.boolean "is_public", default: false, null: false
    t.boolean "transfer_on_delete", default: false, null: false
    t.bigint "creator_id", null: false
    t.inet "creator_ip_addr", null: false
    t.bigint "post_ids", default: [], null: false, array: true
    t.integer "post_count", default: 0, null: false
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.bigint "updater_id", null: false
    t.inet "updater_ip_addr", null: false
    t.index ["post_ids"], name: "index_post_sets_on_post_ids", using: :gin
    t.index ["updater_id"], name: "index_post_sets_on_updater_id"
  end

  create_table "post_versions", force: :cascade do |t|
    t.bigint "post_id", null: false
    t.text "tags", null: false
    t.text "added_tags", default: [], null: false, array: true
    t.text "removed_tags", default: [], null: false, array: true
    t.text "locked_tags", default: "", null: false
    t.text "added_locked_tags", default: [], null: false, array: true
    t.text "removed_locked_tags", default: [], null: false, array: true
    t.bigint "updater_id", null: false
    t.inet "updater_ip_addr", null: false
    t.datetime "updated_at", precision: nil, null: false
    t.string "rating", limit: 1, null: false
    t.boolean "rating_changed", default: false, null: false
    t.bigint "parent_id"
    t.boolean "parent_changed", default: false, null: false
    t.text "source", default: "", null: false
    t.boolean "source_changed", default: false, null: false
    t.text "description", default: "", null: false
    t.boolean "description_changed", default: false, null: false
    t.integer "version", default: 1, null: false
    t.string "reason"
    t.text "original_tags", default: "", null: false
    t.index ["post_id"], name: "index_post_versions_on_post_id"
    t.index ["updated_at"], name: "index_post_versions_on_updated_at"
    t.index ["updater_id"], name: "index_post_versions_on_updater_id"
    t.index ["updater_ip_addr"], name: "index_post_versions_on_updater_ip_addr"
  end

  create_table "post_votes", force: :cascade do |t|
    t.bigint "post_id", null: false
    t.bigint "user_id", null: false
    t.integer "score", null: false
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.inet "user_ip_addr", null: false
    t.boolean "is_locked", default: false, null: false
    t.index ["post_id"], name: "index_post_votes_on_post_id"
    t.index ["score"], name: "index_post_votes_on_score"
    t.index ["user_id", "post_id"], name: "index_post_votes_on_user_id_and_post_id", unique: true
    t.index ["user_id"], name: "index_post_votes_on_user_id"
  end

  create_table "posts", force: :cascade do |t|
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil
    t.integer "up_score", default: 0, null: false
    t.integer "down_score", default: 0, null: false
    t.integer "score", default: 0, null: false
    t.string "source", null: false
    t.string "rating", limit: 1, default: "q", null: false
    t.boolean "is_note_locked", default: false, null: false
    t.boolean "is_rating_locked", default: false, null: false
    t.boolean "is_status_locked", default: false, null: false
    t.boolean "is_pending", default: false, null: false
    t.boolean "is_flagged", default: false, null: false
    t.boolean "is_deleted", default: false, null: false
    t.bigint "uploader_id", null: false
    t.inet "uploader_ip_addr", null: false
    t.bigint "approver_id"
    t.text "fav_string", default: "", null: false
    t.text "pool_string", default: "", null: false
    t.datetime "last_noted_at", precision: nil
    t.datetime "last_comment_bumped_at", precision: nil
    t.integer "fav_count", default: 0, null: false
    t.text "tag_string", default: "", null: false
    t.integer "tag_count", default: 0, null: false
    t.integer "tag_count_general", default: 0, null: false
    t.integer "tag_count_artist", default: 0, null: false
    t.integer "tag_count_character", default: 0, null: false
    t.integer "tag_count_copyright", default: 0, null: false
    t.bigint "parent_id"
    t.boolean "has_children", default: false, null: false
    t.datetime "last_commented_at", precision: nil
    t.boolean "has_active_children", default: false, null: false
    t.bigint "bit_flags", default: 0, null: false
    t.integer "tag_count_meta", default: 0, null: false
    t.text "locked_tags", default: "", null: false
    t.integer "tag_count_species", default: 0, null: false
    t.integer "tag_count_invalid", default: 0, null: false
    t.text "description", default: "", null: false
    t.integer "comment_count", default: 0, null: false
    t.bigserial "change_seq", null: false
    t.integer "tag_count_lore", default: 0, null: false
    t.string "bg_color"
    t.boolean "is_comment_disabled", default: false, null: false
    t.text "original_tag_string", default: "", null: false
    t.boolean "is_comment_locked", default: false, null: false
    t.string "qtags", default: [], null: false, array: true
    t.string "upload_url"
    t.string "vote_string", default: "", null: false
    t.integer "tag_count_gender", default: 0, null: false
    t.integer "thumbnail_frame"
    t.integer "tag_count_contributor", default: 0, null: false
    t.integer "min_edit_level", default: 10, null: false
    t.string "typed_tag_string", default: "", null: false
    t.bigint "upload_media_asset_id"
    t.bigint "updater_id", null: false
    t.inet "updater_ip_addr", null: false
    t.integer "tag_count_important", default: 0, null: false
    t.boolean "is_appealed", default: false, null: false
    t.index "string_to_array(tag_string, ' '::text)", name: "index_posts_on_string_to_array_tag_string", using: :gin
    t.index ["change_seq"], name: "index_posts_on_change_seq", unique: true
    t.index ["created_at"], name: "index_posts_on_created_at"
    t.index ["id"], name: "index_posts_on_id"
    t.index ["is_flagged"], name: "index_posts_on_is_flagged", where: "(is_flagged = true)"
    t.index ["is_pending"], name: "index_posts_on_is_pending", where: "(is_pending = true)"
    t.index ["parent_id"], name: "index_posts_on_parent_id"
    t.index ["updater_id"], name: "index_posts_on_updater_id"
    t.index ["upload_media_asset_id"], name: "index_posts_on_upload_media_asset_id"
    t.index ["uploader_id"], name: "index_posts_on_uploader_id"
    t.index ["uploader_ip_addr"], name: "index_posts_on_uploader_ip_addr"
  end

  create_table "quick_rules", force: :cascade do |t|
    t.bigint "rule_id"
    t.string "reason", null: false
    t.string "header"
    t.integer "order", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "creator_id", null: false
    t.inet "creator_ip_addr", null: false
    t.bigint "updater_id", null: false
    t.inet "updater_ip_addr", null: false
    t.index ["creator_id"], name: "index_quick_rules_on_creator_id"
    t.index ["order"], name: "index_quick_rules_on_order", unique: true
    t.index ["rule_id"], name: "index_quick_rules_on_rule_id"
    t.index ["updater_id"], name: "index_quick_rules_on_updater_id"
  end

  create_table "rule_categories", force: :cascade do |t|
    t.bigint "creator_id", null: false
    t.bigint "updater_id", null: false
    t.string "name", null: false
    t.integer "order", null: false
    t.string "anchor", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.inet "creator_ip_addr", null: false
    t.inet "updater_ip_addr", null: false
    t.index "lower((name)::text)", name: "index_rule_categories_on_lower_name", unique: true
    t.index ["creator_id"], name: "index_rule_categories_on_creator_id"
    t.index ["order"], name: "index_rule_categories_on_order", unique: true
    t.index ["updater_id"], name: "index_rule_categories_on_updater_id"
  end

  create_table "rules", force: :cascade do |t|
    t.bigint "creator_id", null: false
    t.bigint "updater_id", null: false
    t.bigint "category_id", null: false
    t.string "name", null: false
    t.text "description", null: false
    t.integer "order", null: false
    t.string "anchor", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.inet "creator_ip_addr", null: false
    t.inet "updater_ip_addr", null: false
    t.index "lower((name)::text)", name: "index_rules_on_lower_name", unique: true
    t.index ["category_id"], name: "index_rules_on_category_id"
    t.index ["creator_id"], name: "index_rules_on_creator_id"
    t.index ["order", "category_id"], name: "index_rules_on_order_and_category_id", unique: true
    t.index ["updater_id"], name: "index_rules_on_updater_id"
  end

  create_table "staff_audit_logs", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.string "action", default: "unknown_action", null: false
    t.json "values", default: "{}", null: false
    t.inet "user_ip_addr", null: false
    t.index ["user_id"], name: "index_staff_audit_logs_on_user_id"
  end

  create_table "staff_notes", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.bigint "creator_id", null: false
    t.string "body", null: false
    t.boolean "is_deleted", default: false, null: false
    t.bigint "updater_id", null: false
    t.inet "creator_ip_addr", null: false
    t.inet "updater_ip_addr", null: false
    t.index ["creator_id"], name: "index_staff_notes_on_creator_id"
    t.index ["updater_id"], name: "index_staff_notes_on_updater_id"
    t.index ["user_id"], name: "index_staff_notes_on_user_id"
  end

  create_table "tag_aliases", force: :cascade do |t|
    t.string "antecedent_name", null: false
    t.string "consequent_name", null: false
    t.bigint "creator_id", null: false
    t.inet "creator_ip_addr", null: false
    t.text "status", default: "pending", null: false
    t.datetime "created_at", precision: nil
    t.datetime "updated_at", precision: nil
    t.integer "post_count", default: 0, null: false
    t.bigint "approver_id"
    t.bigint "forum_post_id"
    t.bigint "forum_topic_id"
    t.text "reason", default: "", null: false
    t.jsonb "undo_data", default: [], null: false
    t.bigint "updater_id", null: false
    t.inet "updater_ip_addr", null: false
    t.index ["antecedent_name"], name: "index_tag_aliases_on_antecedent_name"
    t.index ["antecedent_name"], name: "index_tag_aliases_on_antecedent_name_pattern", opclass: :text_pattern_ops
    t.index ["consequent_name"], name: "index_tag_aliases_on_consequent_name"
    t.index ["forum_post_id"], name: "index_tag_aliases_on_forum_post_id"
    t.index ["post_count"], name: "index_tag_aliases_on_post_count"
    t.index ["updater_id"], name: "index_tag_aliases_on_updater_id"
  end

  create_table "tag_followers", force: :cascade do |t|
    t.bigint "tag_id", null: false
    t.bigint "user_id", null: false
    t.bigint "last_post_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["last_post_id"], name: "index_tag_followers_on_last_post_id"
    t.index ["tag_id"], name: "index_tag_followers_on_tag_id"
    t.index ["user_id"], name: "index_tag_followers_on_user_id"
  end

  create_table "tag_implications", force: :cascade do |t|
    t.string "antecedent_name", null: false
    t.string "consequent_name", null: false
    t.bigint "creator_id", null: false
    t.inet "creator_ip_addr", null: false
    t.text "status", default: "pending", null: false
    t.datetime "created_at", precision: nil
    t.datetime "updated_at", precision: nil
    t.bigint "approver_id"
    t.bigint "forum_post_id"
    t.bigint "forum_topic_id"
    t.text "descendant_names", default: [], array: true
    t.text "reason", default: "", null: false
    t.jsonb "undo_data", default: [], null: false
    t.bigint "updater_id", null: false
    t.inet "updater_ip_addr", null: false
    t.index ["antecedent_name"], name: "index_tag_implications_on_antecedent_name"
    t.index ["consequent_name"], name: "index_tag_implications_on_consequent_name"
    t.index ["forum_post_id"], name: "index_tag_implications_on_forum_post_id"
    t.index ["updater_id"], name: "index_tag_implications_on_updater_id"
  end

  create_table "tag_rel_undos", force: :cascade do |t|
    t.string "tag_rel_type"
    t.bigint "tag_rel_id"
    t.json "undo_data"
    t.boolean "applied", default: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["tag_rel_type", "tag_rel_id"], name: "index_tag_rel_undos_on_tag_rel_type_and_tag_rel_id"
  end

  create_table "tag_versions", force: :cascade do |t|
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.integer "category", null: false
    t.boolean "is_locked", null: false
    t.bigint "tag_id", null: false
    t.bigint "updater_id", null: false
    t.string "reason", default: "", null: false
    t.boolean "is_deprecated", null: false
    t.inet "updater_ip_addr", null: false
    t.index ["tag_id"], name: "index_tag_versions_on_tag_id"
    t.index ["updater_id"], name: "index_tag_versions_on_updater_id"
  end

  create_table "tags", force: :cascade do |t|
    t.string "name", null: false
    t.integer "post_count", default: 0, null: false
    t.integer "category", limit: 2, default: 0, null: false
    t.text "related_tags"
    t.datetime "related_tags_updated_at", precision: nil
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.boolean "is_locked", default: false, null: false
    t.integer "follower_count", default: 0, null: false
    t.boolean "is_deprecated", default: false, null: false
    t.bigint "creator_id", null: false
    t.inet "creator_ip_addr", null: false
    t.index "regexp_replace((name)::text, '([a-z0-9])[a-z0-9'']*($|[^a-z0-9'']+)'::text, '\\1'::text, 'g'::text) gin_trgm_ops", name: "index_tags_on_name_prefix", using: :gin
    t.index ["creator_id"], name: "index_tags_on_creator_id"
    t.index ["name"], name: "index_tags_on_name", unique: true
    t.index ["name"], name: "index_tags_on_name_pattern", opclass: :text_pattern_ops
    t.index ["name"], name: "index_tags_on_name_trgm", opclass: :gin_trgm_ops, using: :gin
  end

  create_table "takedowns", force: :cascade do |t|
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.bigint "creator_id"
    t.inet "creator_ip_addr", null: false
    t.bigint "approver_id"
    t.string "status", default: "pending", null: false
    t.string "vericode", null: false
    t.string "source", default: "", null: false
    t.string "email", null: false
    t.text "reason", default: "", null: false
    t.boolean "reason_hidden", default: false, null: false
    t.text "notes", default: "none", null: false
    t.text "instructions", default: "", null: false
    t.text "post_ids", default: "", null: false
    t.text "del_post_ids", default: "", null: false
    t.integer "post_count", default: 0, null: false
    t.bigint "updater_id"
    t.inet "updater_ip_addr"
    t.index ["updater_id"], name: "index_takedowns_on_updater_id"
  end

  create_table "tickets", force: :cascade do |t|
    t.bigint "creator_id", null: false
    t.inet "creator_ip_addr", null: false
    t.string "status", default: "pending", null: false
    t.string "reason"
    t.string "response", default: "", null: false
    t.bigint "handler_id"
    t.bigint "claimant_id"
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.bigint "accused_id"
    t.string "model_type", null: false
    t.bigint "model_id", null: false
    t.string "report_type", default: "report", null: false
    t.inet "handler_ip_addr"
  end

  create_table "upload_media_assets", force: :cascade do |t|
    t.bigint "creator_id", null: false
    t.bigint "media_metadata_id", null: false
    t.inet "creator_ip_addr", null: false
    t.string "checksum", limit: 32
    t.string "md5", limit: 32
    t.string "file_ext", limit: 4
    t.boolean "is_animated_png"
    t.boolean "is_animated_gif"
    t.integer "file_size"
    t.integer "image_width"
    t.integer "image_height"
    t.decimal "duration"
    t.integer "framecount"
    t.string "pixel_hash", limit: 32
    t.integer "last_chunk_id", default: 0, null: false
    t.string "status", default: "pending", null: false
    t.string "status_message"
    t.jsonb "generated_variants", default: [], null: false
    t.jsonb "variants_data", default: [], null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "is_animated_webp"
    t.index ["checksum"], name: "index_upload_media_assets_on_checksum"
    t.index ["creator_id"], name: "index_upload_media_assets_on_creator_id"
    t.index ["md5"], name: "index_upload_media_assets_on_md5", unique: true, where: "((status)::text = 'active'::text)"
    t.index ["media_metadata_id"], name: "index_upload_media_assets_on_media_metadata_id"
    t.index ["pixel_hash"], name: "index_upload_media_assets_on_pixel_hash"
  end

  create_table "upload_whitelists", force: :cascade do |t|
    t.string "pattern", null: false
    t.string "note"
    t.string "reason"
    t.boolean "allowed", default: true, null: false
    t.boolean "hidden", default: false, null: false
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.bigint "creator_id", null: false
    t.inet "creator_ip_addr", null: false
    t.bigint "updater_id", null: false
    t.inet "updater_ip_addr", null: false
    t.index ["creator_id"], name: "index_upload_whitelists_on_creator_id"
    t.index ["pattern"], name: "index_upload_whitelists_on_pattern", unique: true
    t.index ["updater_id"], name: "index_upload_whitelists_on_updater_id"
  end

  create_table "uploads", force: :cascade do |t|
    t.text "source"
    t.string "rating", limit: 1, null: false
    t.bigint "uploader_id", null: false
    t.inet "uploader_ip_addr", null: false
    t.text "tag_string", null: false
    t.text "backtrace"
    t.bigint "post_id"
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.bigint "parent_id"
    t.text "description", default: "", null: false
    t.string "direct_url"
    t.bigint "upload_media_asset_id"
    t.index ["source"], name: "index_uploads_on_source"
    t.index ["upload_media_asset_id"], name: "index_uploads_on_upload_media_asset_id"
    t.index ["uploader_id"], name: "index_uploads_on_uploader_id"
    t.index ["uploader_ip_addr"], name: "index_uploads_on_uploader_ip_addr"
  end

  create_table "user_approvals", force: :cascade do |t|
    t.bigint "updater_id"
    t.bigint "user_id", null: false
    t.string "status", default: "pending", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.inet "updater_ip_addr"
    t.index ["updater_id"], name: "index_user_approvals_on_updater_id"
    t.index ["user_id"], name: "index_user_approvals_on_user_id"
  end

  create_table "user_blocks", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "target_id", null: false
    t.boolean "hide_comments", default: false, null: false
    t.boolean "hide_forum_topics", default: false, null: false
    t.boolean "hide_forum_posts", default: false, null: false
    t.boolean "disable_messages", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "suppress_mentions", default: false, null: false
    t.index ["target_id", "user_id"], name: "index_user_blocks_on_target_id_and_user_id", unique: true
    t.index ["target_id"], name: "index_user_blocks_on_target_id"
    t.index ["user_id"], name: "index_user_blocks_on_user_id"
  end

  create_table "user_events", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "user_session_id", null: false
    t.integer "category", null: false
    t.inet "user_ip_addr", null: false
    t.string "session_id", null: false
    t.string "user_agent"
    t.jsonb "metadata", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["category"], name: "index_user_events_on_category"
    t.index ["session_id"], name: "index_user_events_on_session_id"
    t.index ["user_agent"], name: "index_user_events_on_user_agent"
    t.index ["user_id"], name: "index_user_events_on_user_id"
    t.index ["user_ip_addr"], name: "index_user_events_on_user_ip_addr"
    t.index ["user_session_id"], name: "index_user_events_on_user_session_id"
  end

  create_table "user_feedbacks", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "creator_id", null: false
    t.string "category", null: false
    t.text "body", null: false
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.inet "creator_ip_addr", null: false
    t.bigint "updater_id", null: false
    t.boolean "is_deleted", default: false, null: false
    t.inet "updater_ip_addr", null: false
    t.index "lower(body) gin_trgm_ops", name: "index_user_feedback_on_lower_body_trgm", using: :gin
    t.index "to_tsvector('english'::regconfig, body)", name: "index_user_feedback_on_to_tsvector_english_body", using: :gin
    t.index ["created_at"], name: "index_user_feedbacks_on_created_at"
    t.index ["creator_id"], name: "index_user_feedbacks_on_creator_id"
    t.index ["creator_ip_addr"], name: "index_user_feedbacks_on_creator_ip_addr"
    t.index ["user_id"], name: "index_user_feedbacks_on_user_id"
  end

  create_table "user_name_change_requests", force: :cascade do |t|
    t.string "status", default: "pending", null: false
    t.bigint "user_id", null: false
    t.bigint "approver_id"
    t.string "original_name", null: false
    t.string "desired_name", null: false
    t.text "change_reason", default: "", null: false
    t.text "rejection_reason"
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.bigint "creator_id", null: false
    t.inet "creator_ip_addr", null: false
    t.index ["creator_id"], name: "index_user_name_change_requests_on_creator_id"
    t.index ["original_name"], name: "index_user_name_change_requests_on_original_name"
    t.index ["user_id"], name: "index_user_name_change_requests_on_user_id"
  end

  create_table "user_password_reset_nonces", force: :cascade do |t|
    t.string "key", null: false
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.bigint "user_id", null: false
  end

  create_table "user_sessions", force: :cascade do |t|
    t.inet "ip_addr", null: false
    t.string "session_id", null: false
    t.string "user_agent"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["ip_addr"], name: "index_user_sessions_on_ip_addr"
    t.index ["session_id"], name: "index_user_sessions_on_session_id"
  end

  create_table "user_text_versions", force: :cascade do |t|
    t.bigint "updater_id", null: false
    t.inet "updater_ip_addr", null: false
    t.bigint "user_id", null: false
    t.string "about_text", null: false
    t.string "artinfo_text", null: false
    t.string "blacklist_text", null: false
    t.integer "version", default: 1, null: false
    t.string "text_changes", default: [], null: false, array: true
    t.datetime "created_at", null: false
    t.index ["updater_id"], name: "index_user_text_versions_on_updater_id"
    t.index ["user_id"], name: "index_user_text_versions_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil
    t.string "name", null: false
    t.string "password_hash", null: false
    t.string "email"
    t.integer "level", default: 10, null: false
    t.integer "base_upload_limit", default: 10, null: false
    t.datetime "last_logged_in_at", precision: nil
    t.datetime "last_forum_read_at", precision: nil
    t.text "recent_tags"
    t.integer "comment_threshold", default: -2, null: false
    t.string "default_image_size", default: "large", null: false
    t.text "favorite_tags"
    t.text "blacklisted_tags", default: ""
    t.string "time_zone", default: "Central Time (US & Canada)", null: false
    t.text "bcrypt_password_hash"
    t.integer "per_page", default: 100, null: false
    t.text "custom_style", default: "", null: false
    t.bigint "bit_prefs", default: 0, null: false
    t.inet "last_ip_addr"
    t.integer "unread_dmail_count", default: 0, null: false
    t.text "profile_about", default: "", null: false
    t.text "profile_artinfo", default: "", null: false
    t.bigint "avatar_id"
    t.integer "post_count", default: 0, null: false
    t.integer "post_deleted_count", default: 0, null: false
    t.integer "post_update_count", default: 0, null: false
    t.integer "post_flag_count", default: 0, null: false
    t.integer "favorite_count", default: 0, null: false
    t.integer "wiki_update_count", default: 0, null: false
    t.integer "note_update_count", default: 0, null: false
    t.integer "forum_post_count", default: 0, null: false
    t.integer "comment_count", default: 0, null: false
    t.integer "pool_update_count", default: 0, null: false
    t.integer "set_count", default: 0, null: false
    t.integer "artist_update_count", default: 0, null: false
    t.integer "own_post_replaced_count", default: 0, null: false
    t.integer "own_post_replaced_penalize_count", default: 0, null: false
    t.integer "post_replacement_rejected_count", default: 0, null: false
    t.integer "ticket_count", default: 0, null: false
    t.string "title"
    t.integer "unread_notification_count", default: 0, null: false
    t.integer "followed_tag_count", default: 0, null: false
    t.string "mfa_secret"
    t.datetime "mfa_last_used_at"
    t.string "backup_codes", array: true
    t.integer "post_appealed_count", default: 0
    t.string "upload_notifications", default: [], null: false, array: true
    t.integer "post_vote_count", default: 0, null: false
    t.integer "comment_vote_count", default: 0, null: false
    t.integer "forum_post_vote_count", default: 0, null: false
    t.index "lower((email)::text)", name: "index_user_lower_email"
    t.index "lower((name)::text)", name: "index_users_on_name", unique: true
    t.index "lower(profile_about) gin_trgm_ops", name: "index_users_on_lower_profile_about_trgm", using: :gin
    t.index "lower(profile_artinfo) gin_trgm_ops", name: "index_users_on_lower_profile_artinfo_trgm", using: :gin
    t.index "to_tsvector('english'::regconfig, profile_about)", name: "index_users_on_to_tsvector_english_profile_about", using: :gin
    t.index "to_tsvector('english'::regconfig, profile_artinfo)", name: "index_users_on_to_tsvector_english_profile_artinfo", using: :gin
    t.index ["email"], name: "index_users_on_email"
    t.index ["id"], name: "index_users_on_bit_prefs_can_approve_posts_false", where: "((bit_prefs & (256)::bigint) = 0)"
    t.index ["id"], name: "index_users_on_bit_prefs_can_approve_posts_true", where: "((bit_prefs & (256)::bigint) = 256)"
    t.index ["id"], name: "index_users_on_bit_prefs_can_manage_aibur_false", where: "((bit_prefs & (4194304)::bigint) = 0)"
    t.index ["id"], name: "index_users_on_bit_prefs_can_manage_aibur_true", where: "((bit_prefs & (4194304)::bigint) = 4194304)"
    t.index ["id"], name: "index_users_on_bit_prefs_enable_privacy_mode_false", where: "((bit_prefs & (32)::bigint) = 0)"
    t.index ["id"], name: "index_users_on_bit_prefs_enable_privacy_mode_true", where: "((bit_prefs & (32)::bigint) = 32)"
    t.index ["id"], name: "index_users_on_bit_prefs_unrestricted_uploads_false", where: "((bit_prefs & (512)::bigint) = 0)"
    t.index ["id"], name: "index_users_on_bit_prefs_unrestricted_uploads_true", where: "((bit_prefs & (512)::bigint) = 512)"
    t.index ["last_ip_addr"], name: "index_users_on_last_ip_addr", where: "(last_ip_addr IS NOT NULL)"
  end

  create_table "wiki_page_versions", force: :cascade do |t|
    t.bigint "wiki_page_id", null: false
    t.bigint "updater_id", null: false
    t.inet "updater_ip_addr", null: false
    t.string "title", null: false
    t.text "body", null: false
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.string "reason"
    t.string "parent"
    t.integer "protection_level"
    t.bigint "merged_from_id"
    t.string "merged_from_title"
    t.index ["created_at"], name: "index_wiki_page_versions_on_created_at"
    t.index ["merged_from_id"], name: "index_wiki_page_versions_on_merged_from_id"
    t.index ["updater_ip_addr"], name: "index_wiki_page_versions_on_updater_ip_addr"
    t.index ["wiki_page_id"], name: "index_wiki_page_versions_on_wiki_page_id"
  end

  create_table "wiki_pages", force: :cascade do |t|
    t.bigint "creator_id", null: false
    t.string "title", null: false
    t.text "body", null: false
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.bigint "updater_id", null: false
    t.string "parent"
    t.integer "protection_level"
    t.inet "creator_ip_addr", null: false
    t.inet "updater_ip_addr", null: false
    t.index "lower((title)::text) gin_trgm_ops", name: "index_wiki_pages_on_lower_title_trgm", using: :gin
    t.index "lower(body) gin_trgm_ops", name: "index_wiki_pages_on_lower_body_trgm", using: :gin
    t.index "to_tsvector('english'::regconfig, body)", name: "index_wiki_pages_on_to_tsvector_english_body", using: :gin
    t.index ["title"], name: "index_wiki_pages_on_title", unique: true
    t.index ["title"], name: "index_wiki_pages_on_title_pattern", opclass: :text_pattern_ops
    t.index ["updated_at"], name: "index_wiki_pages_on_updated_at"
  end

  add_foreign_key "api_keys", "users"
  add_foreign_key "artist_urls", "artists"
  add_foreign_key "artist_versions", "artists"
  add_foreign_key "artist_versions", "users", column: "linked_user_id"
  add_foreign_key "artist_versions", "users", column: "updater_id"
  add_foreign_key "artists", "users", column: "creator_id"
  add_foreign_key "artists", "users", column: "linked_user_id"
  add_foreign_key "avoid_posting_versions", "avoid_postings"
  add_foreign_key "avoid_posting_versions", "users", column: "updater_id"
  add_foreign_key "avoid_postings", "artists"
  add_foreign_key "avoid_postings", "users", column: "creator_id"
  add_foreign_key "avoid_postings", "users", column: "updater_id"
  add_foreign_key "bans", "users"
  add_foreign_key "bans", "users", column: "banner_id"
  add_foreign_key "bulk_update_request_versions", "bulk_update_requests"
  add_foreign_key "bulk_update_request_versions", "users", column: "updater_id"
  add_foreign_key "bulk_update_requests", "forum_posts", on_delete: :nullify
  add_foreign_key "bulk_update_requests", "forum_topics", on_delete: :nullify
  add_foreign_key "bulk_update_requests", "users", column: "approver_id"
  add_foreign_key "bulk_update_requests", "users", column: "creator_id"
  add_foreign_key "bulk_update_requests", "users", column: "updater_id"
  add_foreign_key "comment_votes", "comments"
  add_foreign_key "comment_votes", "users"
  add_foreign_key "comments", "posts"
  add_foreign_key "comments", "users", column: "creator_id"
  add_foreign_key "comments", "users", column: "updater_id"
  add_foreign_key "comments", "users", column: "warning_user_id"
  add_foreign_key "destroyed_posts", "users", column: "destroyer_id"
  add_foreign_key "destroyed_posts", "users", column: "uploader_id"
  add_foreign_key "dmail_filters", "users"
  add_foreign_key "dmails", "users", column: "from_id"
  add_foreign_key "dmails", "users", column: "owner_id"
  add_foreign_key "dmails", "users", column: "respond_to_id"
  add_foreign_key "dmails", "users", column: "to_id"
  add_foreign_key "edit_histories", "users", column: "updater_id"
  add_foreign_key "email_blacklists", "users", column: "creator_id"
  add_foreign_key "exception_logs", "users"
  add_foreign_key "favorites", "posts"
  add_foreign_key "favorites", "users"
  add_foreign_key "forum_categories", "users", column: "creator_id"
  add_foreign_key "forum_categories", "users", column: "updater_id"
  add_foreign_key "forum_category_visits", "forum_categories"
  add_foreign_key "forum_category_visits", "users"
  add_foreign_key "forum_post_votes", "forum_posts"
  add_foreign_key "forum_post_votes", "users"
  add_foreign_key "forum_posts", "forum_topics", column: "topic_id"
  add_foreign_key "forum_posts", "users", column: "creator_id"
  add_foreign_key "forum_posts", "users", column: "updater_id"
  add_foreign_key "forum_posts", "users", column: "warning_user_id"
  add_foreign_key "forum_topic_statuses", "forum_topics"
  add_foreign_key "forum_topic_statuses", "users"
  add_foreign_key "forum_topics", "forum_categories", column: "category_id"
  add_foreign_key "forum_topics", "users", column: "creator_id"
  add_foreign_key "forum_topics", "users", column: "updater_id"
  add_foreign_key "help_pages", "users", column: "creator_id"
  add_foreign_key "help_pages", "users", column: "updater_id"
  add_foreign_key "help_pages", "wiki_pages"
  add_foreign_key "ip_bans", "users", column: "creator_id"
  add_foreign_key "mascot_media_assets", "media_metadata", column: "media_metadata_id"
  add_foreign_key "mascot_media_assets", "users", column: "creator_id"
  add_foreign_key "mascots", "mascot_media_assets"
  add_foreign_key "mascots", "users", column: "creator_id"
  add_foreign_key "mascots", "users", column: "updater_id"
  add_foreign_key "mod_actions", "users", column: "creator_id"
  add_foreign_key "news_updates", "users", column: "creator_id"
  add_foreign_key "news_updates", "users", column: "updater_id"
  add_foreign_key "note_versions", "notes"
  add_foreign_key "note_versions", "posts"
  add_foreign_key "note_versions", "users", column: "updater_id"
  add_foreign_key "notes", "posts"
  add_foreign_key "notes", "users", column: "creator_id"
  add_foreign_key "notifications", "users"
  add_foreign_key "pool_versions", "pools"
  add_foreign_key "pool_versions", "users", column: "updater_id"
  add_foreign_key "pools", "posts", column: "cover_post_id"
  add_foreign_key "pools", "users", column: "creator_id"
  add_foreign_key "post_appeals", "posts"
  add_foreign_key "post_appeals", "users", column: "creator_id"
  add_foreign_key "post_appeals", "users", column: "updater_id"
  add_foreign_key "post_approvals", "posts"
  add_foreign_key "post_approvals", "users"
  add_foreign_key "post_deletion_reasons", "users", column: "creator_id"
  add_foreign_key "post_deletion_reasons", "users", column: "updater_id"
  add_foreign_key "post_disapprovals", "posts"
  add_foreign_key "post_disapprovals", "users"
  add_foreign_key "post_events", "users", column: "creator_id"
  add_foreign_key "post_flags", "posts"
  add_foreign_key "post_flags", "users", column: "creator_id"
  add_foreign_key "post_replacement_media_assets", "media_metadata", column: "media_metadata_id"
  add_foreign_key "post_replacement_media_assets", "users", column: "creator_id"
  add_foreign_key "post_replacement_rejection_reasons", "users", column: "creator_id"
  add_foreign_key "post_replacement_rejection_reasons", "users", column: "updater_id"
  add_foreign_key "post_replacements", "post_replacement_media_assets"
  add_foreign_key "post_replacements", "posts"
  add_foreign_key "post_replacements", "users", column: "approver_id"
  add_foreign_key "post_replacements", "users", column: "creator_id"
  add_foreign_key "post_replacements", "users", column: "rejector_id"
  add_foreign_key "post_replacements", "users", column: "uploader_id_on_approve"
  add_foreign_key "post_set_maintainers", "post_sets"
  add_foreign_key "post_set_maintainers", "users"
  add_foreign_key "post_sets", "users", column: "creator_id"
  add_foreign_key "post_sets", "users", column: "updater_id"
  add_foreign_key "post_versions", "posts"
  add_foreign_key "post_versions", "users", column: "updater_id"
  add_foreign_key "post_votes", "posts"
  add_foreign_key "post_votes", "users"
  add_foreign_key "posts", "upload_media_assets"
  add_foreign_key "posts", "users", column: "approver_id"
  add_foreign_key "posts", "users", column: "updater_id"
  add_foreign_key "posts", "users", column: "uploader_id"
  add_foreign_key "quick_rules", "rules"
  add_foreign_key "quick_rules", "users", column: "creator_id"
  add_foreign_key "quick_rules", "users", column: "updater_id"
  add_foreign_key "rule_categories", "users", column: "creator_id"
  add_foreign_key "rule_categories", "users", column: "updater_id"
  add_foreign_key "rules", "rule_categories", column: "category_id"
  add_foreign_key "rules", "users", column: "creator_id"
  add_foreign_key "rules", "users", column: "updater_id"
  add_foreign_key "staff_audit_logs", "users"
  add_foreign_key "staff_notes", "users"
  add_foreign_key "staff_notes", "users", column: "creator_id"
  add_foreign_key "staff_notes", "users", column: "updater_id"
  add_foreign_key "tag_aliases", "forum_posts", on_delete: :nullify
  add_foreign_key "tag_aliases", "forum_topics", on_delete: :nullify
  add_foreign_key "tag_aliases", "users", column: "approver_id"
  add_foreign_key "tag_aliases", "users", column: "creator_id"
  add_foreign_key "tag_aliases", "users", column: "updater_id"
  add_foreign_key "tag_followers", "posts", column: "last_post_id"
  add_foreign_key "tag_followers", "tags"
  add_foreign_key "tag_followers", "users"
  add_foreign_key "tag_implications", "forum_posts", on_delete: :nullify
  add_foreign_key "tag_implications", "forum_topics", on_delete: :nullify
  add_foreign_key "tag_implications", "users", column: "approver_id"
  add_foreign_key "tag_implications", "users", column: "creator_id"
  add_foreign_key "tag_implications", "users", column: "updater_id"
  add_foreign_key "tag_versions", "tags"
  add_foreign_key "tag_versions", "users", column: "updater_id"
  add_foreign_key "tags", "users", column: "creator_id"
  add_foreign_key "takedowns", "users", column: "approver_id"
  add_foreign_key "takedowns", "users", column: "creator_id"
  add_foreign_key "takedowns", "users", column: "updater_id"
  add_foreign_key "tickets", "users", column: "accused_id"
  add_foreign_key "tickets", "users", column: "creator_id"
  add_foreign_key "tickets", "users", column: "handler_id"
  add_foreign_key "upload_media_assets", "media_metadata", column: "media_metadata_id"
  add_foreign_key "upload_media_assets", "users", column: "creator_id"
  add_foreign_key "upload_whitelists", "users", column: "creator_id"
  add_foreign_key "upload_whitelists", "users", column: "updater_id"
  add_foreign_key "uploads", "posts"
  add_foreign_key "uploads", "upload_media_assets"
  add_foreign_key "uploads", "users", column: "uploader_id"
  add_foreign_key "user_approvals", "users"
  add_foreign_key "user_approvals", "users", column: "updater_id"
  add_foreign_key "user_blocks", "users"
  add_foreign_key "user_blocks", "users", column: "target_id"
  add_foreign_key "user_events", "user_sessions"
  add_foreign_key "user_events", "users"
  add_foreign_key "user_feedbacks", "users"
  add_foreign_key "user_feedbacks", "users", column: "creator_id"
  add_foreign_key "user_feedbacks", "users", column: "updater_id"
  add_foreign_key "user_name_change_requests", "users"
  add_foreign_key "user_name_change_requests", "users", column: "approver_id"
  add_foreign_key "user_name_change_requests", "users", column: "creator_id"
  add_foreign_key "user_password_reset_nonces", "users"
  add_foreign_key "user_text_versions", "users"
  add_foreign_key "user_text_versions", "users", column: "updater_id"
  add_foreign_key "users", "posts", column: "avatar_id"
  add_foreign_key "wiki_page_versions", "users", column: "updater_id"
  add_foreign_key "wiki_page_versions", "wiki_pages"
  add_foreign_key "wiki_pages", "users", column: "creator_id"
  add_foreign_key "wiki_pages", "users", column: "updater_id"
end

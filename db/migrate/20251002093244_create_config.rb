# frozen_string_literal: true

class CreateConfig < ActiveRecord::Migration[7.1]
  def change
    create_table(:config, id: false) do |t|
      t.column(:id, :text, default: "config", null: false, primary_key: true)
      t.column(:contributor_suffixes, :text, default: "va, modeler", null: false)
      t.column(:comment_bump_threshold, :integer, default: 40, null: false)
      t.column(:pending_uploads_limit, :integer, default: 3, null: false)
      t.column(:comment_limit, :integer, default: 15, null: false)
      t.column(:comment_limit_bypass, :integer, default: User::Levels::TRUSTED, null: false)
      t.column(:comment_vote_limit, :integer, default: 25, null: false)
      t.column(:comment_vote_limit_bypass, :integer, default: User::Levels::TRUSTED, null: false)
      t.column(:post_vote_limit, :integer, default: 1_000, null: false)
      t.column(:post_vote_limit_bypass, :integer, default: User::Levels::TRUSTED, null: false)
      t.column(:dmail_minute_limit, :integer, default: 2, null: false)
      t.column(:dmail_minute_limit_bypass, :integer, default: User::Levels::JANITOR, null: false)
      t.column(:dmail_hour_limit, :integer, default: 30, null: false)
      t.column(:dmail_hour_limit_bypass, :integer, default: User::Levels::JANITOR, null: false)
      t.column(:dmail_day_limit, :integer, default: 60, null: false)
      t.column(:dmail_day_limit_bypass, :integer, default: User::Levels::JANITOR, null: false)
      t.column(:dmail_restricted_day_limit, :integer, default: 5, null: false)
      t.column(:tag_suggestion_limit, :integer, default: 15, null: false)
      t.column(:tag_suggestion_limit_bypass, :integer, default: User::Levels::TRUSTED, null: false)
      t.column(:forum_vote_limit, :integer, default: 25, null: false)
      t.column(:forum_vote_limit_bypass, :integer, default: User::Levels::TRUSTED, null: false)
      t.column(:artist_edit_limit, :integer, default: 25, null: false)
      t.column(:artist_edit_limit_bypass, :integer, default: User::Levels::TRUSTED, null: false)
      t.column(:wiki_edit_limit, :integer, default: 60, null: false)
      t.column(:wiki_edit_limit_bypass, :integer, default: User::Levels::TRUSTED, null: false)
      t.column(:note_edit_limit, :integer, default: 50, null: false)
      t.column(:note_edit_limit_bypass, :integer, default: User::Levels::TRUSTED, null: false)
      t.column(:pool_limit, :integer, default: 2, null: false)
      t.column(:pool_limit_bypass, :integer, default: User::Levels::TRUSTED, null: false)
      t.column(:pool_edit_limit, :integer, default: 10, null: false)
      t.column(:pool_edit_limit_bypass, :integer, default: User::Levels::TRUSTED, null: false)
      t.column(:pool_post_edit_limit, :integer, default: 30, null: false)
      t.column(:pool_post_edit_limit_bypass, :integer, default: User::Levels::TRUSTED, null: false)
      t.column(:post_edit_limit, :integer, default: 150, null: false)
      t.column(:post_edit_limit_bypass, :integer, default: User::Levels::TRUSTED, null: false)
      t.column(:post_appeal_limit, :integer, default: 5, null: false)
      t.column(:post_appeal_limit_bypass, :integer, default: User::Levels::TRUSTED, null: false)
      t.column(:post_flag_limit, :integer, default: 20, null: false)
      t.column(:post_flag_limit_bypass, :integer, default: User::Levels::TRUSTED, null: false)
      t.column(:hourly_upload_limit, :integer, default: 30, null: false)
      t.column(:ticket_limit, :integer, default: 30, null: false)
      t.column(:ticket_limit_bypass, :integer, default: User::Levels::TRUSTED, null: false)
      t.column(:pool_category_change_limit, :integer, default: 30, null: false)
      t.column(:post_replacement_per_day_limit, :integer, default: 2, null: false)
      t.column(:post_replacement_per_day_limit_bypass, :integer, default: User::Levels::JANITOR, null: false)
      t.column(:post_replacement_per_post_limit, :integer, default: 5, null: false)
      t.column(:post_replacement_per_post_limit_bypass, :integer, default: User::Levels::JANITOR, null: false)
      t.column(:compact_uploader_minimum_posts, :integer, default: 10, null: false)
      t.column(:tag_query_limit, :integer, default: 40, null: false)
      t.column(:bur_entry_limit, :jsonb, default: {
        User::Levels::MEMBER => 50,
        User::Levels::ADMIN  => -1,
      }, null: false)
      t.column(:max_numbered_pages, :integer, default: 1_000, null: false)
      t.column(:max_per_page, :integer, default: 500, null: false)
      t.column(:comment_max_size, :integer, default: 10_000, null: false)
      t.column(:dmail_max_size, :integer, default: 50_000, null: false)
      t.column(:forum_post_max_size, :integer, default: 50_000, null: false)
      t.column(:forum_category_description_max_size, :integer, default: 250, null: false)
      t.column(:note_max_size, :integer, default: 1_000, null: false)
      t.column(:pool_description_max_size, :integer, default: 10_000, null: false)
      t.column(:post_description_max_size, :integer, default: 50_000, null: false)
      t.column(:ticket_max_size, :integer, default: 5_000, null: false)
      t.column(:user_about_max_size, :integer, default: 50_000, null: false)
      t.column(:blacklisted_tags_max_size, :integer, default: 150_000, null: false)
      t.column(:custom_style_max_size, :integer, default: 500_000, null: false)
      t.column(:wiki_page_max_size, :integer, default: 250_000, null: false)
      t.column(:user_feedback_max_size, :integer, default: 20_000, null: false)
      t.column(:news_update_max_size, :integer, default: 50_000, null: false)
      t.column(:pool_post_limit, :integer, default: 1_000, null: false)
      t.column(:pool_post_limit_bypass, :integer, default: User::Levels::ADMIN, null: false)
      t.column(:set_post_limit, :integer, default: 10_000, null: false)
      t.column(:set_post_limit_bypass, :integer, default: User::Levels::ADMIN, null: false)
      t.column(:disapproval_message_max_size, :integer, default: 250, null: false)
      t.column(:max_upload_per_request, :integer, default: 75, null: false)
      t.column(:max_file_size, :integer, default: 200, null: false)
      t.column(:max_file_sizes, :jsonb, default: {
        jpg:  100,
        png:  100,
        webp: 100,
        gif:  30,
        apng: 30,
        webm: 200,
        mp4:  200,
      }, null: false)
      t.column(:max_mascot_file_sizes, :jsonb, default: {
        jpg:  1000,
        png:  1000,
        webp: 1000,
      }, null: false)
      t.column(:max_mascot_width, :integer, default: 1000, null: false)
      t.column(:max_mascot_height, :integer, default: 1000, null: false)
      t.column(:max_video_duration, :integer, default: 1800, null: false)
      t.column(:max_image_resolution, :integer, default: 441, null: false)
      t.column(:max_image_width, :integer, default: 40_000, null: false)
      t.column(:max_image_height, :integer, default: 40_000, null: false)
      t.column(:max_tags_per_post, :integer, default: 2_000, null: false)
      t.column(:enable_signups, :boolean, default: true, null: false)
      t.column(:user_approvals_enabled, :boolean, default: true, null: false)
      t.column(:enable_email_verification, :boolean, default: Rails.env.production?, null: false)
      t.column(:enable_stale_forum_topics, :boolean, default: true, null: false)
      t.column(:enable_sock_puppet_validation, :boolean, default: Rails.env.production?, null: false)
      t.column(:forum_topic_stale_window, :integer, default: 180, null: false)
      t.column(:forum_topic_aibur_stale_window, :integer, default: 365, null: false)
      t.column(:flag_notice_wiki_page, :string, default: "internal:flag_notice", null: false)
      t.column(:replacement_notice_wiki_page, :string, default: "internal:replacement_notice", null: false)
      t.column(:avoid_posting_notice_wiki_page, :string, default: "internal:avoid_posting_notice", null: false)
      t.column(:discord_notice_wiki_page, :string, default: "internal:discord_notice", null: false)
      t.column(:rules_body_wiki_page, :string, default: "internal:rules_body", null: false)
      t.column(:restricted_notice_wiki_page, :string, default: "internal:restricted_notice", null: false)
      t.column(:rejected_notice_wiki_page, :string, default: "internal:rejected_notice", null: false)
      t.column(:appeal_notice_wiki_page, :string, default: "internal:appeal_notice", null: false)
      t.column(:ban_notice_wiki_page, :string, default: "internal:ban_notice", null: false)
      t.column(:user_approved_wiki_page, :string, default: "internal:user_approved", null: false)
      t.column(:user_rejected_wiki_page, :string, default: "internal:user_rejected", null: false)
      t.column(:records_per_page, :integer, default: 100, null: false)
      t.column(:tag_change_request_update_limit, :jsonb, default: {
        User::Levels::TRUSTED   => 500,
        User::Levels::JANITOR   => 1_000,
        User::Levels::MODERATOR => 10_000,
        User::Levels::ADMIN     => 100_000,
        User::Levels::OWNER     => -1,
      }, null: false)
      t.column(:followed_tag_limit, :jsonb, default: {
        User::Levels::MEMBER  => 100,
        User::Levels::TRUSTED => 500,
        User::Levels::JANITOR => 1_000,
      }, null: false)
      t.column(:tag_type_edit_limit, :jsonb, default: {
        User::Levels::MEMBER  => 100,
        User::Levels::TRUSTED => 1_000,
        User::Levels::JANITOR => 10_000,
        User::Levels::ADMIN   => -1,
      }, null: false)
      t.column(:tag_type_edit_implicit_limit, :jsonb, default: {
        User::Levels::MEMBER  => 100,
        User::Levels::TRUSTED => 1_000,
      }, null: false)
      t.column(:alias_category_change_cutoff, :integer, default: 10_000, null: false)
      t.column(:max_multi_count, :integer, default: 100, null: false)
      t.column(:takedown_email, :string, default: "admin@femboy.fan", null: false)
      t.column(:contact_email, :string, default: "admin@femboy.fan", null: false)
      t.column(:default_user_timezone, :string, default: "Central Time (US & Canada)")
      t.column(:alias_and_implication_forum_category, :integer, default: 1, null: false)
      t.column(:default_forum_category, :integer, default: 1, null: false)
      t.column(:upload_whitelists_forum_topic, :integer, default: 0, null: false)
      # When calculating statistics based on the posts table, gather this many posts to sample from.
      t.column(:post_sample_size, :integer, default: 300, null: false)
      t.column(:updated_at, :datetime)
    end
    AdminConfig.delete_cache
  end
end

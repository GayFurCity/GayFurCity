# frozen_string_literal: true

class AdminConfig
  module Fields
    mattr_accessor(:fields, default: [])
    mattr_accessor(:categories, default: [])

    module Structs
      module Common
        def usable?(user)
          AdminConfig.usable?(user, attribute)
        end
      end
    end

    module Methods
      def add_field(type, attribute, category: nil, name: attribute.to_s.titleize, hint: nil, disabled: false, input_options: {}, **extra)
        fields << create_struct(attribute, *extra.keys).new(type, category, attribute, name, AdminConfig.has_bypass?(attribute), hint, disabled, input_options, *extra.values)
      end

      def add_number_field(...)
        add_field(:number, ...)
      end

      def add_boolean_field(...)
        add_field(:boolean, ...)
      end

      def add_text_field(*, large: false, **)
        add_field(:text, *, large?: large, **)
      end

      def create_struct(name, *attrs)
        name = name.to_s.camelcase.to_sym
        return AdminConfig::Fields::Structs.const_get(name) if AdminConfig::Fields::Structs.const_defined?(name)
        AdminConfig::Fields::Structs.const_set(name, Struct.new(:type, :category, :attribute, :name, :bypass?, :hint, :disabled?, :input_options, *attrs.map(&:to_sym)).include(AdminConfig::Fields::Structs::Common))
      end

      def add_select_field(attribute, options, category: nil, name: attribute.to_s.titleize, hint: nil, disabled: false, input_options: {}, **extra)
        fields << create_struct(attribute, :options, *extra.keys).new(:select, category, attribute, name, AdminConfig.has_bypass?(attribute), hint, disabled, input_options, options, *extra.values)
      end

      def add_user_field(attribute, category: nil, name: attribute.to_s.titleize, hint: nil, disabled: false, input_options: {}, minimum: User::Levels::MEMBER, maximum: User::Levels::OWNER, **extra)
        fields << create_struct(attribute, :minimum, :maximum, *extra.keys).new(:user, category, attribute, name, AdminConfig.has_bypass?(attribute), hint, disabled, input_options, minimum, maximum, *extra.values)
      end

      def add_object_field(attribute, keys, category: nil, name: attribute.to_s.titleize, hint: nil, disabled: false, input_options: {}, **extra)
        fields << create_struct(attribute, :keys, *extra.keys).new(:object, category, attribute, name, AdminConfig.has_bypass?(attribute), hint, disabled, input_options, keys, *extra.values)
      end

      def add_per_level_field(attribute, category: nil, name: attribute.to_s.titleize, hint: nil, disabled: false, input_options: {}, minimum: User::Levels::MEMBER, maximum: User::Levels::OWNER, **extra)
        fields << create_struct(attribute, :minimum, :maximum, *extra.keys).new(:per_level, category, attribute, name, AdminConfig.has_bypass?(attribute), hint, disabled, input_options, minimum, maximum, *extra.values)
      end

      def category(name, &block)
        categories << name

        return if block.nil?
        mod = Module.new do
          module_function

          def add_field(*, **)
            AdminConfig::Fields.add_field(*, category: category, **)
          end

          def add_number_field(*, **)
            AdminConfig::Fields.add_number_field(*, category: category, **)
          end

          def add_boolean_field(*, **)
            AdminConfig::Fields.add_boolean_field(*, category: category, **)
          end

          def add_text_field(*, **)
            AdminConfig::Fields.add_text_field(*, category: category, **)
          end

          def add_select_field(*, **)
            AdminConfig::Fields.add_select_field(*, category: category, **)
          end

          def add_user_field(*, **)
            AdminConfig::Fields.add_user_field(*, category: category, **)
          end

          def add_object_field(*, **)
            AdminConfig::Fields.add_object_field(*, category: category, **)
          end

          def add_per_level_field(*, **)
            AdminConfig::Fields.add_per_level_field(*, category: category, **)
          end
        end
        mod.module_eval do
          define_singleton_method(:category) { name }
        end
        mod.module_eval(&block)
      end
    end
    extend(Methods)

    category("Action Limits") do
      add_number_field(:comment_limit, name: "Hourly Comment Limit")
      add_number_field(:comment_vote_limit, name: "Hourly Comment Vote Limit")
      add_number_field(:post_vote_limit, name: "Hourly Post Vote Limit")
      add_number_field(:forum_vote_limit, name: "Hourly Forum Vote Limit")
      add_number_field(:post_set_create_limit, name: "Hourly Post Set Creation Limit")
      add_number_field(:dmail_minute_limit, name: "Per-Minute DMail Limit")
      add_number_field(:dmail_hour_limit, name: "Hourly DMail Limit")
      add_number_field(:dmail_day_limit, name: "Daily DMail Limit")
      add_number_field(:dmail_restricted_day_limit, name: "Restricted Daily DMail Limit Limit")
      add_number_field(:tag_suggestion_limit, name: "Hourly Alias/Implication Suggestion Limit")
      add_number_field(:artist_edit_limit, name: "Hourly Artist Edit Limit")
      add_number_field(:character_edit_limit, name: "Hourly Character Edit Limit")
      add_number_field(:wiki_edit_limit, name: "Hourly Wiki Edit Limit")
      add_number_field(:note_edit_limit, name: "Hourly Note Edit Limit")
      add_number_field(:post_edit_limit, name: "Hourly Post Edit Limit")
      add_number_field(:pool_limit, name: "Hourly Pool Creation Limit")
      add_number_field(:pool_edit_limit, name: "Hourly Pool Edit Limit")
      add_number_field(:pool_post_edit_limit, name: "Hourly PoolPost Edit  Limit")
      add_number_field(:post_appeal_limit, name: "Hourly Post Appeal Limit")
      add_number_field(:post_flag_limit, name: "Hourly Post Flag Limit")
      add_number_field(:hourly_upload_limit)
      add_number_field(:ticket_limit, name: "Hourly Ticket Limit")
      add_number_field(:post_replacement_per_day_limit)
      add_number_field(:post_replacement_per_post_limit)
      add_per_level_field(:tag_query_limit, hint: "Max tags allowed in a single search, per user level. -1 for unlimited", minimum: User::Levels::ANONYMOUS)
      add_number_field(:anonymous_hard_tag_limit, hint: "Hard ceiling on whitespace-separated tokens in an anonymous search, checked before any query parsing - protects against expensive parsing of huge queries regardless of tag_query_limit's anonymous tier")
      add_number_field(:pending_uploads_limit)
      add_number_field(:pool_post_limit)
      add_number_field(:set_post_limit)
      add_per_level_field(:post_set_limit, hint: "-1 for unlimited", minimum: User::Levels::REJECTED)
      add_number_field(:pool_category_change_cutoff)
      add_user_field(:show_tag_scripting)
      add_user_field(:show_backtrace, hint: "Show application related backtraces, excluding internals. In some cases this could possibly leak internal secrets/ip addresses in error messages.")
      add_user_field(:bur_nuke, name: "BUR Nuke")
      add_per_level_field(:bur_entry_limit, name: "BUR Entry Limit", hint: "-1 for unlimited")
      add_per_level_field(:tag_change_request_update_limit, hint: "-1 for unlimited")
      add_per_level_field(:followed_tag_limit, hint: "-1 for unlimited")
      add_per_level_field(:tag_type_edit_limit, hint: "-1 for unlimited")
      add_per_level_field(:tag_type_edit_implicit_limit)
    end

    category("Size Limits") do
      add_number_field(:max_numbered_pages)
      add_number_field(:max_per_page)
      add_number_field(:comment_max_size)
      add_number_field(:dmail_max_size, name: "DMail Max Size")
      add_number_field(:forum_post_max_size)
      add_number_field(:forum_category_description_max_size)
      add_number_field(:note_max_size)
      add_number_field(:pool_name_max_size)
      add_number_field(:pool_description_max_size)
      add_number_field(:post_description_max_size)
      add_number_field(:ticket_max_size)
      add_number_field(:user_about_max_size)
      add_number_field(:blacklisted_tags_max_size)
      add_number_field(:custom_style_max_size)
      add_number_field(:wiki_page_max_size)
      add_number_field(:user_feedback_max_size)
      add_number_field(:news_update_max_size)
      add_number_field(:disapproval_message_max_size)
      add_number_field(:post_flag_note_max_size)
      add_object_field(:image_width, AdminConfig.values_for_hash_column("image_width"))
      add_object_field(:image_height, AdminConfig.values_for_hash_column("image_height"))
      add_number_field(:max_upload_per_request, hint: "The size in megabytes after which uploads will be split")
      add_number_field(:max_file_size, hint: "in megabytes")
      add_object_field(:max_file_sizes, AdminConfig.values_for_hash_column("max_file_sizes"), hint: "in megabytes")
      add_number_field(:max_video_duration, hint: "in seconds")
      add_number_field(:max_image_resolution, hint: "in megapixels")
      add_object_field(:mascot_width, AdminConfig.values_for_hash_column("mascot_width"))
      add_object_field(:mascot_height, AdminConfig.values_for_hash_column("mascot_height"))
      add_object_field(:max_mascot_file_sizes, AdminConfig.values_for_hash_column("max_mascot_file_sizes"), hint: "in kilobytes")
      add_number_field(:max_tags_per_post)
      add_number_field(:max_multi_count, hint: "The maximum number of items that will be accepted for string separated (e.g. comma) inputs")
    end

    category("Other") do
      add_text_field(:id, name: "Admin Config ID", disabled: true)
      add_text_field(:app_name)
      add_text_field(:canonical_app_name, hint: "Used when safe mode is enabled to direct to the primary instance")
      add_text_field(:app_description, large: true, input_options: { size: "60x2" })
      add_text_field(:system_user_name)
      add_text_field(:anonymous_user_name)
      add_number_field(:alias_category_change_cutoff)
      add_number_field(:records_per_page)
      add_boolean_field(:enable_signups)
      add_boolean_field(:user_approvals_enabled, name: "Enable User Approvals")
      add_boolean_field(:enable_email_verification)
      add_boolean_field(:enable_sock_puppet_validation)
      add_boolean_field(:enable_stale_forum_topics)
      add_boolean_field(:enable_autotagging, hint: "Enables automatic tagging of things like hi_res, large_file_size, long_playtime, etc")
      add_boolean_field(:enable_bad_sources, hint: "Automatically tags \"bad\" sources (like #{GayFurCity.config.hostname}). Has no effect if autotagging is disabled")
      add_boolean_field(:enable_image_cropping, hint: "Enables generating a cropped 1:1 version of posts. Changing the option will not delete existing crops, or automatically regenerate them on old posts")
      add_boolean_field(:safe_mode, hint: "Enables safe mode, hiding all posts that are not safe.")
      add_text_field(:safeblocked_tags, large: true, hint: "separate by a comma and space", input_options: { size: "30x1" })
      add_text_field(:takedown_email)
      add_text_field(:contact_email)
      add_select_field(:default_user_timezone, -> { time_zone_options_for_select(@config.default_user_timezone) })
      add_number_field(:forum_topic_stale_window, hint: "in days")
      add_number_field(:forum_topic_aibur_stale_window, hint: "in days")
      add_number_field(:comment_bump_threshold, hint: "posts with more comments will not be bumped")
      add_number_field(:compact_uploader_minimum_posts)
      add_text_field(:contributor_suffixes, hint: "separate by a comma and space")
      add_text_field(:lore_suffixes, hint: "separate by a comma and space")
      add_text_field(:artist_exclusion_tags, hint: "separate by a comma and space")
      add_number_field(:post_sample_size, hint: "When calculating statistics based on the posts table, gather this many posts to sample from")
      add_number_field(:pool_category_change_limit)
      add_number_field(:alias_and_implication_forum_category, hint: "The ID of the category aliases and implications will be created within")
      add_number_field(:default_forum_category, hint: "The ID of the category forum posts will default to be created within")
      add_number_field(:upload_whitelists_forum_topic, hint: "The ID of the topic used for upload whitelist requests")
      add_boolean_field(:flag_ai_posts, hint: "If posts detected as ai generated should be automatically flagged")
      add_boolean_field(:tag_ai_posts, hint: "If posts detected as ai generated should be automatically tagged")
      add_number_field(:ai_confidence_threshold, hint: "The minimum required threshold to flag/tag ai generated content")
      add_boolean_field(:db_exports_enabled, hint: "Whether the database exports page is enabled.")
      add_text_field(:default_blacklist, large: true, input_options: { size: "40x10" })
      add_text_field(:blacklisted_preview_url, hint: "Shown in place of a post's thumbnail when it's blacklisted. Not currently live-editable - only the file at this path is used (see blacklists.scss)")
      add_text_field(:deleted_preview_url, hint: "Shown in place of a post's thumbnail when it's deleted and the viewer can't see deleted posts")
      add_text_field(:download_preview_url, hint: "Shown in place of a thumbnail for a download-only file with no viewable preview")
      add_text_field(:missing_preview_url, hint: "Shown in place of a post replacement's thumbnail when it's a metadata-only backup with no real file (see PostReplacement#metadata_only?)")
      add_text_field(:placeholder_preview_url, hint: "Shown in place of a user avatar thumbnail while the real one hasn't loaded yet")
    end

    category("Timeouts") do
      add_per_level_field(:postgres_query_timeout, hint: "Max time in milliseconds a single Postgres query may run before being canceled", minimum: User::Levels::ANONYMOUS)
      add_per_level_field(:elasticsearch_query_timeout, hint: "Max time in milliseconds Elasticsearch spends executing a single search before returning whatever it has", minimum: User::Levels::ANONYMOUS)
      add_per_level_field(:elasticsearch_request_timeout, hint: "Max time in seconds to wait on an Elasticsearch response before aborting the request client-side", minimum: User::Levels::ANONYMOUS)
      add_per_level_field(:request_cycle_timeout, hint: "Max time in milliseconds a full request (queries, rendering, everything) may run before being canceled", minimum: User::Levels::ANONYMOUS)
    end

    category("Wiki Pages") do
      add_text_field(:flag_notice_wiki_page)
      add_text_field(:replacement_notice_wiki_page)
      add_text_field(:avoid_posting_notice_wiki_page)
      add_text_field(:discord_notice_wiki_page)
      add_text_field(:restricted_notice_wiki_page)
      add_text_field(:rejected_notice_wiki_page)
      add_text_field(:appeal_notice_wiki_page)
      add_text_field(:ban_notice_wiki_page)
      add_text_field(:rules_body_wiki_page)
      add_text_field(:user_approved_wiki_page)
      add_text_field(:user_rejected_wiki_page)
    end
  end
end

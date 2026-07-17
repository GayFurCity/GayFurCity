# frozen_string_literal: true

module GayFurCity
  class Config < YiffSpace::ConfigBuilder
    self.env_name = "GAYFURCITY"
    config(:version) { GitHelper.instance.origin.short_commit }

    config(:config_id) { "default" }
    config(:disabled_config_options, :array) { [] }
    config(:domain) { "localhost" }
    config(:hostname) { "http#{'s' if Rails.env.production?}://#{domain}" }
    config(:cdn_domain) { domain }
    config(:cdn_hostname) { "http#{'s' if Rails.env.production?}://#{cdn_domain}" }
    config(:discord_site) { nil }
    config(:app_url) { hostname }
    config(:canonical_app_url) { app_url }
    config(:server_name) { Socket.gethostname }
    config(:source_code_url) { "https://github.com/GayFurCity/GayFurCity" }
    config(:local_source_code_url) { source_code_url }
    config(:custom_html_header_content) { nil }
    config(:user_agent) { "#{::Config.instance.safe_app_name}/#{version} (#{source_code_url})" }
    config(:log_level) { ENV.fetch("RAILS_LOG_LEVEL", "info") }
    config(:rakismet_url) { app_url }
    config(:max_concurrency, :integer) { Concurrent.available_processor_count.to_i.clamp(1..) }

    config(:disable_throttles, :boolean) { false }
    config(:disable_age_checks, :boolean) { false }
    config(:disable_cache_store, :boolean) { false }
    config(:enable_application_logs, :boolean) { true }
    config(:enable_request_logs, :boolean) { true }
    config(:enable_performance_logs, :boolean) { true }

    config(:ffmpeg_path) { "/usr/bin/ffmpeg" }
    config(:post_path_prefix) { "posts/" }
    config(:protected_path_prefix) { "deleted/" }
    config(:replacement_path_prefix) { "replacements/" }
    config(:mascot_path_prefix) { "mascots/" }
    config(:deleted_preview_url) { "/images/delete-preview.png" }

    config(:protected_file_secret, required: true)
    config(:replacement_file_secret, required: true)
    config(:remember_key, required: true)
    config(:email_key, required: true)
    config(:discord_secret) { nil }
    config(:report_key) { nil }
    config(:rakismet_key) { nil }

    # "Login with YiffSpace" (Logto-based Discord OAuth via the yiffspace-auth gem).
    subconfig(:logto) do
      config(:client_id) { nil }
      config(:client_secret) { nil }
      config(:resource) { nil }
      # Logto Management API credentials, only needed for instant permission revocation
      # (webhook-driven) and the admin user-dedup tooling - safe to leave unset otherwise.
      config(:api_client_id) { nil }
      config(:api_client_secret) { nil }
      config(:api_resource) { nil }
      # Only needed if something calls Client#fetch_discord_user - not used by the login flow itself.
      config(:discord_bot_token) { nil }
    end

    config(:memcached_servers, :array) { [] }
    config(:recommender_server) { nil }
    config(:iqdb_server) { nil }
    config(:autocompleted_server) { nil }
    config(:elasticsearch_host, required: true)
    config(:redis_url, required: true)
    config(:clickhouse_url) { nil }
    subconfig(:reports) do
      config(:enabled, :boolean) { present?(:reports_server, :reports_server_internal) }
      config(:server) { nil }
      config(:server_internal) { reports_server }
    end

    # Ships telemetry to an OpenObserve instance via its HTTP _json ingestion API
    subconfig(:telemetry) do
      config(:enabled, :boolean) { present?(:telemetry_endpoint, :telemetry_username, :telemetry_password) }
      config(:endpoint) { nil }
      config(:organization) { "default" }
      config(:stream) { Config.safe_app_name.downcase }
      config(:username) { nil }
      config(:password) { nil }
    end

    config(:http_headers, env: false) do
      { user_agent: user_agent }
    end

    config(:faraday_options, env: false) do
      {
        request: {
          timeout:      10,
          open_timeout: 10,
        },
        headers: http_headers,
      }
    end

    # Permanently redirect all HTTP requests to HTTPS.
    #
    # https://en.wikipedia.org/wiki/HTTP_Strict_Transport_Security
    # http://api.rubyonrails.org/classes/ActionDispatch/SSL.html
    # Only used in production
    config(:ssl_options, env: false) do
      {
        redirect: { exclude: ->(request) { request.subdomain == "insecure" } },
        hsts:     {
          expires:    1.year,
          preload:    true,
          subdomains: false,
        },
      }
    end

    config(:flag_reasons, env: false) do
      [
        {
          name:                "uploading_guidelines",
          reason:              "Does not meet the \"uploading guidelines\":/help/uploading_guidelines",
          text:                "This post fails to meet the site's standards, be it for artistic worth, image quality, relevancy, or something else.\nKeep in mind that your personal preferences have no bearing on this. If you find the content of a post objectionable, simply \"blacklist\":/help/blacklisting it.",
          require_explanation: true,
        },
        {
          name:   "dnp_artist",
          reason: "The artist of this post is on the \"avoid posting list\":/static/avoid_posting",
          text:   "Certain artists have requested that their work is not to be published on this site, and were granted [[avoid_posting|Do Not Post]] status.\nSometimes, that status comes with conditions; see [[conditional_dnp]] for more information",
        },
        {
          name:   "pay_content",
          reason: "Paysite, commercial, or subscription content",
          text:   "We do not host paysite or commercial that is under 1 year old.",
        },
        {
          name:                "trace",
          reason:              "Trace of another artist's work",
          text:                "Images traced from other artists' artwork are not accepted on this site. Referencing from something is fine, but outright copying someone else's work is not.\nPlease, leave more information in the comments, or simply add the original artwork as the posts's parent if it's hosted on this site.",
          require_explanation: true,
        },
        {
          name:   "previously_deleted",
          reason: "Previously deleted",
          text:   "Posts usually get removed for a good reason, and reuploading of deleted content is not acceptable.\nPlease, leave more information in the comments, or simply add the original post as this post's parent.",
        },
        {
          name:   "real_porn",
          reason: "Real-life pornography",
          text:   "Posts featuring real-life pornography are not acceptable on this site.",
        },
        {
          name:                "corrupt",
          reason:              "File is either corrupted, broken, or otherwise does not work",
          text:                "Something about this post does not work quite right. This may be a broken video, or a corrupted image.\nEither way, in order to avoid confusion, please explain the situation in the comments.",
          require_explanation: true,
        },
        {
          name:   "inferior",
          reason: "Duplicate or inferior version of another post",
          text:   "A superior version of this post already exists on the site.\nThis may include images with better visual quality (larger, less compressed), but may also feature \"fixed\" versions, with visual mistakes accounted for by the artist.\nNote that edits and alternate versions do not fall under this category.",
          parent: true,
        },
      ]
    end

    config(:ticket_quick_response_buttons, env: false) do
      [
        { name: "Handled", text: "Handled, thank you." },
        { name: "Reviewed", text: "Reviewed, thank you." },
        { name: "NAT", text: "Reviewed, no action taken." },
        { name: "Closed", text: "Ticket closed." },
        { name: "Dismissed", text: "Ticket dismissed." },
        { name: "Old", text: "That comment is from N years ago.\nWe do not punish people for comments older than 3 months." },
        { name: "Reply", text: "I believe that you tried to reply to a comment, but reported it instead.\nPlease, be more careful in the future." },
        { name: "Already", text: "User already received a record for that message." },
        { name: "Banned", text: "This user is already banned." },
        { name: "Blacklist", text: "If you find the contents of that post objectionable, \"blacklist\":/help/blacklisting it." },
        { name: "Takedown", text: "Artists and character owners may request a takedown \"here\":/static/takedown.\nWe do not accept third party takedowns." },
      ]
    end

    config(:user_needs_login_for_post, :boolean, env: false) { |_post| false }
    config(:select_posts_visible_to_user, env: false) { |user, posts| posts.select { |x| can_user_see_post?(user, x) } }
    config(:is_unlimited_tag, :boolean, env: false) do |tag|
      !(tag =~ /\A(-?status:deleted|rating:s.*|limit:.+)\z/i).nil?
    end
    config(:bypass_upload_whitelist, :boolean, env: false) do |user|
      user.is_admin? || user.is_system?
    end
    config(:can_user_see_post, :boolean, env: false) do |user, post|
      # TODO: appealed posts should be visible, but this makes it far too easy to get the contents of deleted posts at a moments notice
      next true if user.is_staff? # || post.is_appealed?
      !post.is_deleted?
    end

    subconfig(:recaptcha) do
      config(:enabled, :boolean) { Rails.env.production? && present?(:recaptcha_site_key, :recaptcha_secret_key) }
      config(:site_key) { nil }
      config(:secret_key) { nil }
    end

    subconfig(:email) do
      config(:delivery_method, :symbol) { nil }
      config(:config, env: false) do
        case email_delivery_method
        when :smtp
          [:smtp_settings, email_smtp_config]
        when :sendmail
          [:sendmail_settings, email_sendmail_config]
          nil
        end
      end
      config(:delivery_errors, :boolean) { true }
      config(:from_addr) { "system@#{domain}" }
      subconfig(:smtp) do
        config(:address)
        config(:port, :integer)
        config(:domain)
        config(:user_name)
        config(:password)
        config(:authentication) { nil } # plain, login, cram_md5
        config(:enable_starttls, :boolean) { false }
        config(:enable_starttls_auto, :boolean) { true }
        config(:open_timeout, :integer) { 5 }
        config(:read_timeout, :integer) { 5 }
        config(:timeout) { 5 }
        config(:config, env: false) do
          %i[address port domain user_name password authentication enable_starttls enable_starttls_auto open_timeout read_timeout]
            .index_with { |n| public_send(:"email_smtp_#{n}") }
            .compact_blank
        end
      end
      subconfig(:sendmail) do
        config(:location) { "/usr/sbin/sendmail" }
        config(:arguments, :array) { %w[-i] }
        config(:config, env: false) do
          {
            location:  email_sendmail_location,
            arguments: email_sendmail_arguments,
          }
        end
      end
      config(:mailgun_api_key) { nil }
    end

    config(:large_image_width) { image.large_width }
    config(:replacement_thumbnail_width) { 300 }
    subconfig(:image) do
      # env: name(width, height, method)
      config(:variants, nil) do
        {
          "crop"    => MediaAsset::Rescale.new(width: 300, height: 300, method: :exact),
          "preview" => MediaAsset::Rescale.new(width: 300, height: nil, method: :scaled), # thumbnail, small
          "large"   => MediaAsset::Rescale.new(width: 850, height: nil, method: :scaled), # sample, width is used to determine resizing
        }
      end
      reviver(:variants) { |v| MediaAsset::Rescale.from_string(v) }
      config(:large_width) { image.variants["large"]&.width || raise(NotImplementedError, "missing large image variant") }
    end

    subconfig(:video) do
      # env: name(width, height, method)
      config(:variants, nil) do
        {
          "720p" => MediaAsset::Rescale.new(width: 1280, height: 720, method: :scaled),
          "480p" => MediaAsset::Rescale.new(width: 640, height: 480, method: :scaled),
        }
      end
      reviver(:variants) { |v| MediaAsset::Rescale.from_string(v) }
      # env: name(width, height, method)
      config(:image_variants, nil) do
        {
          "crop"    => MediaAsset::Rescale.new(width: 300, height: 300, method: :exact),
          "preview" => MediaAsset::Rescale.new(width: 300, height: nil, method: :scaled), # thumbnail, small
          "large"   => MediaAsset::Rescale.new(width: nil, height: nil, method: :scaled), # sample
        }
      end
      reviver(:image_variants) { |v| MediaAsset::Rescale.from_string(v) }

      config(:scale_options_webm, nil) do |width, height, file_path|
        [
          "-c:v",
          "libvpx-vp9",
          "-pix_fmt",
          "yuv420p",
          "-deadline",
          "good",
          "-cpu-used",
          "5", # 4+ disable a bunch of rate estimation features, but seems to save reasonable CPU time without large quality drop
          "-auto-alt-ref",
          "0",
          "-qmin",
          "20",
          "-qmax",
          "42",
          "-crf",
          "35",
          "-b:v",
          "3M",
          "-vf",
          "scale=w=#{width}:h=#{height}",
          "-threads",
          (Etc.nprocessors * 0.7).to_i.to_s,
          "-row-mt",
          "1",
          "-max_muxing_queue_size",
          "4096",
          "-slices",
          "8",
          "-c:a",
          "libopus",
          "-b:a",
          "96k",
          "-map_metadata",
          "-1",
          "-metadata",
          %(title="#{domain}_preview_quality_conversion,_visit_site_for_full_quality_download"),
          file_path,
        ]
      end
      reviver(:scale_options_webm) { |v, width, height, file_path| v.gsub("$WIDTH", width).gsub("$HEIGHT", height).gsub("$FILE_PATH", file_path) }

      config(:scale_options_mp4, nil) do |width, height, file_path|
        [
          "-c:v",
          "libx264",
          "-pix_fmt",
          "yuv420p",
          "-profile:v",
          "main",
          "-preset",
          "fast",
          "-crf",
          "27",
          "-b:v",
          "3M",
          "-vf",
          "scale=w=#{width}:h=#{height}",
          "-threads",
          (Etc.nprocessors * 0.7).to_i.to_s,
          "-max_muxing_queue_size",
          "4096",
          "-c:a",
          "aac",
          "-b:a",
          "128k",
          "-map_metadata",
          "-1",
          "-metadata",
          %(title="#{domain}_preview_quality_conversion,_visit_site_for_full_quality_download"),
          "-movflags",
          "+faststart",
          file_path,
        ]
      end
      reviver(:scale_options_mp4) { |v, width, height, file_path| v.gsub("$WIDTH", width).gsub("$HEIGHT", height).gsub("$FILE_PATH", file_path) }
    end

    config(:variant_location, env: false) do |variant, _file_ext|
      variant = variant.to_s
      next :none if variant == "original"
      next :path if %w[720p 480p crop preview large].include?(variant)
      next :file if %w[thumb].include?(variant)
      # return :file if %w[720p 480p].include?(variant)
      # return :path if %w[crop preview large].include?(variant)
      Rails.logger.warn("[variant_location]: Unknown variant #{variant}")
      :none
    end

    subconfig(:discord) do
      config(:janitor_stats_webhook_url) { nil }
      config(:moderator_stats_webhook_url) { nil }
      config(:aibur_stats_webhook_url) { nil }
      config(:webhook_url) { nil }
    end

    subconfig(:storage_manager) do
      config(:type, :symbol) { :local }
      config(:base_url) { cdn_hostname }
      config(:base_path, blank: true) { "/data" }
      config(:base_dir, blank: true) { Rails.public_path.join("data").to_s }
      config(:hierarchical, :boolean) { true }
      config(:instance, env: false) do
        case storage_manager.type
        when :local
          StorageManager::Local.new(
            base_url:     storage_manager.base_url,
            base_path:    storage_manager.base_path,
            base_dir:     storage_manager.base_dir,
            hierarchical: storage_manager.hierarchical,
          )
        when :ftp
          StorageManager::Ftp.new(
            base_url:     storage_manager.base_url,
            base_path:    storage_manager.base_path,
            base_dir:     storage_manager.base_dir,
            hierarchical: storage_manager.hierarchical,
            host:         storage_manager.ftp.hostname,
            port:         storage_manager.ftp.port,
            username:     storage_manager.ftp.username,
            password:     storage_manager.ftp.password,
          )
        when :bunny
          StorageManager::Bunny.new(
            base_url:     storage_manager.base_url,
            base_path:    storage_manager.base_path,
            base_dir:     storage_manager.base_dir,
            hierarchical: storage_manager.hierarchical,
            host:         storage_manager.ftp.hostname,
            port:         storage_manager.ftp.port,
            username:     storage_manager.ftp.username,
            password:     storage_manager.ftp.password,
            api_key:      storage_manager.bunny_api_key,
          )
        else
          StorageManager::Null.new
        end
      end

      subconfig(:ftp) do
        config(:hostname)
        config(:port, :integer)
        config(:username)
        config(:password)
      end

      config(:bunny_api_key)
    end

    subconfig(:backup_storage_manager) do
      config(:type, :symbol) { :null }
      config(:base_url) { cdn_hostname }
      config(:base_path, blank: true) { "/data" }
      config(:base_dir, blank: true) { Rails.public_path.join("data").to_s }
      config(:hierarchical, :boolean) { true }
      config(:instance, env: false) do
        case backup_storage_manager.type
        when :local
          StorageManager::Local.new(
            base_url:     backup_storage_manager.base_url,
            base_path:    backup_storage_manager.base_path,
            base_dir:     backup_storage_manager.base_dir,
            hierarchical: backup_storage_manager.hierarchical,
          )
        when :ftp
          StorageManager::Ftp.new(
            base_url:     backup_storage_manager.base_url,
            base_path:    backup_storage_manager.base_path,
            base_dir:     backup_storage_manager.base_dir,
            hierarchical: backup_storage_manager.hierarchical,
            host:         backup_storage_manager.ftp.hostname,
            port:         backup_storage_manager.ftp.port,
            username:     backup_storage_manager.ftp.username,
            password:     backup_storage_manager.ftp.password,
          )
        when :bunny
          StorageManager::Bunny.new(
            base_url:     backup_storage_manager.base_url,
            base_path:    backup_storage_manager.base_path,
            base_dir:     backup_storage_manager.base_dir,
            hierarchical: backup_storage_manager.hierarchical,
            host:         backup_storage_manager.ftp.hostname,
            port:         backup_storage_manager.ftp.port,
            username:     backup_storage_manager.ftp.username,
            password:     backup_storage_manager.ftp.password,
            api_key:      backup_storage_manager.bunny_api_key,
          )
        else
          StorageManager::Null.new
        end
      end

      subconfig(:ftp) do
        config(:hostname)
        config(:port, :integer)
        config(:username)
        config(:password)
      end

      config(:bunny_api_key)
    end

    config(:customize_new_user, env: false) do |user|
      user.blacklisted_tags           = ::Config.instance.default_blacklist
      user.comment_threshold          = -10
      user.enable_autocomplete        = true
      user.enable_keyboard_navigation = true
      user.per_page                   = ::Config.instance.records_per_page
      user.style_usernames            = true
      user.move_related_thumbnails    = true
      user.enable_hover_zoom          = true
      user.hover_zoom_shift           = true
      user.hover_zoom_sticky_shift    = true
      user.go_to_recent_forum_post    = true
      user.forum_unread_bubble        = true
      user.upload_notifications       = User.upload_notifications_options
      user.email_verified             = !::Config.instance.enable_email_verification?
      user.level                      = User::Levels::RESTRICTED if ::Config.instance.user_approvals_enabled? && user.level == User::Levels::MEMBER
    end
  end

  def self.config
    @config ||= Config.instance
  end
end

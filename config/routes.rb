# frozen_string_literal: true

id_name_constraint = { id: %r{[^/]+?}, format: /json|html/ }.freeze
Rails.application.routes.draw do
  mount(GoodJob::Engine, at: "/good_job", constraints: AdminRouteConstraint.new)
  mount(YiffSpace::Auth::Engine.for(:default), at: "/auth/yiffspace", as: "yiffspace_auth")

  namespace(:users) do
    get("yiffspace/callback", controller: "yiffspace", action: "callback")
  end

  namespace(:admin) do
    resources(:users, only: %i[edit update]) do
      member do
        get(:edit_blacklist)
        post(:update_blacklist)
        get(:request_password_reset)
        post(:password_reset)
      end
      collection do
        get(:alt_list)
      end
    end
    resource(:bulk_update_request_import, only: %i[new create])
    resource(:dashboard, only: %i[show])
    resources(:exceptions, only: %i[index show])
    resource(:logs, only: []) do
      get("application", action: :application_logs)
      get("application/status", action: :application_status, as: :application_status)
      get("request", action: :request_logs)
      get("request/status", action: :request_status, as: :request_status)
      get("performance", action: :performance_logs)
      get("performance/status", action: :performance_status, as: :performance_status)
    end
    resource(:reowner, controller: "reowner", only: %i[new create])
    resource(:stuck_dnp, controller: "stuck_dnp", only: %i[new create])
    resources(:destroyed_posts, only: %i[index show update])
    resources(:audit_logs, only: %i[index])
    resource(:config, only: %i[show update])
  end

  namespace(:security) do
    root(to: "dashboard#index")
    get("dashboard", to: "dashboard#index", as: :dashboard)
    resources(:lockdown, only: %i[index]) do
      collection do
        put(:panic)
        put(:enact)
        put(:uploads_min_level)
        put(:uploads_hide_pending)
      end
    end
  end

  resources(:edit_histories, only: %i[index show]) do
    get(:diff, on: :collection)
  end
  namespace(:moderator) do
    resource(:dashboard, only: [:show])
    resources(:ip_addrs, only: [:index]) do
      collection do
        get(:export)
      end
    end
    resources(:user_text_versions, only: %i[index show]) do
      get(:diff, on: :collection)
    end
    resources(:user_approvals, only: %i[index]) do
      member do
        put(:approve)
        put(:reject)
      end
    end
  end
  resources(:api_keys) do
    get(:usage, on: :member)
  end
  resources(:popular, only: %i[index]) do
    collection do
      get(:uploads)
      get(:followed_tags)
      get(:views)
      get("/views/top", to: "popular#top_views", as: "top_views")
      get(:searches)
      get("/searches/top", to: "popular#top_searches", as: "top_searches")
      get("/searches/missed", to: "popular#missed_searches", as: "missed_searches")
      get("/searches/missed/top", to: "popular#top_missed_searches", as: "top_missed_searches")
    end
  end
  namespace(:users) do
    resource(:count_fixes, only: %i[new create])
    resource(:email_notification, only: %i[show destroy])
    resource(:password_reset, only: %i[new create edit update])
    resource(:login_reminder, only: %i[new create])
    resource(:deletion, only: %i[show destroy])
    resource(:email_change, only: %i[new create])
    resource(:dmail_filter, only: %i[show edit update])
  end

  resources(:avoid_postings, constraints: id_name_constraint) do
    collection do
      resources(:versions, only: %i[index], controller: "avoid_postings/versions", as: "avoid_posting_versions")
    end
    member do
      put(:delete)
      put(:undelete)
    end
  end

  resources(:tickets, except: %i[destroy]) do
    member do
      post(:claim)
      post(:unclaim)
    end
  end

  resources(:takedowns) do
    collection do
      post(:count_matching_posts)
    end
    member do
      post(:add_by_ids)
      post(:add_by_tags)
      post(:remove_by_ids)
    end
  end

  resources(:artists, constraints: id_name_constraint) do
    member do
      put(:revert)
    end
    collection do
      get(:show_or_new)
      resources(:versions, only: %i[index], controller: "artists/versions", as: "artist_versions") do
        get(:search, on: :collection)
      end
      resources(:urls, only: %i[index], controller: "artists/urls", as: "artist_urls")
    end
  end
  resources(:bans) do
    get(:acknowledge, on: :collection)
  end
  resources(:bulk_update_requests) do
    member do
      post(:approve)
      put(:revert)
    end
    collection do
      resources(:versions, controller: "bulk_update_requests/versions", as: "bulk_update_request_versions", only: %i[index]) do
        member do
          get(:diff)
          put(:undo)
        end
      end
    end
  end
  resources(:comments) do
    resource(:votes, controller: "comments/votes", only: %i[create destroy])
    resource(:edits, controller: "edit_histories", only: %i[show])
    collection do
      get(:search)
      resources(:votes, controller: "comments/votes", as: "comment_votes", only: %i[index]) do
        collection do
          post(:lock)
          post(:delete)
        end
      end
    end
    member do
      put(:hide)
      put(:unhide)
      put(:warning)
      put(:mark_spam)
      put(:mark_not_spam)
    end
  end
  resources(:db_exports, only: %i[index])
  resources(:dmails, only: %i[new create index show destroy]) do
    member do
      put(:mark_as_read)
      put(:mark_as_unread)
      put(:mark_spam)
      put(:mark_not_spam)
    end
    collection do
      put(:mark_all_as_read)
    end
  end
  resources(:dtext_links, only:  %i[index])
  resource(:dtext_preview, only: %i[create])
  resources(:favorites, only: %i[index create destroy]) do
    collection do
      get(:clear)
      put(:clear)
    end
  end
  resources(:forums, only: %i[index show]) do
    collection do
      get(:search)
      resources(:categories, controller: "forums/categories", as: "forum_categories", only: %i[index show new create edit update destroy]) do
        collection do
          post(:reorder)
          put(:mark_all_as_read)
        end
        member do
          match(:move_all_topics, via: %i[get post])
          put(:mark_as_read)
        end
      end
      resources(:posts, controller: "forums/posts", as: "forum_posts") do
        resource(:votes, controller: "forums/posts/votes", only: %i[create destroy])
        resource(:edits, controller: "edit_histories", only: %i[show])
        member do
          put(:hide)
          put(:unhide)
          put(:warning)
          put(:mark_spam)
          put(:mark_not_spam)
        end
        collection do
          resources(:votes, controller: "forums/posts/votes", as: "forum_post_votes", only: %i[index]) do
            post(:delete, on: :collection)
          end
        end
      end
      resources(:topics, controller: "forums/topics", as: "forum_topics") do
        member do
          put(:hide)
          put(:unhide)
          put(:lock)
          put(:unlock)
          put(:sticky)
          put(:unsticky)
          put(:subscribe)
          put(:unsubscribe)
          put(:mute)
          put(:unmute)
          put(:mark_as_read)
          resource(:merge, controller: "forums/topics/merges", as: "merge_forum_topic", only: %i[show create destroy]) do
            get(:undo)
          end
          resource(:move, controller: "forums/topics/moves", as: "move_forum_topic", only: %i[show create])
        end
      end
    end
  end
  resources(:help_pages, controller: "help", path: "help")
  resources(:ip_bans, only: %i[index new create destroy])
  resources(:upload_whitelists, except: %i[show]) do
    collection do
      get(:is_allowed)
    end
  end
  resources(:email_blacklists, only: %i[new create destroy index])
  scope(module: :media_assets, path: "media_assets") do
    resource(:status, as: "media_asset_status", only: %i[show update])
    resources(:mascots, only: %i[index], as: "mascot_media_assets")
    resources(:post_replacements, only: %i[index], as: "post_replacement_media_assets") do
      member do
        put(:append)
        put(:finalize)
        put(:cancel)
      end
    end
    resources(:uploads, only: %i[index], as: "upload_media_assets") do
      member do
        put(:append)
        put(:finalize)
        put(:cancel)
      end
    end
  end
  resources(:mod_actions, only: %i[index show])
  resources(:news_updates, except: %i[show])
  resources(:notes) do
    collection do
      get(:search)
      resources(:versions, controller: "notes/versions", as: "note_versions", only: %i[index])
    end
    member do
      put(:revert)
    end
  end
  resources(:notifications, only: %i[index show destroy]) do
    member do
      put(:mark_as_read)
    end
    put(:mark_all_as_read, on: :collection)
  end
  resources(:pools) do
    resource(:order, only: %i[edit], controller: "pools/orders")
    member do
      put(:revert)
    end
    collection do
      get(:gallery)
      resources(:versions, controller: "pools/versions", as: "pool_versions", only: %i[index]) do
        member do
          get(:diff)
          put(:undo)
        end
      end
    end
  end
  resources(:posts, only: %i[index show update destroy]) do
    resource(:recommended, only: %i[show], controller: "posts/recommendations")
    resource(:similar, only: %i[show], controller: "posts/iqdb")
    resource(:votes, controller: "posts/votes", only: %i[create destroy])
    resource(:flag, controller: "posts/flags", only: %i[destroy])
    collection do
      get(:random)
      get(:uploaders)
      resources(:approvals, controller: "posts/approvals", as: "post_approvals", only: %i[index create destroy])
      resources(:appeals, controller: "posts/appeals", as: "post_appeals", only: %i[index show new create destroy])
      resources(:deleted, controller: "posts/deleted", as: "deleted_posts", only: %i[index])
      resources(:deletion_reasons, controller: "posts/deletion_reasons", as: "post_deletion_reasons", only: %i[index new create edit update destroy]) do
        post(:reorder, on: :collection)
      end
      resources(:disapprovals, controller: "posts/disapprovals", as: "post_disapprovals", only: %i[create index])
      resources(:events, controller: "posts/events", as: "post_events", only: :index)
      resources(:flags, controller: "posts/flags", as: "post_flags", except: %i[edit update])
      resource(:iqdb, controller: "posts/iqdb", as: "posts_iqdb", only: %i[show]) do
        collection do
          post(:show)
        end
      end
      resource(:recommendations, controller: "posts/recommendations", as: "post_recommendations", only: %i[show])
      resources(:replacements, controller: "posts/replacements", as: "post_replacements", only: %i[index new create destroy]) do
        member do
          put(:approve)
          put(:reject)
          get(:reject_with_reason)
          post(:promote)
          put(:toggle_penalize)
        end
        collection do
          resources(:rejection_reasons, controller: "posts/replacements/rejection_reasons", as: "post_replacement_rejection_reasons", only: %i[index new create edit update destroy]) do
            post(:reorder, on: :collection)
          end
        end
      end
      resources(:versions, controller: "posts/versions", as: "post_versions", only: %i[index]) do
        member do
          put(:undo)
        end
      end
      resources(:votes, controller: "posts/votes", as: "post_votes", only: %i[index]) do
        collection do
          post(:lock)
          post(:delete)
        end
      end
    end
    member do
      put(:update_iqdb)
      put(:revert)
      put(:copy_notes)
      get(:show_seq)
      post(:mark_as_translated)
      get(:comments, to: "comments#for_post")
      get(:favorites)

      put(:expunge)
      put(:finish_in_progress)
      get(:delete)
      put(:undelete)
      put(:regenerate_thumbnails)
      put(:regenerate_videos)
      put(:ai_check)
      post(:add_to_pool)
      post(:remove_from_pool)
      get("/frame/:frame", to: "posts#frame", as: "frame")
      resource(:move_favorites, controller: "posts/move_favorites", as: "move_favorites_post", only: %i[show create])
    end
  end
  resources(:qtags, path: "q", only: %i[show])
  resources(:staff_notes, only: %i[index])
  resources(:rules, only: %i[index new create edit update destroy]) do
    collection do
      get(:order)
      post(:reorder)
      get(:builder)
      resources(:categories, controller: "rules/categories", as: "rule_categories", except: %i[show]) do
        collection do
          get(:order)
          post(:reorder)
        end
      end
      resources(:quick, controller: "rules/quick", as: "quick_rules", only: %i[index new create edit update destroy]) do
        collection do
          get(:order)
          post(:reorder)
        end
      end
    end
  end
  resource(:session, only: %i[new create destroy]) do
    collection do
      get(:confirm_password)
      post(:verify_mfa)
    end
  end
  resources(:stats, only: %i[index])
  resource(:status, only: %i[show])
  resource(:system, only: %i[show])
  resources(:tags, constraints: id_name_constraint, only: %i[index show edit update]) do
    collection do
      get(:preview)
      get(:meta_search)
      get(:followed)
      resource(:related, controller: "tags/related", as: "related_tags", only: %i[show]) do
        collection do
          get(:bulk)
          post(:bulk)
        end
      end
      resources(:versions, controller: "tags/versions", as: "tag_versions", only: %i[index])
      resources(:aliases, controller: "tags/aliases", as: "tag_aliases") do
        put(:approve, on: :member)
      end
      resources(:implications, controller: "tags/implications", as: "tag_implications") do
        put(:approve, on: :member)
      end
    end
    member do
      get(:followers)
      put(:follow)
      put(:unfollow)
      put(:correct)
    end
  end
  resources(:uploads, only: %i[index show new create]) do
    get(:settings, on: :collection)
  end
  resources(:users, except: %i[edit update]) do
    resource(:password, only: %i[edit], controller: "users/passwords")
    resources(:api_keys, controller: "api_keys")
    resources(:staff_notes, only: %i[index new create destroy update], controller: "staff_notes") do
      put(:undelete)
    end
    resources(:text_versions, only: %i[index], to: "moderator/user_text_versions#for_user")
    resources(:blocks, only: %i[index new create edit update destroy], controller: "users/blocks")

    collection do
      get(:home)
      get(:search)
      get(:upload_limit)
      get(:custom_style)
      get(:me)
      get(:edit)
      post("/update", to: "users#update", as: "update")
      resources(:feedbacks, controller: "users/feedbacks", as: "user_feedbacks") do
        collection do
          get(:search)
        end
        member do
          put(:delete)
          put(:undelete)
        end
      end
      resources(:name_change_requests, controller: "users/name_change_requests", as: "user_name_change_requests", only: %i[index show new create])
      resource(:revert, controller: "users/reverts", as: "user_revert", only: %i[new create])
      resources(:events, controller: "users/events", as: "user_events", only: %i[index])
      resources(:sessions, controller: "users/sessions", as: "user_sessions", only: %i[index])
      resource(:mfa, controller: "users/mfa", as: "user_mfa", only: %i[edit update destroy]) do
        resource(:backup_codes, controller: "users/mfa/backup_codes", only: %i[show create])
      end
      resources(:linked_accounts, controller: "users/linked_accounts", as: "user_linked_accounts", only: %i[destroy]) do
        get(:edit, on: :collection)
      end
    end
    member do
      put(:delete)
      put(:undelete)
      put(:unban)
      get(:info)
    end
  end
  resources(:wiki_pages, constraints: id_name_constraint) do
    member do
      put(:revert)
      resource(:merge, controller: "wiki_pages/merges", as: "merge_wiki_page", only: %i[show create])
    end
    collection do
      get(:search)
      get(:show_or_new)
      resources(:versions, controller: "wiki_pages/versions", as: "wiki_page_versions", only: %i[index show]) do
        collection do
          get(:diff)
        end
      end
    end
  end
  resources(:post_sets) do
    collection do
      get(:for_select)
      resources(:maintainers, controller: "post_sets/maintainers", as: "post_set_maintainers", only: %i[index create destroy]) do
        member do
          get(:approve)
          get(:block)
          get(:deny)
        end
      end
    end
    member do
      get(:maintainers)
      get(:post_list)
      post(:update_posts)
      post(:add_posts)
      post(:remove_posts)
    end
  end
  resource(:email, only: %i[]) do
    collection do
      get(:activate_user)
      get(:resend_confirmation)
    end
  end
  resources(:mascots, only: %i[index new create edit update destroy])
  resource(:api, controller: "api_documentation", as: "api_documentation", only: %i[show]) do
    get(:spec)
  end

  options("*all", to: "application#enable_cors")

  get("/static/keyboard_shortcuts", to: "static#keyboard_shortcuts", as: "keyboard_shortcuts")
  get("/static/site_map", to: "static#site_map", as: "site_map")
  get("/static/privacy", to: "static#privacy", as: "privacy_policy")
  get("/static/takedown", to: "static#takedown", as: "takedown_static")
  get("/static/terms_of_service", to: "static#terms_of_service", as: "terms_of_service")
  get("/static/contact", to: "static#contact", as: "contact")
  get("/static/discord", to: "static#discord", as: "discord_get")
  post("/static/discord", to: "static#discord", as: "discord_post")
  get("/static/toggle_mobile_mode", to: "static#toggle_mobile_mode", as: "toggle_mobile_mode")
  get("/static/theme", to: "static#theme", as: "theme")
  get("/static/staff", to: "static#staff", as: "staff")
  get("/static/avoid_posting", to: "static#avoid_posting", as: "avoid_posting_static")
  get("/robots", to: "static#robots", as: "robots")
  get("/sitemap", to: "static#site_map", as: "sitemap_root")
  get("/sitemap/*type", to: "static#site_map", as: "sitemap_type")
  get("/route", to: "static#recognize_route", as: "recognize_route")
  get("/up", to: "rails/health#show", as: "health_check")
  root(to: "static#home")

  get("*other", to: "static#not_found")
end

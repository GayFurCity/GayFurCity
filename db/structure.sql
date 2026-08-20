SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: pg_trgm; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS pg_trgm WITH SCHEMA public;


--
-- Name: EXTENSION pg_trgm; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION pg_trgm IS 'text similarity measurement and index searching based on trigrams';


--
-- Name: posts_trigger_change_seq(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.posts_trigger_change_seq() RETURNS trigger
    LANGUAGE plpgsql
    AS $$ DECLARE old_md5 text; new_md5 text; BEGIN SELECT md5 INTO old_md5 FROM upload_media_assets WHERE id = OLD.upload_media_asset_id; SELECT md5 INTO new_md5 FROM upload_media_assets WHERE id = NEW.upload_media_asset_id; IF NEW.source IS DISTINCT FROM OLD.source OR NEW.rating IS DISTINCT FROM OLD.rating OR NEW.is_note_locked IS DISTINCT FROM OLD.is_note_locked OR NEW.is_rating_locked IS DISTINCT FROM OLD.is_rating_locked OR NEW.is_status_locked IS DISTINCT FROM OLD.is_status_locked OR NEW.is_pending IS DISTINCT FROM OLD.is_pending OR NEW.is_flagged IS DISTINCT FROM OLD.is_flagged OR NEW.is_deleted IS DISTINCT FROM OLD.is_deleted OR NEW.is_appealed IS DISTINCT FROM OLD.is_appealed OR NEW.approver_id IS DISTINCT FROM OLD.approver_id OR NEW.last_noted_at IS DISTINCT FROM OLD.last_noted_at OR NEW.tag_string IS DISTINCT FROM OLD.tag_string OR NEW.typed_tag_string IS DISTINCT FROM OLD.typed_tag_string OR NEW.parent_id IS DISTINCT FROM OLD.parent_id OR NEW.has_children IS DISTINCT FROM OLD.has_children OR NEW.has_active_children IS DISTINCT FROM OLD.has_active_children OR NEW.bit_flags IS DISTINCT FROM OLD.bit_flags OR NEW.locked_tags IS DISTINCT FROM OLD.locked_tags OR NEW.description IS DISTINCT FROM OLD.description OR NEW.bg_color IS DISTINCT FROM OLD.bg_color OR NEW.is_comment_disabled IS DISTINCT FROM OLD.is_comment_disabled OR NEW.is_comment_locked IS DISTINCT FROM OLD.is_comment_locked OR NEW.thumbnail_frame IS DISTINCT FROM OLD.thumbnail_frame OR NEW.min_edit_level IS DISTINCT FROM OLD.min_edit_level OR NEW.last_commented_at IS DISTINCT FROM OLD.last_commented_at OR NEW.comment_count IS DISTINCT FROM OLD.comment_count OR NEW.qtags IS DISTINCT FROM OLD.qtags OR NEW.tag_count_general IS DISTINCT FROM OLD.tag_count_general OR NEW.tag_count_artist IS DISTINCT FROM OLD.tag_count_artist OR NEW.tag_count_contributor IS DISTINCT FROM OLD.tag_count_contributor OR NEW.tag_count_character IS DISTINCT FROM OLD.tag_count_character OR NEW.tag_count_copyright IS DISTINCT FROM OLD.tag_count_copyright OR NEW.tag_count_meta IS DISTINCT FROM OLD.tag_count_meta OR NEW.tag_count_species IS DISTINCT FROM OLD.tag_count_species OR NEW.tag_count_invalid IS DISTINCT FROM OLD.tag_count_invalid OR NEW.tag_count_lore IS DISTINCT FROM OLD.tag_count_lore OR NEW.tag_count_gender IS DISTINCT FROM OLD.tag_count_gender OR NEW.tag_count_important IS DISTINCT FROM OLD.tag_count_important OR NEW.is_unlisted IS DISTINCT FROM OLD.is_unlisted OR NEW.is_in_progress IS DISTINCT FROM OLD.is_in_progress OR old_md5 IS DISTINCT FROM new_md5 THEN NEW.change_seq = nextval('public.posts_change_seq_seq'); END IF; RETURN NEW; END; $$;


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: api_keys; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.api_keys (
    id bigint NOT NULL,
    user_id bigint NOT NULL,
    key character varying NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    name character varying DEFAULT ''::character varying NOT NULL,
    permissions character varying[] DEFAULT '{}'::character varying[] NOT NULL,
    permitted_ip_addresses inet[] DEFAULT '{}'::inet[] NOT NULL,
    uses integer DEFAULT 0 NOT NULL,
    last_used_at timestamp(6) without time zone,
    last_ip_address inet
);


--
-- Name: api_keys_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.api_keys_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: api_keys_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.api_keys_id_seq OWNED BY public.api_keys.id;


--
-- Name: ar_internal_metadata; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ar_internal_metadata (
    key character varying NOT NULL,
    value character varying,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: artist_urls; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.artist_urls (
    id bigint NOT NULL,
    artist_id bigint NOT NULL,
    url text NOT NULL,
    normalized_url text NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    is_active boolean DEFAULT true NOT NULL
);


--
-- Name: artist_urls_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.artist_urls_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: artist_urls_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.artist_urls_id_seq OWNED BY public.artist_urls.id;


--
-- Name: artist_versions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.artist_versions (
    id bigint NOT NULL,
    artist_id bigint NOT NULL,
    name character varying NOT NULL,
    updater_id bigint NOT NULL,
    updater_ip_addr inet NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    other_names text[] DEFAULT '{}'::text[] NOT NULL,
    urls text[] DEFAULT '{}'::text[] NOT NULL,
    notes_changed boolean DEFAULT false,
    linked_user_id bigint
);


--
-- Name: artist_versions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.artist_versions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: artist_versions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.artist_versions_id_seq OWNED BY public.artist_versions.id;


--
-- Name: artists; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.artists (
    id bigint NOT NULL,
    name character varying NOT NULL,
    creator_id bigint NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    other_names text[] DEFAULT '{}'::text[] NOT NULL,
    linked_user_id bigint,
    is_locked boolean DEFAULT false,
    creator_ip_addr inet NOT NULL
);


--
-- Name: artists_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.artists_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: artists_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.artists_id_seq OWNED BY public.artists.id;


--
-- Name: avoid_posting_versions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.avoid_posting_versions (
    id bigint NOT NULL,
    updater_id bigint NOT NULL,
    avoid_posting_id bigint NOT NULL,
    updater_ip_addr inet NOT NULL,
    details character varying DEFAULT ''::character varying NOT NULL,
    staff_notes character varying DEFAULT ''::character varying NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: avoid_posting_versions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.avoid_posting_versions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: avoid_posting_versions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.avoid_posting_versions_id_seq OWNED BY public.avoid_posting_versions.id;


--
-- Name: avoid_postings; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.avoid_postings (
    id bigint NOT NULL,
    creator_id bigint NOT NULL,
    updater_id bigint NOT NULL,
    creator_ip_addr inet NOT NULL,
    updater_ip_addr inet NOT NULL,
    details character varying DEFAULT ''::character varying NOT NULL,
    staff_notes character varying DEFAULT ''::character varying NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    artist_id bigint NOT NULL
);


--
-- Name: avoid_postings_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.avoid_postings_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: avoid_postings_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.avoid_postings_id_seq OWNED BY public.avoid_postings.id;


--
-- Name: bans; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.bans (
    id bigint NOT NULL,
    user_id bigint NOT NULL,
    reason text NOT NULL,
    banner_id bigint NOT NULL,
    expires_at timestamp without time zone,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    banner_ip_addr inet NOT NULL
);


--
-- Name: bans_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.bans_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: bans_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.bans_id_seq OWNED BY public.bans.id;


--
-- Name: bulk_update_request_imports; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.bulk_update_request_imports (
    id bigint NOT NULL,
    creator_id bigint NOT NULL,
    creator_ip_addr inet NOT NULL,
    updater_id bigint NOT NULL,
    updater_ip_addr inet NOT NULL,
    forum_topic_id bigint,
    script text NOT NULL,
    status character varying DEFAULT 'pending'::character varying NOT NULL,
    status_message text,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: bulk_update_request_imports_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.bulk_update_request_imports_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: bulk_update_request_imports_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.bulk_update_request_imports_id_seq OWNED BY public.bulk_update_request_imports.id;


--
-- Name: bulk_update_request_versions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.bulk_update_request_versions (
    id bigint NOT NULL,
    bulk_update_request_id bigint NOT NULL,
    updater_id bigint NOT NULL,
    updater_ip_addr inet NOT NULL,
    script character varying NOT NULL,
    script_changed boolean DEFAULT false NOT NULL,
    status character varying NOT NULL,
    status_changed boolean DEFAULT false NOT NULL,
    title character varying NOT NULL,
    title_changed boolean DEFAULT false NOT NULL,
    version integer DEFAULT 1 NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: bulk_update_request_versions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.bulk_update_request_versions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: bulk_update_request_versions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.bulk_update_request_versions_id_seq OWNED BY public.bulk_update_request_versions.id;


--
-- Name: bulk_update_requests; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.bulk_update_requests (
    id bigint NOT NULL,
    creator_id bigint NOT NULL,
    forum_topic_id bigint,
    script text NOT NULL,
    status character varying DEFAULT 'pending'::character varying NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    approver_id bigint,
    forum_post_id bigint,
    title text DEFAULT ''::text NOT NULL,
    creator_ip_addr inet DEFAULT '127.0.0.1'::inet NOT NULL,
    updater_id bigint NOT NULL,
    updater_ip_addr inet NOT NULL,
    undo_data jsonb DEFAULT '[]'::jsonb NOT NULL
);


--
-- Name: bulk_update_requests_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.bulk_update_requests_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: bulk_update_requests_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.bulk_update_requests_id_seq OWNED BY public.bulk_update_requests.id;


--
-- Name: comment_votes; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.comment_votes (
    id bigint NOT NULL,
    comment_id bigint NOT NULL,
    user_id bigint NOT NULL,
    score integer NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    user_ip_addr inet NOT NULL,
    is_locked boolean DEFAULT false NOT NULL
);


--
-- Name: comment_votes_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.comment_votes_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: comment_votes_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.comment_votes_id_seq OWNED BY public.comment_votes.id;


--
-- Name: comments; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.comments (
    id bigint NOT NULL,
    post_id bigint NOT NULL,
    creator_id bigint NOT NULL,
    body text NOT NULL,
    creator_ip_addr inet NOT NULL,
    score integer DEFAULT 0 NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    updater_id bigint NOT NULL,
    updater_ip_addr inet NOT NULL,
    do_not_bump_post boolean DEFAULT false NOT NULL,
    is_hidden boolean DEFAULT false NOT NULL,
    is_sticky boolean DEFAULT false NOT NULL,
    warning_type integer,
    warning_user_id bigint,
    notified_mentions bigint[] DEFAULT '{}'::bigint[] NOT NULL,
    is_spam boolean DEFAULT false NOT NULL
);


--
-- Name: comments_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.comments_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: comments_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.comments_id_seq OWNED BY public.comments.id;


--
-- Name: config; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.config (
    id text DEFAULT 'config'::text NOT NULL,
    contributor_suffixes text DEFAULT 'va, modeler'::text NOT NULL,
    comment_bump_threshold integer DEFAULT 40 NOT NULL,
    pending_uploads_limit integer DEFAULT 3 NOT NULL,
    comment_limit integer DEFAULT 15 NOT NULL,
    comment_limit_bypass integer DEFAULT 15 NOT NULL,
    comment_vote_limit integer DEFAULT 25 NOT NULL,
    comment_vote_limit_bypass integer DEFAULT 15 NOT NULL,
    post_vote_limit integer DEFAULT 1000 NOT NULL,
    post_vote_limit_bypass integer DEFAULT 15 NOT NULL,
    dmail_minute_limit integer DEFAULT 2 NOT NULL,
    dmail_minute_limit_bypass integer DEFAULT 20 NOT NULL,
    dmail_hour_limit integer DEFAULT 30 NOT NULL,
    dmail_hour_limit_bypass integer DEFAULT 20 NOT NULL,
    dmail_day_limit integer DEFAULT 60 NOT NULL,
    dmail_day_limit_bypass integer DEFAULT 20 NOT NULL,
    dmail_restricted_day_limit integer DEFAULT 5 NOT NULL,
    tag_suggestion_limit integer DEFAULT 15 NOT NULL,
    tag_suggestion_limit_bypass integer DEFAULT 15 NOT NULL,
    forum_vote_limit integer DEFAULT 25 NOT NULL,
    forum_vote_limit_bypass integer DEFAULT 15 NOT NULL,
    artist_edit_limit integer DEFAULT 25 NOT NULL,
    artist_edit_limit_bypass integer DEFAULT 15 NOT NULL,
    wiki_edit_limit integer DEFAULT 60 NOT NULL,
    wiki_edit_limit_bypass integer DEFAULT 15 NOT NULL,
    note_edit_limit integer DEFAULT 50 NOT NULL,
    note_edit_limit_bypass integer DEFAULT 15 NOT NULL,
    pool_limit integer DEFAULT 2 NOT NULL,
    pool_limit_bypass integer DEFAULT 15 NOT NULL,
    pool_edit_limit integer DEFAULT 10 NOT NULL,
    pool_edit_limit_bypass integer DEFAULT 15 NOT NULL,
    pool_post_edit_limit integer DEFAULT 30 NOT NULL,
    pool_post_edit_limit_bypass integer DEFAULT 15 NOT NULL,
    post_edit_limit integer DEFAULT 150 NOT NULL,
    post_edit_limit_bypass integer DEFAULT 15 NOT NULL,
    post_appeal_limit integer DEFAULT 5 NOT NULL,
    post_appeal_limit_bypass integer DEFAULT 15 NOT NULL,
    post_flag_limit integer DEFAULT 20 NOT NULL,
    post_flag_limit_bypass integer DEFAULT 15 NOT NULL,
    hourly_upload_limit integer DEFAULT 30 NOT NULL,
    ticket_limit integer DEFAULT 30 NOT NULL,
    ticket_limit_bypass integer DEFAULT 15 NOT NULL,
    pool_category_change_limit integer DEFAULT 30 NOT NULL,
    post_replacement_per_day_limit integer DEFAULT 2 NOT NULL,
    post_replacement_per_day_limit_bypass integer DEFAULT 20 NOT NULL,
    post_replacement_per_post_limit integer DEFAULT 5 NOT NULL,
    post_replacement_per_post_limit_bypass integer DEFAULT 20 NOT NULL,
    compact_uploader_minimum_posts integer DEFAULT 10 NOT NULL,
    bur_entry_limit jsonb DEFAULT '{"10": 50, "40": -1}'::jsonb NOT NULL,
    max_numbered_pages integer DEFAULT 1000 NOT NULL,
    max_per_page integer DEFAULT 500 NOT NULL,
    comment_max_size integer DEFAULT 10000 NOT NULL,
    dmail_max_size integer DEFAULT 50000 NOT NULL,
    forum_post_max_size integer DEFAULT 50000 NOT NULL,
    forum_category_description_max_size integer DEFAULT 250 NOT NULL,
    note_max_size integer DEFAULT 1000 NOT NULL,
    pool_description_max_size integer DEFAULT 10000 NOT NULL,
    post_description_max_size integer DEFAULT 50000 NOT NULL,
    ticket_max_size integer DEFAULT 5000 NOT NULL,
    user_about_max_size integer DEFAULT 50000 NOT NULL,
    blacklisted_tags_max_size integer DEFAULT 150000 NOT NULL,
    custom_style_max_size integer DEFAULT 500000 NOT NULL,
    wiki_page_max_size integer DEFAULT 250000 NOT NULL,
    user_feedback_max_size integer DEFAULT 20000 NOT NULL,
    news_update_max_size integer DEFAULT 50000 NOT NULL,
    pool_post_limit integer DEFAULT 1000 NOT NULL,
    pool_post_limit_bypass integer DEFAULT 40 NOT NULL,
    set_post_limit integer DEFAULT 10000 NOT NULL,
    set_post_limit_bypass integer DEFAULT 40 NOT NULL,
    disapproval_message_max_size integer DEFAULT 250 NOT NULL,
    max_upload_per_request integer DEFAULT 75 NOT NULL,
    max_file_size integer DEFAULT 200 NOT NULL,
    max_file_sizes jsonb DEFAULT '{"gif": 30, "jpg": 100, "mp4": 200, "png": 100, "apng": 30, "webm": 200, "webp": 100}'::jsonb NOT NULL,
    max_mascot_file_sizes jsonb DEFAULT '{"jpg": 1000, "png": 1000, "webp": 1000}'::jsonb NOT NULL,
    max_video_duration integer DEFAULT 1800 NOT NULL,
    max_image_resolution integer DEFAULT 441 NOT NULL,
    max_tags_per_post integer DEFAULT 2000 NOT NULL,
    enable_signups boolean DEFAULT true NOT NULL,
    user_approvals_enabled boolean DEFAULT true NOT NULL,
    enable_email_verification boolean DEFAULT false NOT NULL,
    enable_stale_forum_topics boolean DEFAULT true NOT NULL,
    enable_sock_puppet_validation boolean DEFAULT false NOT NULL,
    forum_topic_stale_window integer DEFAULT 180 NOT NULL,
    forum_topic_aibur_stale_window integer DEFAULT 365 NOT NULL,
    flag_notice_wiki_page character varying DEFAULT 'internal:flag_notice'::character varying NOT NULL,
    replacement_notice_wiki_page character varying DEFAULT 'internal:replacement_notice'::character varying NOT NULL,
    avoid_posting_notice_wiki_page character varying DEFAULT 'internal:avoid_posting_notice'::character varying NOT NULL,
    discord_notice_wiki_page character varying DEFAULT 'internal:discord_notice'::character varying NOT NULL,
    rules_body_wiki_page character varying DEFAULT 'internal:rules_body'::character varying NOT NULL,
    restricted_notice_wiki_page character varying DEFAULT 'internal:restricted_notice'::character varying NOT NULL,
    rejected_notice_wiki_page character varying DEFAULT 'internal:rejected_notice'::character varying NOT NULL,
    appeal_notice_wiki_page character varying DEFAULT 'internal:appeal_notice'::character varying NOT NULL,
    ban_notice_wiki_page character varying DEFAULT 'internal:ban_notice'::character varying NOT NULL,
    user_approved_wiki_page character varying DEFAULT 'internal:user_approved'::character varying NOT NULL,
    user_rejected_wiki_page character varying DEFAULT 'internal:user_rejected'::character varying NOT NULL,
    records_per_page integer DEFAULT 100 NOT NULL,
    tag_change_request_update_limit jsonb DEFAULT '{"15": 500, "20": 1000, "30": 10000, "40": 100000, "50": -1}'::jsonb NOT NULL,
    followed_tag_limit jsonb DEFAULT '{"10": 100, "15": 500, "20": 1000}'::jsonb NOT NULL,
    tag_type_edit_limit jsonb DEFAULT '{"10": 100, "15": 1000, "20": 10000, "40": -1}'::jsonb NOT NULL,
    tag_type_edit_implicit_limit jsonb DEFAULT '{"10": 100, "15": 1000}'::jsonb NOT NULL,
    alias_category_change_cutoff integer DEFAULT 10000 NOT NULL,
    max_multi_count integer DEFAULT 100 NOT NULL,
    takedown_email character varying DEFAULT 'admin@gayfur.city'::character varying NOT NULL,
    contact_email character varying DEFAULT 'admin@gayfur.city'::character varying NOT NULL,
    default_user_timezone character varying DEFAULT 'Central Time (US & Canada)'::character varying,
    alias_and_implication_forum_category integer DEFAULT 1 NOT NULL,
    default_forum_category integer DEFAULT 1 NOT NULL,
    upload_whitelists_forum_topic integer DEFAULT 0 NOT NULL,
    post_sample_size integer DEFAULT 300 NOT NULL,
    updated_at timestamp(6) without time zone,
    lore_suffixes text DEFAULT 'lore'::text NOT NULL,
    artist_exclusion_tags text DEFAULT 'avoid_posting, conditional_dnp, epilepsy_warning, sound_warning'::text NOT NULL,
    flag_ai_posts boolean DEFAULT true NOT NULL,
    tag_ai_posts boolean DEFAULT true NOT NULL,
    ai_confidence_threshold integer DEFAULT 50 NOT NULL,
    post_flag_note_max_size integer DEFAULT 10000 NOT NULL,
    pool_category_change_cutoff integer DEFAULT 30 NOT NULL,
    pool_category_change_cutoff_bypass integer DEFAULT 20 NOT NULL,
    pool_name_max_size integer DEFAULT 250 NOT NULL,
    default_blacklist character varying DEFAULT ''::character varying NOT NULL,
    safeblocked_tags character varying DEFAULT ''::character varying NOT NULL,
    enable_autotagging boolean DEFAULT true NOT NULL,
    enable_image_cropping boolean DEFAULT true NOT NULL,
    enable_bad_sources boolean DEFAULT true NOT NULL,
    safe_mode boolean DEFAULT false NOT NULL,
    show_tag_scripting integer DEFAULT 15 NOT NULL,
    show_backtrace integer DEFAULT 20 NOT NULL,
    bur_nuke integer DEFAULT 40 NOT NULL,
    app_name character varying DEFAULT 'GayFur City'::character varying NOT NULL,
    canonical_app_name character varying DEFAULT 'GayFur City'::character varying NOT NULL,
    app_description character varying DEFAULT 'Your one-stop shop for gay furries.'::character varying NOT NULL,
    anonymous_user_name character varying DEFAULT 'Anonymous'::character varying NOT NULL,
    system_user_name character varying DEFAULT 'System'::character varying NOT NULL,
    image_width jsonb DEFAULT '{"max": 40000, "min": 300}'::jsonb NOT NULL,
    image_height jsonb DEFAULT '{"max": 40000, "min": 300}'::jsonb NOT NULL,
    mascot_width jsonb DEFAULT '{"max": 1000, "min": 250}'::jsonb NOT NULL,
    mascot_height jsonb DEFAULT '{"max": 1000, "min": 250}'::jsonb NOT NULL,
    postgres_query_timeout jsonb DEFAULT '{"0": 3000, "15": 6000, "19": 9000}'::jsonb NOT NULL,
    elasticsearch_query_timeout jsonb DEFAULT '{"0": 3000, "15": 6000, "19": 9000}'::jsonb NOT NULL,
    elasticsearch_request_timeout jsonb DEFAULT '{"0": 5, "15": 10, "19": 15}'::jsonb NOT NULL,
    request_cycle_timeout jsonb DEFAULT '{"0": 10000, "15": 20000, "19": 30000}'::jsonb NOT NULL,
    db_exports_enabled boolean DEFAULT false NOT NULL,
    blacklisted_preview_url character varying DEFAULT '/images/blacklisted-preview.png'::character varying NOT NULL,
    deleted_preview_url character varying DEFAULT '/images/deleted-preview.png'::character varying NOT NULL,
    download_preview_url character varying DEFAULT '/images/download-preview.png'::character varying NOT NULL,
    missing_preview_url character varying DEFAULT '/images/missing-preview.png'::character varying NOT NULL,
    placeholder_preview_url character varying DEFAULT '/images/placeholder-preview.png'::character varying NOT NULL,
    tag_query_limit jsonb DEFAULT '{"0": 40}'::jsonb NOT NULL,
    anonymous_hard_tag_limit integer DEFAULT 40 NOT NULL
);


--
-- Name: db_exports; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.db_exports (
    id bigint NOT NULL,
    name character varying NOT NULL,
    date date NOT NULL,
    file_size bigint DEFAULT 0 NOT NULL,
    checksum character varying,
    columns jsonb DEFAULT '{}'::jsonb NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: db_exports_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.db_exports_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: db_exports_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.db_exports_id_seq OWNED BY public.db_exports.id;


--
-- Name: destroyed_posts; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.destroyed_posts (
    id bigint NOT NULL,
    post_id bigint NOT NULL,
    md5 character varying NOT NULL,
    destroyer_id bigint NOT NULL,
    destroyer_ip_addr inet NOT NULL,
    uploader_id bigint NOT NULL,
    uploader_ip_addr inet NOT NULL,
    upload_date timestamp without time zone,
    post_data json NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    reason character varying DEFAULT ''::character varying NOT NULL,
    notify boolean DEFAULT true NOT NULL
);


--
-- Name: destroyed_posts_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.destroyed_posts_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: destroyed_posts_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.destroyed_posts_id_seq OWNED BY public.destroyed_posts.id;


--
-- Name: dmail_filters; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.dmail_filters (
    id bigint NOT NULL,
    user_id bigint NOT NULL,
    words text NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: dmail_filters_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.dmail_filters_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: dmail_filters_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.dmail_filters_id_seq OWNED BY public.dmail_filters.id;


--
-- Name: dmails; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.dmails (
    id bigint NOT NULL,
    owner_id bigint NOT NULL,
    from_id bigint NOT NULL,
    to_id bigint NOT NULL,
    title text NOT NULL,
    body text NOT NULL,
    is_read boolean DEFAULT false NOT NULL,
    is_deleted boolean DEFAULT false NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    from_ip_addr inet NOT NULL,
    key character varying DEFAULT ''::character varying NOT NULL,
    respond_to_id bigint,
    is_spam boolean DEFAULT false NOT NULL
);


--
-- Name: dmails_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.dmails_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: dmails_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.dmails_id_seq OWNED BY public.dmails.id;


--
-- Name: dtext_links; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.dtext_links (
    id bigint NOT NULL,
    model_type character varying NOT NULL,
    model_id bigint NOT NULL,
    link_type integer NOT NULL,
    link_target character varying NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: dtext_links_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.dtext_links_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: dtext_links_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.dtext_links_id_seq OWNED BY public.dtext_links.id;


--
-- Name: edit_histories; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.edit_histories (
    id bigint NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    body text NOT NULL,
    subject text,
    versionable_type character varying(100) NOT NULL,
    versionable_id bigint NOT NULL,
    version integer NOT NULL,
    updater_ip_addr inet NOT NULL,
    updater_id bigint NOT NULL,
    edit_type text DEFAULT 'original'::text NOT NULL,
    extra_data jsonb DEFAULT '{}'::jsonb NOT NULL
);


--
-- Name: edit_histories_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.edit_histories_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: edit_histories_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.edit_histories_id_seq OWNED BY public.edit_histories.id;


--
-- Name: email_blacklists; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.email_blacklists (
    id bigint NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    domain character varying NOT NULL,
    creator_id bigint NOT NULL,
    reason character varying NOT NULL,
    creator_ip_addr inet NOT NULL
);


--
-- Name: email_blacklists_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.email_blacklists_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: email_blacklists_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.email_blacklists_id_seq OWNED BY public.email_blacklists.id;


--
-- Name: exception_logs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.exception_logs (
    id bigint NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    class_name character varying NOT NULL,
    ip_addr inet NOT NULL,
    version character varying NOT NULL,
    extra_params text DEFAULT '{}'::text NOT NULL,
    message text NOT NULL,
    trace text NOT NULL,
    code uuid NOT NULL,
    user_id bigint
);


--
-- Name: exception_logs_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.exception_logs_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: exception_logs_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.exception_logs_id_seq OWNED BY public.exception_logs.id;


--
-- Name: favorites; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.favorites (
    id bigint NOT NULL,
    user_id bigint NOT NULL,
    post_id bigint NOT NULL,
    created_at timestamp without time zone DEFAULT now() NOT NULL
);


--
-- Name: favorites_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.favorites_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: favorites_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.favorites_id_seq OWNED BY public.favorites.id;


--
-- Name: fixes; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.fixes (
    id integer NOT NULL,
    index integer
);


--
-- Name: forum_categories; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.forum_categories (
    id bigint NOT NULL,
    name character varying NOT NULL,
    "order" integer NOT NULL,
    can_view integer DEFAULT 0 NOT NULL,
    can_create integer DEFAULT 10 NOT NULL,
    description text DEFAULT ''::text NOT NULL,
    topic_count integer DEFAULT 0 NOT NULL,
    post_count integer DEFAULT 0 NOT NULL,
    creator_id bigint NOT NULL,
    creator_ip_addr inet NOT NULL,
    updater_id bigint NOT NULL,
    updater_ip_addr inet NOT NULL
);


--
-- Name: forum_categories_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.forum_categories_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: forum_categories_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.forum_categories_id_seq OWNED BY public.forum_categories.id;


--
-- Name: forum_category_visits; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.forum_category_visits (
    id bigint NOT NULL,
    user_id bigint NOT NULL,
    forum_category_id bigint NOT NULL,
    last_read_at timestamp(6) without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);


--
-- Name: forum_category_visits_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.forum_category_visits_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: forum_category_visits_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.forum_category_visits_id_seq OWNED BY public.forum_category_visits.id;


--
-- Name: forum_post_votes; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.forum_post_votes (
    id bigint NOT NULL,
    forum_post_id bigint NOT NULL,
    user_id bigint NOT NULL,
    score integer NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    user_ip_addr inet NOT NULL
);


--
-- Name: forum_post_votes_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.forum_post_votes_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: forum_post_votes_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.forum_post_votes_id_seq OWNED BY public.forum_post_votes.id;


--
-- Name: forum_posts; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.forum_posts (
    id bigint NOT NULL,
    topic_id bigint NOT NULL,
    creator_id bigint NOT NULL,
    updater_id bigint NOT NULL,
    body text NOT NULL,
    is_hidden boolean DEFAULT false NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    creator_ip_addr inet NOT NULL,
    warning_type integer,
    warning_user_id bigint,
    tag_change_request_id bigint,
    tag_change_request_type character varying,
    notified_mentions bigint[] DEFAULT '{}'::bigint[] NOT NULL,
    is_spam boolean DEFAULT false NOT NULL,
    original_topic_id bigint,
    merged_at timestamp(6) without time zone,
    allow_voting boolean DEFAULT false NOT NULL,
    total_score integer DEFAULT 0 NOT NULL,
    percentage_score numeric DEFAULT 0.0 NOT NULL,
    total_votes integer DEFAULT 0 NOT NULL,
    up_votes integer DEFAULT 0 NOT NULL,
    down_votes integer DEFAULT 0 NOT NULL,
    meh_votes integer DEFAULT 0 NOT NULL,
    updater_ip_addr inet NOT NULL
);


--
-- Name: forum_posts_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.forum_posts_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: forum_posts_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.forum_posts_id_seq OWNED BY public.forum_posts.id;


--
-- Name: forum_topic_statuses; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.forum_topic_statuses (
    id bigint NOT NULL,
    user_id bigint NOT NULL,
    forum_topic_id bigint NOT NULL,
    subscription_last_read_at timestamp(6) without time zone,
    subscription boolean DEFAULT false NOT NULL,
    mute boolean DEFAULT false NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: forum_topic_statuses_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.forum_topic_statuses_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: forum_topic_statuses_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.forum_topic_statuses_id_seq OWNED BY public.forum_topic_statuses.id;


--
-- Name: forum_topics; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.forum_topics (
    id bigint NOT NULL,
    creator_id bigint NOT NULL,
    updater_id bigint NOT NULL,
    title character varying NOT NULL,
    response_count integer DEFAULT 0 NOT NULL,
    is_sticky boolean DEFAULT false NOT NULL,
    is_locked boolean DEFAULT false NOT NULL,
    is_hidden boolean DEFAULT false NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    category_id bigint DEFAULT 0 NOT NULL,
    creator_ip_addr inet NOT NULL,
    last_post_created_at timestamp(6) without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    merge_target_id bigint,
    merged_at timestamp(6) without time zone,
    updater_ip_addr inet NOT NULL
);


--
-- Name: forum_topics_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.forum_topics_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: forum_topics_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.forum_topics_id_seq OWNED BY public.forum_topics.id;


--
-- Name: good_job_batches; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.good_job_batches (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    description text,
    serialized_properties jsonb,
    on_finish text,
    on_success text,
    on_discard text,
    callback_queue_name text,
    callback_priority integer,
    enqueued_at timestamp(6) without time zone,
    discarded_at timestamp(6) without time zone,
    finished_at timestamp(6) without time zone,
    jobs_finished_at timestamp(6) without time zone
);


--
-- Name: good_job_executions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.good_job_executions (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    active_job_id uuid NOT NULL,
    job_class text,
    queue_name text,
    serialized_params jsonb,
    scheduled_at timestamp(6) without time zone,
    finished_at timestamp(6) without time zone,
    error text,
    error_event smallint,
    error_backtrace text[],
    process_id uuid,
    duration interval
);


--
-- Name: good_job_processes; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.good_job_processes (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    state jsonb,
    lock_type smallint
);


--
-- Name: good_job_settings; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.good_job_settings (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    key text,
    value jsonb
);


--
-- Name: good_jobs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.good_jobs (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    queue_name text,
    priority integer,
    serialized_params jsonb,
    scheduled_at timestamp(6) without time zone,
    performed_at timestamp(6) without time zone,
    finished_at timestamp(6) without time zone,
    error text,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    active_job_id uuid,
    concurrency_key text,
    cron_key text,
    retried_good_job_id uuid,
    cron_at timestamp(6) without time zone,
    batch_id uuid,
    batch_callback_id uuid,
    is_discrete boolean,
    executions_count integer,
    job_class text,
    error_event smallint,
    labels text[],
    locked_by_id uuid,
    locked_at timestamp(6) without time zone,
    lock_type smallint
);


--
-- Name: help_pages; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.help_pages (
    id bigint NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    name character varying NOT NULL,
    related character varying DEFAULT ''::character varying NOT NULL,
    title character varying DEFAULT ''::character varying NOT NULL,
    wiki_page_id bigint NOT NULL,
    creator_id bigint NOT NULL,
    creator_ip_addr inet NOT NULL,
    updater_id bigint NOT NULL,
    updater_ip_addr inet NOT NULL
);


--
-- Name: help_pages_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.help_pages_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: help_pages_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.help_pages_id_seq OWNED BY public.help_pages.id;


--
-- Name: ip_bans; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ip_bans (
    id bigint NOT NULL,
    creator_id bigint NOT NULL,
    ip_addr inet NOT NULL,
    reason text NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    creator_ip_addr inet NOT NULL
);


--
-- Name: ip_bans_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.ip_bans_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: ip_bans_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.ip_bans_id_seq OWNED BY public.ip_bans.id;


--
-- Name: linked_accounts; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.linked_accounts (
    id bigint NOT NULL,
    user_id bigint NOT NULL,
    provider character varying NOT NULL,
    uid character varying NOT NULL,
    display_name character varying,
    data jsonb DEFAULT '{}'::jsonb NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: linked_accounts_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.linked_accounts_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: linked_accounts_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.linked_accounts_id_seq OWNED BY public.linked_accounts.id;


--
-- Name: mascot_media_assets; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.mascot_media_assets (
    id bigint NOT NULL,
    creator_id bigint NOT NULL,
    media_metadata_id bigint NOT NULL,
    creator_ip_addr inet NOT NULL,
    checksum character varying(32),
    md5 character varying(32),
    file_ext character varying(4),
    is_animated_png boolean,
    is_animated_gif boolean,
    file_size integer,
    image_width integer,
    image_height integer,
    duration numeric,
    framecount integer,
    pixel_hash character varying(32),
    status character varying DEFAULT 'pending'::character varying NOT NULL,
    status_message character varying,
    last_chunk_id integer DEFAULT 0 NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    is_animated_webp boolean
);


--
-- Name: mascot_media_assets_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.mascot_media_assets_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: mascot_media_assets_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.mascot_media_assets_id_seq OWNED BY public.mascot_media_assets.id;


--
-- Name: mascots; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.mascots (
    id bigint NOT NULL,
    creator_id bigint NOT NULL,
    display_name character varying NOT NULL,
    background_color character varying NOT NULL,
    artist_url character varying NOT NULL,
    artist_name character varying NOT NULL,
    active boolean DEFAULT true NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    available_on character varying[] DEFAULT '{}'::character varying[] NOT NULL,
    hide_anonymous boolean DEFAULT false NOT NULL,
    mascot_media_asset_id bigint,
    creator_ip_addr inet NOT NULL,
    updater_id bigint NOT NULL,
    updater_ip_addr inet NOT NULL
);


--
-- Name: mascots_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.mascots_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: mascots_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.mascots_id_seq OWNED BY public.mascots.id;


--
-- Name: media_metadata; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.media_metadata (
    id bigint NOT NULL,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: media_metadata_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.media_metadata_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: media_metadata_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.media_metadata_id_seq OWNED BY public.media_metadata.id;


--
-- Name: mod_actions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.mod_actions (
    id bigint NOT NULL,
    creator_id bigint NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    action text NOT NULL,
    "values" json DEFAULT '{}'::json NOT NULL,
    subject_id bigint,
    subject_type character varying,
    creator_ip_addr inet NOT NULL
);


--
-- Name: mod_actions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.mod_actions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: mod_actions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.mod_actions_id_seq OWNED BY public.mod_actions.id;


--
-- Name: news_updates; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.news_updates (
    id bigint NOT NULL,
    message text NOT NULL,
    creator_id bigint NOT NULL,
    updater_id bigint NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    creator_ip_addr inet NOT NULL,
    updater_ip_addr inet NOT NULL
);


--
-- Name: news_updates_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.news_updates_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: news_updates_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.news_updates_id_seq OWNED BY public.news_updates.id;


--
-- Name: note_versions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.note_versions (
    id bigint NOT NULL,
    note_id bigint NOT NULL,
    post_id bigint NOT NULL,
    updater_id bigint NOT NULL,
    updater_ip_addr inet NOT NULL,
    x integer NOT NULL,
    y integer NOT NULL,
    width integer NOT NULL,
    height integer NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    body text NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    version integer NOT NULL
);


--
-- Name: note_versions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.note_versions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: note_versions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.note_versions_id_seq OWNED BY public.note_versions.id;


--
-- Name: notes; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.notes (
    id bigint NOT NULL,
    creator_id bigint NOT NULL,
    post_id bigint NOT NULL,
    x integer NOT NULL,
    y integer NOT NULL,
    width integer NOT NULL,
    height integer NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    body text NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    version integer DEFAULT 0 NOT NULL,
    creator_ip_addr inet NOT NULL
);


--
-- Name: notes_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.notes_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: notes_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.notes_id_seq OWNED BY public.notes.id;


--
-- Name: notifications; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.notifications (
    id bigint NOT NULL,
    user_id bigint NOT NULL,
    category integer DEFAULT 0 NOT NULL,
    data json DEFAULT '{}'::json NOT NULL,
    is_read boolean DEFAULT false NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: notifications_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.notifications_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: notifications_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.notifications_id_seq OWNED BY public.notifications.id;


--
-- Name: pool_versions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.pool_versions (
    id bigint NOT NULL,
    pool_id bigint NOT NULL,
    post_ids bigint[] DEFAULT '{}'::bigint[] NOT NULL,
    added_post_ids bigint[] DEFAULT '{}'::bigint[] NOT NULL,
    removed_post_ids bigint[] DEFAULT '{}'::bigint[] NOT NULL,
    updater_id bigint NOT NULL,
    updater_ip_addr inet NOT NULL,
    description text NOT NULL,
    description_changed boolean DEFAULT false NOT NULL,
    name text DEFAULT ''::text NOT NULL,
    name_changed boolean DEFAULT false NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    is_ongoing boolean DEFAULT true NOT NULL,
    version integer DEFAULT 1 NOT NULL,
    is_ongoing_changed boolean DEFAULT false NOT NULL,
    category character varying NOT NULL,
    category_changed boolean DEFAULT false NOT NULL
);


--
-- Name: pool_versions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.pool_versions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: pool_versions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.pool_versions_id_seq OWNED BY public.pool_versions.id;


--
-- Name: pools; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.pools (
    id bigint NOT NULL,
    name character varying NOT NULL,
    creator_id bigint NOT NULL,
    description text DEFAULT ''::text NOT NULL,
    is_ongoing boolean DEFAULT true NOT NULL,
    post_ids bigint[] DEFAULT '{}'::bigint[] NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    artist_names character varying[] DEFAULT '{}'::character varying[] NOT NULL,
    cover_post_id bigint,
    creator_ip_addr inet NOT NULL,
    category character varying DEFAULT 'series'::character varying NOT NULL
);


--
-- Name: pools_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.pools_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: pools_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.pools_id_seq OWNED BY public.pools.id;


--
-- Name: post_appeals; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.post_appeals (
    id bigint NOT NULL,
    post_id bigint NOT NULL,
    creator_id bigint NOT NULL,
    creator_ip_addr inet NOT NULL,
    reason character varying DEFAULT ''::character varying NOT NULL,
    status integer DEFAULT 0 NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    updater_id bigint NOT NULL,
    updater_ip_addr inet NOT NULL
);


--
-- Name: post_appeals_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.post_appeals_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: post_appeals_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.post_appeals_id_seq OWNED BY public.post_appeals.id;


--
-- Name: post_approvals; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.post_approvals (
    id bigint NOT NULL,
    user_id bigint NOT NULL,
    post_id bigint NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    user_ip_addr inet NOT NULL
);


--
-- Name: post_approvals_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.post_approvals_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: post_approvals_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.post_approvals_id_seq OWNED BY public.post_approvals.id;


--
-- Name: post_deletion_reasons; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.post_deletion_reasons (
    id bigint NOT NULL,
    creator_id bigint NOT NULL,
    reason character varying NOT NULL,
    title character varying,
    prompt character varying,
    "order" integer NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    creator_ip_addr inet NOT NULL,
    updater_id bigint NOT NULL,
    updater_ip_addr inet NOT NULL
);


--
-- Name: post_deletion_reasons_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.post_deletion_reasons_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: post_deletion_reasons_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.post_deletion_reasons_id_seq OWNED BY public.post_deletion_reasons.id;


--
-- Name: post_disapprovals; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.post_disapprovals (
    id bigint NOT NULL,
    user_id bigint NOT NULL,
    post_id bigint NOT NULL,
    reason character varying NOT NULL,
    message text DEFAULT ''::text NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    user_ip_addr inet NOT NULL
);


--
-- Name: post_disapprovals_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.post_disapprovals_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: post_disapprovals_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.post_disapprovals_id_seq OWNED BY public.post_disapprovals.id;


--
-- Name: post_events; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.post_events (
    id bigint NOT NULL,
    creator_id bigint NOT NULL,
    post_id bigint NOT NULL,
    action integer NOT NULL,
    extra_data jsonb NOT NULL,
    created_at timestamp without time zone NOT NULL,
    creator_ip_addr inet NOT NULL
);


--
-- Name: post_events_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.post_events_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: post_events_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.post_events_id_seq OWNED BY public.post_events.id;


--
-- Name: post_flags; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.post_flags (
    id bigint NOT NULL,
    post_id bigint NOT NULL,
    creator_id bigint NOT NULL,
    creator_ip_addr inet NOT NULL,
    reason text NOT NULL,
    is_resolved boolean DEFAULT false NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    is_deletion boolean DEFAULT false NOT NULL,
    note character varying
);


--
-- Name: post_flags_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.post_flags_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: post_flags_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.post_flags_id_seq OWNED BY public.post_flags.id;


--
-- Name: post_replacement_media_assets; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.post_replacement_media_assets (
    id bigint NOT NULL,
    creator_id bigint NOT NULL,
    media_metadata_id bigint NOT NULL,
    creator_ip_addr inet NOT NULL,
    checksum character varying(32),
    md5 character varying(32),
    file_ext character varying(4),
    is_animated_png boolean,
    is_animated_gif boolean,
    file_size integer,
    image_width integer,
    image_height integer,
    duration numeric,
    framecount integer,
    pixel_hash character varying(32),
    status character varying DEFAULT 'pending'::character varying NOT NULL,
    status_message character varying,
    storage_id character varying NOT NULL,
    last_chunk_id integer DEFAULT 0 NOT NULL,
    generated_variants jsonb DEFAULT '[]'::jsonb NOT NULL,
    variants_data jsonb DEFAULT '[]'::jsonb NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    is_animated_webp boolean
);


--
-- Name: post_replacement_media_assets_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.post_replacement_media_assets_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: post_replacement_media_assets_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.post_replacement_media_assets_id_seq OWNED BY public.post_replacement_media_assets.id;


--
-- Name: post_replacement_rejection_reasons; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.post_replacement_rejection_reasons (
    id bigint NOT NULL,
    creator_id bigint NOT NULL,
    reason character varying NOT NULL,
    "order" integer NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    creator_ip_addr inet NOT NULL,
    updater_id bigint NOT NULL,
    updater_ip_addr inet NOT NULL
);


--
-- Name: post_replacement_rejection_reasons_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.post_replacement_rejection_reasons_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: post_replacement_rejection_reasons_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.post_replacement_rejection_reasons_id_seq OWNED BY public.post_replacement_rejection_reasons.id;


--
-- Name: post_replacements; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.post_replacements (
    id bigint NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    post_id bigint NOT NULL,
    creator_id bigint NOT NULL,
    creator_ip_addr inet NOT NULL,
    approver_id bigint,
    source character varying DEFAULT ''::character varying NOT NULL,
    file_name character varying,
    status character varying DEFAULT 'uploading'::character varying NOT NULL,
    reason character varying NOT NULL,
    uploader_id_on_approve bigint,
    penalize_uploader_on_approve boolean,
    rejector_id bigint,
    rejection_reason character varying DEFAULT ''::character varying NOT NULL,
    previous_details jsonb,
    post_replacement_media_asset_id bigint,
    sequence_number integer NOT NULL
);


--
-- Name: post_replacements_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.post_replacements_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: post_replacements_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.post_replacements_id_seq OWNED BY public.post_replacements.id;


--
-- Name: post_set_maintainers; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.post_set_maintainers (
    id bigint NOT NULL,
    post_set_id bigint NOT NULL,
    user_id bigint NOT NULL,
    status character varying DEFAULT 'pending'::character varying NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: post_set_maintainers_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.post_set_maintainers_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: post_set_maintainers_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.post_set_maintainers_id_seq OWNED BY public.post_set_maintainers.id;


--
-- Name: post_sets; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.post_sets (
    id bigint NOT NULL,
    name character varying NOT NULL,
    shortname character varying NOT NULL,
    description text DEFAULT ''::text NOT NULL,
    is_public boolean DEFAULT false NOT NULL,
    transfer_on_delete boolean DEFAULT false NOT NULL,
    creator_id bigint NOT NULL,
    creator_ip_addr inet NOT NULL,
    post_ids bigint[] DEFAULT '{}'::bigint[] NOT NULL,
    post_count integer DEFAULT 0 NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    updater_id bigint NOT NULL,
    updater_ip_addr inet NOT NULL
);


--
-- Name: post_sets_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.post_sets_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: post_sets_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.post_sets_id_seq OWNED BY public.post_sets.id;


--
-- Name: post_versions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.post_versions (
    id bigint NOT NULL,
    post_id bigint NOT NULL,
    tags text NOT NULL,
    added_tags text[] DEFAULT '{}'::text[] NOT NULL,
    removed_tags text[] DEFAULT '{}'::text[] NOT NULL,
    locked_tags text DEFAULT ''::text NOT NULL,
    added_locked_tags text[] DEFAULT '{}'::text[] NOT NULL,
    removed_locked_tags text[] DEFAULT '{}'::text[] NOT NULL,
    updater_id bigint NOT NULL,
    updater_ip_addr inet NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    rating character varying(1) NOT NULL,
    rating_changed boolean DEFAULT false NOT NULL,
    parent_id bigint,
    parent_changed boolean DEFAULT false NOT NULL,
    source text DEFAULT ''::text NOT NULL,
    source_changed boolean DEFAULT false NOT NULL,
    description text DEFAULT ''::text NOT NULL,
    description_changed boolean DEFAULT false NOT NULL,
    version integer DEFAULT 1 NOT NULL,
    reason character varying,
    original_tags text DEFAULT ''::text NOT NULL
);


--
-- Name: post_versions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.post_versions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: post_versions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.post_versions_id_seq OWNED BY public.post_versions.id;


--
-- Name: post_votes; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.post_votes (
    id bigint NOT NULL,
    post_id bigint NOT NULL,
    user_id bigint NOT NULL,
    score integer NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    user_ip_addr inet NOT NULL,
    is_locked boolean DEFAULT false NOT NULL
);


--
-- Name: post_votes_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.post_votes_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: post_votes_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.post_votes_id_seq OWNED BY public.post_votes.id;


--
-- Name: posts; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.posts (
    id bigint NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone,
    up_score integer DEFAULT 0 NOT NULL,
    down_score integer DEFAULT 0 NOT NULL,
    score integer DEFAULT 0 NOT NULL,
    source character varying NOT NULL,
    rating character(1) DEFAULT 'q'::bpchar NOT NULL,
    is_note_locked boolean DEFAULT false NOT NULL,
    is_rating_locked boolean DEFAULT false NOT NULL,
    is_status_locked boolean DEFAULT false NOT NULL,
    is_pending boolean DEFAULT false NOT NULL,
    is_flagged boolean DEFAULT false NOT NULL,
    is_deleted boolean DEFAULT false NOT NULL,
    uploader_id bigint NOT NULL,
    uploader_ip_addr inet NOT NULL,
    approver_id bigint,
    fav_string text DEFAULT ''::text NOT NULL,
    pool_string text DEFAULT ''::text NOT NULL,
    last_noted_at timestamp without time zone,
    last_comment_bumped_at timestamp without time zone,
    fav_count integer DEFAULT 0 NOT NULL,
    tag_string text DEFAULT ''::text NOT NULL,
    tag_count integer DEFAULT 0 NOT NULL,
    tag_count_general integer DEFAULT 0 NOT NULL,
    tag_count_artist integer DEFAULT 0 NOT NULL,
    tag_count_character integer DEFAULT 0 NOT NULL,
    tag_count_copyright integer DEFAULT 0 NOT NULL,
    parent_id bigint,
    has_children boolean DEFAULT false NOT NULL,
    last_commented_at timestamp without time zone,
    has_active_children boolean DEFAULT false NOT NULL,
    bit_flags bigint DEFAULT 0 NOT NULL,
    tag_count_meta integer DEFAULT 0 NOT NULL,
    locked_tags text DEFAULT ''::text NOT NULL,
    tag_count_species integer DEFAULT 0 NOT NULL,
    tag_count_invalid integer DEFAULT 0 NOT NULL,
    description text DEFAULT ''::text NOT NULL,
    comment_count integer DEFAULT 0 NOT NULL,
    change_seq bigint NOT NULL,
    tag_count_lore integer DEFAULT 0 NOT NULL,
    bg_color character varying,
    is_comment_disabled boolean DEFAULT false NOT NULL,
    original_tag_string text DEFAULT ''::text NOT NULL,
    is_comment_locked boolean DEFAULT false NOT NULL,
    qtags character varying[] DEFAULT '{}'::character varying[] NOT NULL,
    upload_url character varying,
    vote_string character varying DEFAULT ''::character varying NOT NULL,
    tag_count_gender integer DEFAULT 0 NOT NULL,
    thumbnail_frame integer,
    tag_count_contributor integer DEFAULT 0 NOT NULL,
    min_edit_level integer DEFAULT 10 NOT NULL,
    typed_tag_string character varying DEFAULT ''::character varying NOT NULL,
    upload_media_asset_id bigint,
    updater_id bigint NOT NULL,
    updater_ip_addr inet NOT NULL,
    tag_count_important integer DEFAULT 0 NOT NULL,
    is_appealed boolean DEFAULT false NOT NULL,
    is_unlisted boolean DEFAULT false NOT NULL,
    is_in_progress boolean DEFAULT false NOT NULL
);


--
-- Name: posts_change_seq_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.posts_change_seq_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: posts_change_seq_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.posts_change_seq_seq OWNED BY public.posts.change_seq;


--
-- Name: posts_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.posts_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: posts_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.posts_id_seq OWNED BY public.posts.id;


--
-- Name: quick_rules; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.quick_rules (
    id bigint NOT NULL,
    rule_id bigint,
    reason character varying NOT NULL,
    header character varying,
    "order" integer NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    creator_id bigint NOT NULL,
    creator_ip_addr inet NOT NULL,
    updater_id bigint NOT NULL,
    updater_ip_addr inet NOT NULL
);


--
-- Name: quick_rules_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.quick_rules_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: quick_rules_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.quick_rules_id_seq OWNED BY public.quick_rules.id;


--
-- Name: rule_categories; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.rule_categories (
    id bigint NOT NULL,
    creator_id bigint NOT NULL,
    updater_id bigint NOT NULL,
    name character varying NOT NULL,
    "order" integer NOT NULL,
    anchor character varying NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    creator_ip_addr inet NOT NULL,
    updater_ip_addr inet NOT NULL
);


--
-- Name: rule_categories_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.rule_categories_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: rule_categories_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.rule_categories_id_seq OWNED BY public.rule_categories.id;


--
-- Name: rules; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.rules (
    id bigint NOT NULL,
    creator_id bigint NOT NULL,
    updater_id bigint NOT NULL,
    category_id bigint NOT NULL,
    name character varying NOT NULL,
    description text NOT NULL,
    "order" integer NOT NULL,
    anchor character varying NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    creator_ip_addr inet NOT NULL,
    updater_ip_addr inet NOT NULL
);


--
-- Name: rules_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.rules_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: rules_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.rules_id_seq OWNED BY public.rules.id;


--
-- Name: schema_migrations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.schema_migrations (
    version character varying NOT NULL
);


--
-- Name: staff_audit_logs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.staff_audit_logs (
    id bigint NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    user_id bigint NOT NULL,
    action character varying DEFAULT 'unknown_action'::character varying NOT NULL,
    "values" json DEFAULT '"{}"'::json NOT NULL,
    user_ip_addr inet NOT NULL
);


--
-- Name: staff_audit_logs_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.staff_audit_logs_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: staff_audit_logs_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.staff_audit_logs_id_seq OWNED BY public.staff_audit_logs.id;


--
-- Name: staff_notes; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.staff_notes (
    id bigint NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    user_id bigint NOT NULL,
    creator_id bigint NOT NULL,
    body character varying NOT NULL,
    is_deleted boolean DEFAULT false NOT NULL,
    updater_id bigint NOT NULL,
    creator_ip_addr inet NOT NULL,
    updater_ip_addr inet NOT NULL
);


--
-- Name: staff_notes_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.staff_notes_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: staff_notes_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.staff_notes_id_seq OWNED BY public.staff_notes.id;


--
-- Name: tag_aliases; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.tag_aliases (
    id bigint NOT NULL,
    antecedent_name character varying NOT NULL,
    consequent_name character varying NOT NULL,
    creator_id bigint NOT NULL,
    creator_ip_addr inet NOT NULL,
    status text DEFAULT 'pending'::text NOT NULL,
    created_at timestamp without time zone,
    updated_at timestamp without time zone,
    post_count integer DEFAULT 0 NOT NULL,
    approver_id bigint,
    forum_post_id bigint,
    forum_topic_id bigint,
    reason text DEFAULT ''::text NOT NULL,
    undo_data jsonb DEFAULT '[]'::jsonb NOT NULL,
    updater_id bigint NOT NULL,
    updater_ip_addr inet NOT NULL
);


--
-- Name: tag_aliases_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.tag_aliases_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: tag_aliases_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.tag_aliases_id_seq OWNED BY public.tag_aliases.id;


--
-- Name: tag_followers; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.tag_followers (
    id bigint NOT NULL,
    tag_id bigint NOT NULL,
    user_id bigint NOT NULL,
    last_post_id bigint,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: tag_followers_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.tag_followers_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: tag_followers_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.tag_followers_id_seq OWNED BY public.tag_followers.id;


--
-- Name: tag_implications; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.tag_implications (
    id bigint NOT NULL,
    antecedent_name character varying NOT NULL,
    consequent_name character varying NOT NULL,
    creator_id bigint NOT NULL,
    creator_ip_addr inet NOT NULL,
    status text DEFAULT 'pending'::text NOT NULL,
    created_at timestamp without time zone,
    updated_at timestamp without time zone,
    approver_id bigint,
    forum_post_id bigint,
    forum_topic_id bigint,
    descendant_names text[] DEFAULT '{}'::text[],
    reason text DEFAULT ''::text NOT NULL,
    undo_data jsonb DEFAULT '[]'::jsonb NOT NULL,
    updater_id bigint NOT NULL,
    updater_ip_addr inet NOT NULL
);


--
-- Name: tag_implications_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.tag_implications_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: tag_implications_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.tag_implications_id_seq OWNED BY public.tag_implications.id;


--
-- Name: tag_rel_undos; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.tag_rel_undos (
    id bigint NOT NULL,
    tag_rel_type character varying,
    tag_rel_id bigint,
    undo_data json,
    applied boolean DEFAULT false,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: tag_rel_undos_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.tag_rel_undos_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: tag_rel_undos_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.tag_rel_undos_id_seq OWNED BY public.tag_rel_undos.id;


--
-- Name: tag_versions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.tag_versions (
    id bigint NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    category integer NOT NULL,
    is_locked boolean NOT NULL,
    tag_id bigint NOT NULL,
    updater_id bigint NOT NULL,
    reason character varying DEFAULT ''::character varying NOT NULL,
    is_deprecated boolean NOT NULL,
    updater_ip_addr inet NOT NULL
);


--
-- Name: tag_versions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.tag_versions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: tag_versions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.tag_versions_id_seq OWNED BY public.tag_versions.id;


--
-- Name: tags; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.tags (
    id bigint NOT NULL,
    name character varying NOT NULL,
    post_count integer DEFAULT 0 NOT NULL,
    category smallint DEFAULT 0 NOT NULL,
    related_tags text,
    related_tags_updated_at timestamp without time zone,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    is_locked boolean DEFAULT false NOT NULL,
    follower_count integer DEFAULT 0 NOT NULL,
    is_deprecated boolean DEFAULT false NOT NULL,
    creator_id bigint NOT NULL,
    creator_ip_addr inet NOT NULL
);


--
-- Name: tags_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.tags_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: tags_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.tags_id_seq OWNED BY public.tags.id;


--
-- Name: takedowns; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.takedowns (
    id bigint NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    creator_id bigint,
    creator_ip_addr inet NOT NULL,
    approver_id bigint,
    status character varying DEFAULT 'pending'::character varying NOT NULL,
    vericode character varying NOT NULL,
    source character varying DEFAULT ''::character varying NOT NULL,
    email character varying NOT NULL,
    reason text DEFAULT ''::text NOT NULL,
    reason_hidden boolean DEFAULT false NOT NULL,
    notes text DEFAULT 'none'::text NOT NULL,
    instructions text DEFAULT ''::text NOT NULL,
    post_ids text DEFAULT ''::text NOT NULL,
    del_post_ids text DEFAULT ''::text NOT NULL,
    post_count integer DEFAULT 0 NOT NULL,
    updater_id bigint,
    updater_ip_addr inet
);


--
-- Name: takedowns_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.takedowns_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: takedowns_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.takedowns_id_seq OWNED BY public.takedowns.id;


--
-- Name: tickets; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.tickets (
    id bigint NOT NULL,
    creator_id bigint NOT NULL,
    creator_ip_addr inet NOT NULL,
    status character varying DEFAULT 'pending'::character varying NOT NULL,
    reason character varying,
    response character varying DEFAULT ''::character varying NOT NULL,
    handler_id bigint,
    claimant_id bigint,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    accused_id bigint,
    model_type character varying NOT NULL,
    model_id bigint NOT NULL,
    report_type character varying DEFAULT 'report'::character varying NOT NULL,
    handler_ip_addr inet
);


--
-- Name: tickets_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.tickets_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: tickets_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.tickets_id_seq OWNED BY public.tickets.id;


--
-- Name: upload_media_assets; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.upload_media_assets (
    id bigint NOT NULL,
    creator_id bigint NOT NULL,
    media_metadata_id bigint NOT NULL,
    creator_ip_addr inet NOT NULL,
    checksum character varying(32),
    md5 character varying(32),
    file_ext character varying(4),
    is_animated_png boolean,
    is_animated_gif boolean,
    file_size integer,
    image_width integer,
    image_height integer,
    duration numeric,
    framecount integer,
    pixel_hash character varying(32),
    last_chunk_id integer DEFAULT 0 NOT NULL,
    status character varying DEFAULT 'pending'::character varying NOT NULL,
    status_message character varying,
    generated_variants jsonb DEFAULT '[]'::jsonb NOT NULL,
    variants_data jsonb DEFAULT '[]'::jsonb NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    is_animated_webp boolean
);


--
-- Name: upload_media_assets_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.upload_media_assets_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: upload_media_assets_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.upload_media_assets_id_seq OWNED BY public.upload_media_assets.id;


--
-- Name: upload_whitelists; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.upload_whitelists (
    id bigint NOT NULL,
    pattern character varying NOT NULL,
    note character varying,
    reason character varying,
    allowed boolean DEFAULT true NOT NULL,
    hidden boolean DEFAULT false NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    creator_id bigint NOT NULL,
    creator_ip_addr inet NOT NULL,
    updater_id bigint NOT NULL,
    updater_ip_addr inet NOT NULL
);


--
-- Name: upload_whitelists_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.upload_whitelists_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: upload_whitelists_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.upload_whitelists_id_seq OWNED BY public.upload_whitelists.id;


--
-- Name: uploads; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.uploads (
    id bigint NOT NULL,
    source text,
    rating character(1) NOT NULL,
    uploader_id bigint NOT NULL,
    uploader_ip_addr inet NOT NULL,
    tag_string text NOT NULL,
    backtrace text,
    post_id bigint,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    parent_id bigint,
    description text DEFAULT ''::text NOT NULL,
    direct_url character varying,
    upload_media_asset_id bigint
);


--
-- Name: uploads_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.uploads_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: uploads_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.uploads_id_seq OWNED BY public.uploads.id;


--
-- Name: user_approvals; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.user_approvals (
    id bigint NOT NULL,
    updater_id bigint,
    user_id bigint NOT NULL,
    status character varying DEFAULT 'pending'::character varying NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    updater_ip_addr inet
);


--
-- Name: user_approvals_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.user_approvals_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: user_approvals_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.user_approvals_id_seq OWNED BY public.user_approvals.id;


--
-- Name: user_blocks; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.user_blocks (
    id bigint NOT NULL,
    user_id bigint NOT NULL,
    target_id bigint NOT NULL,
    hide_comments boolean DEFAULT false NOT NULL,
    hide_forum_topics boolean DEFAULT false NOT NULL,
    hide_forum_posts boolean DEFAULT false NOT NULL,
    disable_messages boolean DEFAULT false NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    suppress_mentions boolean DEFAULT false NOT NULL
);


--
-- Name: user_blocks_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.user_blocks_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: user_blocks_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.user_blocks_id_seq OWNED BY public.user_blocks.id;


--
-- Name: user_events; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.user_events (
    id bigint NOT NULL,
    user_id bigint NOT NULL,
    user_session_id bigint NOT NULL,
    category integer NOT NULL,
    user_ip_addr inet NOT NULL,
    session_id character varying NOT NULL,
    user_agent character varying,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: user_events_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.user_events_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: user_events_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.user_events_id_seq OWNED BY public.user_events.id;


--
-- Name: user_feedbacks; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.user_feedbacks (
    id bigint NOT NULL,
    user_id bigint NOT NULL,
    creator_id bigint NOT NULL,
    category character varying NOT NULL,
    body text NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    creator_ip_addr inet NOT NULL,
    updater_id bigint NOT NULL,
    is_deleted boolean DEFAULT false NOT NULL,
    updater_ip_addr inet NOT NULL
);


--
-- Name: user_feedbacks_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.user_feedbacks_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: user_feedbacks_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.user_feedbacks_id_seq OWNED BY public.user_feedbacks.id;


--
-- Name: user_name_change_requests; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.user_name_change_requests (
    id bigint NOT NULL,
    status character varying DEFAULT 'pending'::character varying NOT NULL,
    user_id bigint NOT NULL,
    approver_id bigint,
    original_name character varying NOT NULL,
    desired_name character varying NOT NULL,
    change_reason text DEFAULT ''::text NOT NULL,
    rejection_reason text,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    creator_id bigint NOT NULL,
    creator_ip_addr inet NOT NULL
);


--
-- Name: user_name_change_requests_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.user_name_change_requests_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: user_name_change_requests_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.user_name_change_requests_id_seq OWNED BY public.user_name_change_requests.id;


--
-- Name: user_password_reset_nonces; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.user_password_reset_nonces (
    id bigint NOT NULL,
    key character varying NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    user_id bigint NOT NULL
);


--
-- Name: user_password_reset_nonces_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.user_password_reset_nonces_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: user_password_reset_nonces_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.user_password_reset_nonces_id_seq OWNED BY public.user_password_reset_nonces.id;


--
-- Name: user_sessions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.user_sessions (
    id bigint NOT NULL,
    ip_addr inet NOT NULL,
    session_id character varying NOT NULL,
    user_agent character varying,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: user_sessions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.user_sessions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: user_sessions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.user_sessions_id_seq OWNED BY public.user_sessions.id;


--
-- Name: user_text_versions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.user_text_versions (
    id bigint NOT NULL,
    updater_id bigint NOT NULL,
    updater_ip_addr inet NOT NULL,
    user_id bigint NOT NULL,
    about_text character varying NOT NULL,
    artinfo_text character varying NOT NULL,
    blacklist_text character varying NOT NULL,
    version integer DEFAULT 1 NOT NULL,
    text_changes character varying[] DEFAULT '{}'::character varying[] NOT NULL,
    created_at timestamp(6) without time zone NOT NULL
);


--
-- Name: user_text_versions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.user_text_versions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: user_text_versions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.user_text_versions_id_seq OWNED BY public.user_text_versions.id;


--
-- Name: users; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.users (
    id bigint NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone,
    name character varying NOT NULL,
    password_hash character varying NOT NULL,
    email character varying,
    level integer DEFAULT 10 NOT NULL,
    base_upload_limit integer DEFAULT 10 NOT NULL,
    last_logged_in_at timestamp without time zone,
    last_forum_read_at timestamp without time zone,
    recent_tags text,
    comment_threshold integer DEFAULT '-2'::integer NOT NULL,
    default_image_size character varying DEFAULT 'large'::character varying NOT NULL,
    favorite_tags text,
    blacklisted_tags text DEFAULT ''::text,
    time_zone character varying DEFAULT 'Central Time (US & Canada)'::character varying NOT NULL,
    bcrypt_password_hash text,
    per_page integer DEFAULT 100 NOT NULL,
    custom_style text DEFAULT ''::text NOT NULL,
    bit_prefs bigint DEFAULT 0 NOT NULL,
    last_ip_addr inet,
    unread_dmail_count integer DEFAULT 0 NOT NULL,
    profile_about text DEFAULT ''::text NOT NULL,
    profile_artinfo text DEFAULT ''::text NOT NULL,
    avatar_id bigint,
    post_count integer DEFAULT 0 NOT NULL,
    post_deleted_count integer DEFAULT 0 NOT NULL,
    post_update_count integer DEFAULT 0 NOT NULL,
    post_flag_count integer DEFAULT 0 NOT NULL,
    favorite_count integer DEFAULT 0 NOT NULL,
    wiki_update_count integer DEFAULT 0 NOT NULL,
    note_update_count integer DEFAULT 0 NOT NULL,
    forum_post_count integer DEFAULT 0 NOT NULL,
    comment_count integer DEFAULT 0 NOT NULL,
    pool_update_count integer DEFAULT 0 NOT NULL,
    set_count integer DEFAULT 0 NOT NULL,
    artist_update_count integer DEFAULT 0 NOT NULL,
    own_post_replaced_count integer DEFAULT 0 NOT NULL,
    own_post_replaced_penalize_count integer DEFAULT 0 NOT NULL,
    post_replacement_rejected_count integer DEFAULT 0 NOT NULL,
    ticket_count integer DEFAULT 0 NOT NULL,
    title character varying,
    unread_notification_count integer DEFAULT 0 NOT NULL,
    followed_tag_count integer DEFAULT 0 NOT NULL,
    mfa_secret character varying,
    mfa_last_used_at timestamp(6) without time zone,
    backup_codes character varying[],
    post_appealed_count integer DEFAULT 0,
    upload_notifications character varying[] DEFAULT '{}'::character varying[] NOT NULL,
    post_vote_count integer DEFAULT 0 NOT NULL,
    comment_vote_count integer DEFAULT 0 NOT NULL,
    forum_post_vote_count integer DEFAULT 0 NOT NULL
);


--
-- Name: users_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.users_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: users_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.users_id_seq OWNED BY public.users.id;


--
-- Name: wiki_page_versions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.wiki_page_versions (
    id bigint NOT NULL,
    wiki_page_id bigint NOT NULL,
    updater_id bigint NOT NULL,
    updater_ip_addr inet NOT NULL,
    title character varying NOT NULL,
    body text NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    reason character varying,
    parent character varying,
    protection_level integer,
    merged_from_id bigint,
    merged_from_title character varying
);


--
-- Name: wiki_page_versions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.wiki_page_versions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: wiki_page_versions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.wiki_page_versions_id_seq OWNED BY public.wiki_page_versions.id;


--
-- Name: wiki_pages; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.wiki_pages (
    id bigint NOT NULL,
    creator_id bigint NOT NULL,
    title character varying NOT NULL,
    body text NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    updater_id bigint NOT NULL,
    parent character varying,
    protection_level integer,
    creator_ip_addr inet NOT NULL,
    updater_ip_addr inet NOT NULL
);


--
-- Name: wiki_pages_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.wiki_pages_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: wiki_pages_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.wiki_pages_id_seq OWNED BY public.wiki_pages.id;


--
-- Name: api_keys id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.api_keys ALTER COLUMN id SET DEFAULT nextval('public.api_keys_id_seq'::regclass);


--
-- Name: artist_urls id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.artist_urls ALTER COLUMN id SET DEFAULT nextval('public.artist_urls_id_seq'::regclass);


--
-- Name: artist_versions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.artist_versions ALTER COLUMN id SET DEFAULT nextval('public.artist_versions_id_seq'::regclass);


--
-- Name: artists id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.artists ALTER COLUMN id SET DEFAULT nextval('public.artists_id_seq'::regclass);


--
-- Name: avoid_posting_versions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.avoid_posting_versions ALTER COLUMN id SET DEFAULT nextval('public.avoid_posting_versions_id_seq'::regclass);


--
-- Name: avoid_postings id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.avoid_postings ALTER COLUMN id SET DEFAULT nextval('public.avoid_postings_id_seq'::regclass);


--
-- Name: bans id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.bans ALTER COLUMN id SET DEFAULT nextval('public.bans_id_seq'::regclass);


--
-- Name: bulk_update_request_imports id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.bulk_update_request_imports ALTER COLUMN id SET DEFAULT nextval('public.bulk_update_request_imports_id_seq'::regclass);


--
-- Name: bulk_update_request_versions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.bulk_update_request_versions ALTER COLUMN id SET DEFAULT nextval('public.bulk_update_request_versions_id_seq'::regclass);


--
-- Name: bulk_update_requests id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.bulk_update_requests ALTER COLUMN id SET DEFAULT nextval('public.bulk_update_requests_id_seq'::regclass);


--
-- Name: comment_votes id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.comment_votes ALTER COLUMN id SET DEFAULT nextval('public.comment_votes_id_seq'::regclass);


--
-- Name: comments id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.comments ALTER COLUMN id SET DEFAULT nextval('public.comments_id_seq'::regclass);


--
-- Name: db_exports id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.db_exports ALTER COLUMN id SET DEFAULT nextval('public.db_exports_id_seq'::regclass);


--
-- Name: destroyed_posts id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.destroyed_posts ALTER COLUMN id SET DEFAULT nextval('public.destroyed_posts_id_seq'::regclass);


--
-- Name: dmail_filters id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.dmail_filters ALTER COLUMN id SET DEFAULT nextval('public.dmail_filters_id_seq'::regclass);


--
-- Name: dmails id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.dmails ALTER COLUMN id SET DEFAULT nextval('public.dmails_id_seq'::regclass);


--
-- Name: dtext_links id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.dtext_links ALTER COLUMN id SET DEFAULT nextval('public.dtext_links_id_seq'::regclass);


--
-- Name: edit_histories id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.edit_histories ALTER COLUMN id SET DEFAULT nextval('public.edit_histories_id_seq'::regclass);


--
-- Name: email_blacklists id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.email_blacklists ALTER COLUMN id SET DEFAULT nextval('public.email_blacklists_id_seq'::regclass);


--
-- Name: exception_logs id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.exception_logs ALTER COLUMN id SET DEFAULT nextval('public.exception_logs_id_seq'::regclass);


--
-- Name: favorites id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.favorites ALTER COLUMN id SET DEFAULT nextval('public.favorites_id_seq'::regclass);


--
-- Name: forum_categories id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.forum_categories ALTER COLUMN id SET DEFAULT nextval('public.forum_categories_id_seq'::regclass);


--
-- Name: forum_category_visits id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.forum_category_visits ALTER COLUMN id SET DEFAULT nextval('public.forum_category_visits_id_seq'::regclass);


--
-- Name: forum_post_votes id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.forum_post_votes ALTER COLUMN id SET DEFAULT nextval('public.forum_post_votes_id_seq'::regclass);


--
-- Name: forum_posts id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.forum_posts ALTER COLUMN id SET DEFAULT nextval('public.forum_posts_id_seq'::regclass);


--
-- Name: forum_topic_statuses id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.forum_topic_statuses ALTER COLUMN id SET DEFAULT nextval('public.forum_topic_statuses_id_seq'::regclass);


--
-- Name: forum_topics id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.forum_topics ALTER COLUMN id SET DEFAULT nextval('public.forum_topics_id_seq'::regclass);


--
-- Name: help_pages id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.help_pages ALTER COLUMN id SET DEFAULT nextval('public.help_pages_id_seq'::regclass);


--
-- Name: ip_bans id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ip_bans ALTER COLUMN id SET DEFAULT nextval('public.ip_bans_id_seq'::regclass);


--
-- Name: linked_accounts id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.linked_accounts ALTER COLUMN id SET DEFAULT nextval('public.linked_accounts_id_seq'::regclass);


--
-- Name: mascot_media_assets id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.mascot_media_assets ALTER COLUMN id SET DEFAULT nextval('public.mascot_media_assets_id_seq'::regclass);


--
-- Name: mascots id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.mascots ALTER COLUMN id SET DEFAULT nextval('public.mascots_id_seq'::regclass);


--
-- Name: media_metadata id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.media_metadata ALTER COLUMN id SET DEFAULT nextval('public.media_metadata_id_seq'::regclass);


--
-- Name: mod_actions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.mod_actions ALTER COLUMN id SET DEFAULT nextval('public.mod_actions_id_seq'::regclass);


--
-- Name: news_updates id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.news_updates ALTER COLUMN id SET DEFAULT nextval('public.news_updates_id_seq'::regclass);


--
-- Name: note_versions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.note_versions ALTER COLUMN id SET DEFAULT nextval('public.note_versions_id_seq'::regclass);


--
-- Name: notes id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.notes ALTER COLUMN id SET DEFAULT nextval('public.notes_id_seq'::regclass);


--
-- Name: notifications id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.notifications ALTER COLUMN id SET DEFAULT nextval('public.notifications_id_seq'::regclass);


--
-- Name: pool_versions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pool_versions ALTER COLUMN id SET DEFAULT nextval('public.pool_versions_id_seq'::regclass);


--
-- Name: pools id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pools ALTER COLUMN id SET DEFAULT nextval('public.pools_id_seq'::regclass);


--
-- Name: post_appeals id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.post_appeals ALTER COLUMN id SET DEFAULT nextval('public.post_appeals_id_seq'::regclass);


--
-- Name: post_approvals id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.post_approvals ALTER COLUMN id SET DEFAULT nextval('public.post_approvals_id_seq'::regclass);


--
-- Name: post_deletion_reasons id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.post_deletion_reasons ALTER COLUMN id SET DEFAULT nextval('public.post_deletion_reasons_id_seq'::regclass);


--
-- Name: post_disapprovals id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.post_disapprovals ALTER COLUMN id SET DEFAULT nextval('public.post_disapprovals_id_seq'::regclass);


--
-- Name: post_events id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.post_events ALTER COLUMN id SET DEFAULT nextval('public.post_events_id_seq'::regclass);


--
-- Name: post_flags id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.post_flags ALTER COLUMN id SET DEFAULT nextval('public.post_flags_id_seq'::regclass);


--
-- Name: post_replacement_media_assets id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.post_replacement_media_assets ALTER COLUMN id SET DEFAULT nextval('public.post_replacement_media_assets_id_seq'::regclass);


--
-- Name: post_replacement_rejection_reasons id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.post_replacement_rejection_reasons ALTER COLUMN id SET DEFAULT nextval('public.post_replacement_rejection_reasons_id_seq'::regclass);


--
-- Name: post_replacements id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.post_replacements ALTER COLUMN id SET DEFAULT nextval('public.post_replacements_id_seq'::regclass);


--
-- Name: post_set_maintainers id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.post_set_maintainers ALTER COLUMN id SET DEFAULT nextval('public.post_set_maintainers_id_seq'::regclass);


--
-- Name: post_sets id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.post_sets ALTER COLUMN id SET DEFAULT nextval('public.post_sets_id_seq'::regclass);


--
-- Name: post_versions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.post_versions ALTER COLUMN id SET DEFAULT nextval('public.post_versions_id_seq'::regclass);


--
-- Name: post_votes id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.post_votes ALTER COLUMN id SET DEFAULT nextval('public.post_votes_id_seq'::regclass);


--
-- Name: posts id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.posts ALTER COLUMN id SET DEFAULT nextval('public.posts_id_seq'::regclass);


--
-- Name: posts change_seq; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.posts ALTER COLUMN change_seq SET DEFAULT nextval('public.posts_change_seq_seq'::regclass);


--
-- Name: quick_rules id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.quick_rules ALTER COLUMN id SET DEFAULT nextval('public.quick_rules_id_seq'::regclass);


--
-- Name: rule_categories id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.rule_categories ALTER COLUMN id SET DEFAULT nextval('public.rule_categories_id_seq'::regclass);


--
-- Name: rules id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.rules ALTER COLUMN id SET DEFAULT nextval('public.rules_id_seq'::regclass);


--
-- Name: staff_audit_logs id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.staff_audit_logs ALTER COLUMN id SET DEFAULT nextval('public.staff_audit_logs_id_seq'::regclass);


--
-- Name: staff_notes id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.staff_notes ALTER COLUMN id SET DEFAULT nextval('public.staff_notes_id_seq'::regclass);


--
-- Name: tag_aliases id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tag_aliases ALTER COLUMN id SET DEFAULT nextval('public.tag_aliases_id_seq'::regclass);


--
-- Name: tag_followers id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tag_followers ALTER COLUMN id SET DEFAULT nextval('public.tag_followers_id_seq'::regclass);


--
-- Name: tag_implications id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tag_implications ALTER COLUMN id SET DEFAULT nextval('public.tag_implications_id_seq'::regclass);


--
-- Name: tag_rel_undos id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tag_rel_undos ALTER COLUMN id SET DEFAULT nextval('public.tag_rel_undos_id_seq'::regclass);


--
-- Name: tag_versions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tag_versions ALTER COLUMN id SET DEFAULT nextval('public.tag_versions_id_seq'::regclass);


--
-- Name: tags id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tags ALTER COLUMN id SET DEFAULT nextval('public.tags_id_seq'::regclass);


--
-- Name: takedowns id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.takedowns ALTER COLUMN id SET DEFAULT nextval('public.takedowns_id_seq'::regclass);


--
-- Name: tickets id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tickets ALTER COLUMN id SET DEFAULT nextval('public.tickets_id_seq'::regclass);


--
-- Name: upload_media_assets id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.upload_media_assets ALTER COLUMN id SET DEFAULT nextval('public.upload_media_assets_id_seq'::regclass);


--
-- Name: upload_whitelists id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.upload_whitelists ALTER COLUMN id SET DEFAULT nextval('public.upload_whitelists_id_seq'::regclass);


--
-- Name: uploads id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.uploads ALTER COLUMN id SET DEFAULT nextval('public.uploads_id_seq'::regclass);


--
-- Name: user_approvals id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_approvals ALTER COLUMN id SET DEFAULT nextval('public.user_approvals_id_seq'::regclass);


--
-- Name: user_blocks id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_blocks ALTER COLUMN id SET DEFAULT nextval('public.user_blocks_id_seq'::regclass);


--
-- Name: user_events id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_events ALTER COLUMN id SET DEFAULT nextval('public.user_events_id_seq'::regclass);


--
-- Name: user_feedbacks id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_feedbacks ALTER COLUMN id SET DEFAULT nextval('public.user_feedbacks_id_seq'::regclass);


--
-- Name: user_name_change_requests id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_name_change_requests ALTER COLUMN id SET DEFAULT nextval('public.user_name_change_requests_id_seq'::regclass);


--
-- Name: user_password_reset_nonces id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_password_reset_nonces ALTER COLUMN id SET DEFAULT nextval('public.user_password_reset_nonces_id_seq'::regclass);


--
-- Name: user_sessions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_sessions ALTER COLUMN id SET DEFAULT nextval('public.user_sessions_id_seq'::regclass);


--
-- Name: user_text_versions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_text_versions ALTER COLUMN id SET DEFAULT nextval('public.user_text_versions_id_seq'::regclass);


--
-- Name: users id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users ALTER COLUMN id SET DEFAULT nextval('public.users_id_seq'::regclass);


--
-- Name: wiki_page_versions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.wiki_page_versions ALTER COLUMN id SET DEFAULT nextval('public.wiki_page_versions_id_seq'::regclass);


--
-- Name: wiki_pages id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.wiki_pages ALTER COLUMN id SET DEFAULT nextval('public.wiki_pages_id_seq'::regclass);


--
-- Name: api_keys api_keys_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.api_keys
    ADD CONSTRAINT api_keys_pkey PRIMARY KEY (id);


--
-- Name: ar_internal_metadata ar_internal_metadata_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ar_internal_metadata
    ADD CONSTRAINT ar_internal_metadata_pkey PRIMARY KEY (key);


--
-- Name: artist_urls artist_urls_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.artist_urls
    ADD CONSTRAINT artist_urls_pkey PRIMARY KEY (id);


--
-- Name: artist_versions artist_versions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.artist_versions
    ADD CONSTRAINT artist_versions_pkey PRIMARY KEY (id);


--
-- Name: artists artists_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.artists
    ADD CONSTRAINT artists_pkey PRIMARY KEY (id);


--
-- Name: avoid_posting_versions avoid_posting_versions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.avoid_posting_versions
    ADD CONSTRAINT avoid_posting_versions_pkey PRIMARY KEY (id);


--
-- Name: avoid_postings avoid_postings_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.avoid_postings
    ADD CONSTRAINT avoid_postings_pkey PRIMARY KEY (id);


--
-- Name: bans bans_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.bans
    ADD CONSTRAINT bans_pkey PRIMARY KEY (id);


--
-- Name: bulk_update_request_imports bulk_update_request_imports_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.bulk_update_request_imports
    ADD CONSTRAINT bulk_update_request_imports_pkey PRIMARY KEY (id);


--
-- Name: bulk_update_request_versions bulk_update_request_versions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.bulk_update_request_versions
    ADD CONSTRAINT bulk_update_request_versions_pkey PRIMARY KEY (id);


--
-- Name: bulk_update_requests bulk_update_requests_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.bulk_update_requests
    ADD CONSTRAINT bulk_update_requests_pkey PRIMARY KEY (id);


--
-- Name: comment_votes comment_votes_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.comment_votes
    ADD CONSTRAINT comment_votes_pkey PRIMARY KEY (id);


--
-- Name: comments comments_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.comments
    ADD CONSTRAINT comments_pkey PRIMARY KEY (id);


--
-- Name: config config_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.config
    ADD CONSTRAINT config_pkey PRIMARY KEY (id);


--
-- Name: db_exports db_exports_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.db_exports
    ADD CONSTRAINT db_exports_pkey PRIMARY KEY (id);


--
-- Name: destroyed_posts destroyed_posts_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.destroyed_posts
    ADD CONSTRAINT destroyed_posts_pkey PRIMARY KEY (id);


--
-- Name: dmail_filters dmail_filters_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.dmail_filters
    ADD CONSTRAINT dmail_filters_pkey PRIMARY KEY (id);


--
-- Name: dmails dmails_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.dmails
    ADD CONSTRAINT dmails_pkey PRIMARY KEY (id);


--
-- Name: dtext_links dtext_links_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.dtext_links
    ADD CONSTRAINT dtext_links_pkey PRIMARY KEY (id);


--
-- Name: edit_histories edit_histories_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.edit_histories
    ADD CONSTRAINT edit_histories_pkey PRIMARY KEY (id);


--
-- Name: email_blacklists email_blacklists_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.email_blacklists
    ADD CONSTRAINT email_blacklists_pkey PRIMARY KEY (id);


--
-- Name: exception_logs exception_logs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.exception_logs
    ADD CONSTRAINT exception_logs_pkey PRIMARY KEY (id);


--
-- Name: favorites favorites_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.favorites
    ADD CONSTRAINT favorites_pkey PRIMARY KEY (id);


--
-- Name: forum_categories forum_categories_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.forum_categories
    ADD CONSTRAINT forum_categories_pkey PRIMARY KEY (id);


--
-- Name: forum_category_visits forum_category_visits_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.forum_category_visits
    ADD CONSTRAINT forum_category_visits_pkey PRIMARY KEY (id);


--
-- Name: forum_post_votes forum_post_votes_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.forum_post_votes
    ADD CONSTRAINT forum_post_votes_pkey PRIMARY KEY (id);


--
-- Name: forum_posts forum_posts_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.forum_posts
    ADD CONSTRAINT forum_posts_pkey PRIMARY KEY (id);


--
-- Name: forum_topic_statuses forum_topic_statuses_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.forum_topic_statuses
    ADD CONSTRAINT forum_topic_statuses_pkey PRIMARY KEY (id);


--
-- Name: forum_topics forum_topics_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.forum_topics
    ADD CONSTRAINT forum_topics_pkey PRIMARY KEY (id);


--
-- Name: good_job_batches good_job_batches_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.good_job_batches
    ADD CONSTRAINT good_job_batches_pkey PRIMARY KEY (id);


--
-- Name: good_job_executions good_job_executions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.good_job_executions
    ADD CONSTRAINT good_job_executions_pkey PRIMARY KEY (id);


--
-- Name: good_job_processes good_job_processes_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.good_job_processes
    ADD CONSTRAINT good_job_processes_pkey PRIMARY KEY (id);


--
-- Name: good_job_settings good_job_settings_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.good_job_settings
    ADD CONSTRAINT good_job_settings_pkey PRIMARY KEY (id);


--
-- Name: good_jobs good_jobs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.good_jobs
    ADD CONSTRAINT good_jobs_pkey PRIMARY KEY (id);


--
-- Name: help_pages help_pages_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.help_pages
    ADD CONSTRAINT help_pages_pkey PRIMARY KEY (id);


--
-- Name: ip_bans ip_bans_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ip_bans
    ADD CONSTRAINT ip_bans_pkey PRIMARY KEY (id);


--
-- Name: linked_accounts linked_accounts_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.linked_accounts
    ADD CONSTRAINT linked_accounts_pkey PRIMARY KEY (id);


--
-- Name: mascot_media_assets mascot_media_assets_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.mascot_media_assets
    ADD CONSTRAINT mascot_media_assets_pkey PRIMARY KEY (id);


--
-- Name: mascots mascots_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.mascots
    ADD CONSTRAINT mascots_pkey PRIMARY KEY (id);


--
-- Name: media_metadata media_metadata_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.media_metadata
    ADD CONSTRAINT media_metadata_pkey PRIMARY KEY (id);


--
-- Name: mod_actions mod_actions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.mod_actions
    ADD CONSTRAINT mod_actions_pkey PRIMARY KEY (id);


--
-- Name: news_updates news_updates_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.news_updates
    ADD CONSTRAINT news_updates_pkey PRIMARY KEY (id);


--
-- Name: note_versions note_versions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.note_versions
    ADD CONSTRAINT note_versions_pkey PRIMARY KEY (id);


--
-- Name: notes notes_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.notes
    ADD CONSTRAINT notes_pkey PRIMARY KEY (id);


--
-- Name: notifications notifications_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.notifications
    ADD CONSTRAINT notifications_pkey PRIMARY KEY (id);


--
-- Name: pool_versions pool_versions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pool_versions
    ADD CONSTRAINT pool_versions_pkey PRIMARY KEY (id);


--
-- Name: pools pools_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pools
    ADD CONSTRAINT pools_pkey PRIMARY KEY (id);


--
-- Name: post_appeals post_appeals_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.post_appeals
    ADD CONSTRAINT post_appeals_pkey PRIMARY KEY (id);


--
-- Name: post_approvals post_approvals_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.post_approvals
    ADD CONSTRAINT post_approvals_pkey PRIMARY KEY (id);


--
-- Name: post_deletion_reasons post_deletion_reasons_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.post_deletion_reasons
    ADD CONSTRAINT post_deletion_reasons_pkey PRIMARY KEY (id);


--
-- Name: post_disapprovals post_disapprovals_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.post_disapprovals
    ADD CONSTRAINT post_disapprovals_pkey PRIMARY KEY (id);


--
-- Name: post_events post_events_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.post_events
    ADD CONSTRAINT post_events_pkey PRIMARY KEY (id);


--
-- Name: post_flags post_flags_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.post_flags
    ADD CONSTRAINT post_flags_pkey PRIMARY KEY (id);


--
-- Name: post_replacement_media_assets post_replacement_media_assets_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.post_replacement_media_assets
    ADD CONSTRAINT post_replacement_media_assets_pkey PRIMARY KEY (id);


--
-- Name: post_replacement_rejection_reasons post_replacement_rejection_reasons_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.post_replacement_rejection_reasons
    ADD CONSTRAINT post_replacement_rejection_reasons_pkey PRIMARY KEY (id);


--
-- Name: post_replacements post_replacements_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.post_replacements
    ADD CONSTRAINT post_replacements_pkey PRIMARY KEY (id);


--
-- Name: post_set_maintainers post_set_maintainers_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.post_set_maintainers
    ADD CONSTRAINT post_set_maintainers_pkey PRIMARY KEY (id);


--
-- Name: post_sets post_sets_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.post_sets
    ADD CONSTRAINT post_sets_pkey PRIMARY KEY (id);


--
-- Name: post_versions post_versions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.post_versions
    ADD CONSTRAINT post_versions_pkey PRIMARY KEY (id);

ALTER TABLE public.post_versions CLUSTER ON post_versions_pkey;


--
-- Name: post_votes post_votes_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.post_votes
    ADD CONSTRAINT post_votes_pkey PRIMARY KEY (id);


--
-- Name: posts posts_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.posts
    ADD CONSTRAINT posts_pkey PRIMARY KEY (id);


--
-- Name: quick_rules quick_rules_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.quick_rules
    ADD CONSTRAINT quick_rules_pkey PRIMARY KEY (id);


--
-- Name: rule_categories rule_categories_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.rule_categories
    ADD CONSTRAINT rule_categories_pkey PRIMARY KEY (id);


--
-- Name: rules rules_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.rules
    ADD CONSTRAINT rules_pkey PRIMARY KEY (id);


--
-- Name: schema_migrations schema_migrations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.schema_migrations
    ADD CONSTRAINT schema_migrations_pkey PRIMARY KEY (version);


--
-- Name: staff_audit_logs staff_audit_logs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.staff_audit_logs
    ADD CONSTRAINT staff_audit_logs_pkey PRIMARY KEY (id);


--
-- Name: staff_notes staff_notes_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.staff_notes
    ADD CONSTRAINT staff_notes_pkey PRIMARY KEY (id);


--
-- Name: tag_aliases tag_aliases_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tag_aliases
    ADD CONSTRAINT tag_aliases_pkey PRIMARY KEY (id);


--
-- Name: tag_followers tag_followers_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tag_followers
    ADD CONSTRAINT tag_followers_pkey PRIMARY KEY (id);


--
-- Name: tag_implications tag_implications_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tag_implications
    ADD CONSTRAINT tag_implications_pkey PRIMARY KEY (id);


--
-- Name: tag_rel_undos tag_rel_undos_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tag_rel_undos
    ADD CONSTRAINT tag_rel_undos_pkey PRIMARY KEY (id);


--
-- Name: tag_versions tag_versions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tag_versions
    ADD CONSTRAINT tag_versions_pkey PRIMARY KEY (id);


--
-- Name: tags tags_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tags
    ADD CONSTRAINT tags_pkey PRIMARY KEY (id);


--
-- Name: takedowns takedowns_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.takedowns
    ADD CONSTRAINT takedowns_pkey PRIMARY KEY (id);


--
-- Name: tickets tickets_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tickets
    ADD CONSTRAINT tickets_pkey PRIMARY KEY (id);


--
-- Name: upload_media_assets upload_media_assets_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.upload_media_assets
    ADD CONSTRAINT upload_media_assets_pkey PRIMARY KEY (id);


--
-- Name: upload_whitelists upload_whitelists_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.upload_whitelists
    ADD CONSTRAINT upload_whitelists_pkey PRIMARY KEY (id);


--
-- Name: uploads uploads_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.uploads
    ADD CONSTRAINT uploads_pkey PRIMARY KEY (id);


--
-- Name: user_approvals user_approvals_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_approvals
    ADD CONSTRAINT user_approvals_pkey PRIMARY KEY (id);


--
-- Name: user_blocks user_blocks_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_blocks
    ADD CONSTRAINT user_blocks_pkey PRIMARY KEY (id);


--
-- Name: user_events user_events_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_events
    ADD CONSTRAINT user_events_pkey PRIMARY KEY (id);


--
-- Name: user_feedbacks user_feedbacks_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_feedbacks
    ADD CONSTRAINT user_feedbacks_pkey PRIMARY KEY (id);


--
-- Name: user_name_change_requests user_name_change_requests_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_name_change_requests
    ADD CONSTRAINT user_name_change_requests_pkey PRIMARY KEY (id);


--
-- Name: user_password_reset_nonces user_password_reset_nonces_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_password_reset_nonces
    ADD CONSTRAINT user_password_reset_nonces_pkey PRIMARY KEY (id);


--
-- Name: user_sessions user_sessions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_sessions
    ADD CONSTRAINT user_sessions_pkey PRIMARY KEY (id);


--
-- Name: user_text_versions user_text_versions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_text_versions
    ADD CONSTRAINT user_text_versions_pkey PRIMARY KEY (id);


--
-- Name: users users_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);


--
-- Name: wiki_page_versions wiki_page_versions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.wiki_page_versions
    ADD CONSTRAINT wiki_page_versions_pkey PRIMARY KEY (id);


--
-- Name: wiki_pages wiki_pages_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.wiki_pages
    ADD CONSTRAINT wiki_pages_pkey PRIMARY KEY (id);


--
-- Name: index_api_keys_on_key; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_api_keys_on_key ON public.api_keys USING btree (key);


--
-- Name: index_api_keys_on_name_and_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_api_keys_on_name_and_user_id ON public.api_keys USING btree (name, user_id);


--
-- Name: index_artist_urls_on_artist_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_artist_urls_on_artist_id ON public.artist_urls USING btree (artist_id);


--
-- Name: index_artist_urls_on_artist_id_and_url; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_artist_urls_on_artist_id_and_url ON public.artist_urls USING btree (artist_id, url);


--
-- Name: index_artist_urls_on_normalized_url_pattern; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_artist_urls_on_normalized_url_pattern ON public.artist_urls USING btree (normalized_url text_pattern_ops);


--
-- Name: index_artist_urls_on_normalized_url_trgm; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_artist_urls_on_normalized_url_trgm ON public.artist_urls USING gin (normalized_url public.gin_trgm_ops);


--
-- Name: index_artist_urls_on_url_trgm; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_artist_urls_on_url_trgm ON public.artist_urls USING gin (url public.gin_trgm_ops);


--
-- Name: index_artist_versions_on_artist_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_artist_versions_on_artist_id ON public.artist_versions USING btree (artist_id);


--
-- Name: index_artist_versions_on_created_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_artist_versions_on_created_at ON public.artist_versions USING btree (created_at);


--
-- Name: index_artist_versions_on_linked_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_artist_versions_on_linked_user_id ON public.artist_versions USING btree (linked_user_id);


--
-- Name: index_artist_versions_on_name; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_artist_versions_on_name ON public.artist_versions USING btree (name);


--
-- Name: index_artist_versions_on_updater_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_artist_versions_on_updater_id ON public.artist_versions USING btree (updater_id);


--
-- Name: index_artist_versions_on_updater_ip_addr; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_artist_versions_on_updater_ip_addr ON public.artist_versions USING btree (updater_ip_addr);


--
-- Name: index_artists_on_linked_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_artists_on_linked_user_id ON public.artists USING btree (linked_user_id);


--
-- Name: index_artists_on_name; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_artists_on_name ON public.artists USING btree (name);


--
-- Name: index_artists_on_name_trgm; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_artists_on_name_trgm ON public.artists USING gin (name public.gin_trgm_ops);


--
-- Name: index_artists_on_other_names; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_artists_on_other_names ON public.artists USING gin (other_names);


--
-- Name: index_avoid_posting_versions_on_avoid_posting_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_avoid_posting_versions_on_avoid_posting_id ON public.avoid_posting_versions USING btree (avoid_posting_id);


--
-- Name: index_avoid_posting_versions_on_updater_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_avoid_posting_versions_on_updater_id ON public.avoid_posting_versions USING btree (updater_id);


--
-- Name: index_avoid_postings_on_artist_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_avoid_postings_on_artist_id ON public.avoid_postings USING btree (artist_id);


--
-- Name: index_avoid_postings_on_creator_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_avoid_postings_on_creator_id ON public.avoid_postings USING btree (creator_id);


--
-- Name: index_avoid_postings_on_updater_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_avoid_postings_on_updater_id ON public.avoid_postings USING btree (updater_id);


--
-- Name: index_bans_on_banner_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_bans_on_banner_id ON public.bans USING btree (banner_id);


--
-- Name: index_bans_on_expires_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_bans_on_expires_at ON public.bans USING btree (expires_at);


--
-- Name: index_bans_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_bans_on_user_id ON public.bans USING btree (user_id);


--
-- Name: index_bulk_update_request_imports_on_creator_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_bulk_update_request_imports_on_creator_id ON public.bulk_update_request_imports USING btree (creator_id);


--
-- Name: index_bulk_update_request_imports_on_forum_topic_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_bulk_update_request_imports_on_forum_topic_id ON public.bulk_update_request_imports USING btree (forum_topic_id);


--
-- Name: index_bulk_update_request_imports_on_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_bulk_update_request_imports_on_status ON public.bulk_update_request_imports USING btree (status);


--
-- Name: index_bulk_update_request_imports_on_updater_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_bulk_update_request_imports_on_updater_id ON public.bulk_update_request_imports USING btree (updater_id);


--
-- Name: index_bulk_update_request_versions_on_bulk_update_request_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_bulk_update_request_versions_on_bulk_update_request_id ON public.bulk_update_request_versions USING btree (bulk_update_request_id);


--
-- Name: index_bulk_update_request_versions_on_updater_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_bulk_update_request_versions_on_updater_id ON public.bulk_update_request_versions USING btree (updater_id);


--
-- Name: index_bulk_update_requests_on_forum_post_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_bulk_update_requests_on_forum_post_id ON public.bulk_update_requests USING btree (forum_post_id);


--
-- Name: index_bulk_update_requests_on_updater_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_bulk_update_requests_on_updater_id ON public.bulk_update_requests USING btree (updater_id);


--
-- Name: index_comment_votes_on_comment_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_comment_votes_on_comment_id ON public.comment_votes USING btree (comment_id);


--
-- Name: index_comment_votes_on_comment_id_and_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_comment_votes_on_comment_id_and_user_id ON public.comment_votes USING btree (comment_id, user_id);


--
-- Name: index_comment_votes_on_created_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_comment_votes_on_created_at ON public.comment_votes USING btree (created_at);


--
-- Name: index_comment_votes_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_comment_votes_on_user_id ON public.comment_votes USING btree (user_id);


--
-- Name: index_comments_on_creator_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_comments_on_creator_id ON public.comments USING btree (creator_id);


--
-- Name: index_comments_on_creator_id_and_post_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_comments_on_creator_id_and_post_id ON public.comments USING btree (creator_id, post_id);


--
-- Name: index_comments_on_creator_ip_addr; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_comments_on_creator_ip_addr ON public.comments USING btree (creator_ip_addr);


--
-- Name: index_comments_on_lower_body_trgm; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_comments_on_lower_body_trgm ON public.comments USING gin (lower(body) public.gin_trgm_ops);


--
-- Name: index_comments_on_post_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_comments_on_post_id ON public.comments USING btree (post_id);


--
-- Name: index_comments_on_post_id_and_is_hidden; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_comments_on_post_id_and_is_hidden ON public.comments USING btree (post_id, is_hidden);


--
-- Name: index_comments_on_to_tsvector_english_body; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_comments_on_to_tsvector_english_body ON public.comments USING gin (to_tsvector('english'::regconfig, body));


--
-- Name: index_db_exports_on_date; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_db_exports_on_date ON public.db_exports USING btree (date);


--
-- Name: index_db_exports_on_name_and_date; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_db_exports_on_name_and_date ON public.db_exports USING btree (name, date);


--
-- Name: index_dmail_filters_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_dmail_filters_on_user_id ON public.dmail_filters USING btree (user_id);


--
-- Name: index_dmails_on_from_ip_addr; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_dmails_on_from_ip_addr ON public.dmails USING btree (from_ip_addr);


--
-- Name: index_dmails_on_is_deleted; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_dmails_on_is_deleted ON public.dmails USING btree (is_deleted);


--
-- Name: index_dmails_on_is_read; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_dmails_on_is_read ON public.dmails USING btree (is_read);


--
-- Name: index_dmails_on_lower_body_trgm; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_dmails_on_lower_body_trgm ON public.dmails USING gin (lower(body) public.gin_trgm_ops);


--
-- Name: index_dmails_on_owner_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_dmails_on_owner_id ON public.dmails USING btree (owner_id);


--
-- Name: index_dmails_on_respond_to_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_dmails_on_respond_to_id ON public.dmails USING btree (respond_to_id);


--
-- Name: index_dmails_on_to_tsvector_english_body; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_dmails_on_to_tsvector_english_body ON public.dmails USING gin (to_tsvector('english'::regconfig, body));


--
-- Name: index_dtext_links_on_link_target; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_dtext_links_on_link_target ON public.dtext_links USING btree (link_target text_pattern_ops);


--
-- Name: index_dtext_links_on_link_target_and_model_type_and_model_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_dtext_links_on_link_target_and_model_type_and_model_id ON public.dtext_links USING btree (link_target, model_type, model_id);


--
-- Name: index_dtext_links_on_link_type; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_dtext_links_on_link_type ON public.dtext_links USING btree (link_type);


--
-- Name: index_dtext_links_on_model; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_dtext_links_on_model ON public.dtext_links USING btree (model_type, model_id);


--
-- Name: index_edit_histories_on_updater_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_edit_histories_on_updater_id ON public.edit_histories USING btree (updater_id);


--
-- Name: index_edit_histories_on_versionable_id_and_versionable_type; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_edit_histories_on_versionable_id_and_versionable_type ON public.edit_histories USING btree (versionable_id, versionable_type);


--
-- Name: index_email_blacklists_on_lower_domain; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_email_blacklists_on_lower_domain ON public.email_blacklists USING btree (lower((domain)::text));


--
-- Name: index_favorites_on_post_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_favorites_on_post_id ON public.favorites USING btree (post_id);


--
-- Name: index_favorites_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_favorites_on_user_id ON public.favorites USING btree (user_id);


--
-- Name: index_favorites_on_user_id_and_post_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_favorites_on_user_id_and_post_id ON public.favorites USING btree (user_id, post_id);


--
-- Name: index_fixes_on_id_and_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_fixes_on_id_and_index ON public.fixes USING btree (id, index) NULLS NOT DISTINCT;


--
-- Name: index_forum_categories_on_creator_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_forum_categories_on_creator_id ON public.forum_categories USING btree (creator_id);


--
-- Name: index_forum_categories_on_lower_name; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_forum_categories_on_lower_name ON public.forum_categories USING btree (lower((name)::text));


--
-- Name: index_forum_categories_on_updater_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_forum_categories_on_updater_id ON public.forum_categories USING btree (updater_id);


--
-- Name: index_forum_category_visits_on_forum_category_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_forum_category_visits_on_forum_category_id ON public.forum_category_visits USING btree (forum_category_id);


--
-- Name: index_forum_category_visits_on_last_read_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_forum_category_visits_on_last_read_at ON public.forum_category_visits USING btree (last_read_at);


--
-- Name: index_forum_category_visits_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_forum_category_visits_on_user_id ON public.forum_category_visits USING btree (user_id);


--
-- Name: index_forum_post_votes_on_forum_post_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_forum_post_votes_on_forum_post_id ON public.forum_post_votes USING btree (forum_post_id);


--
-- Name: index_forum_post_votes_on_forum_post_id_and_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_forum_post_votes_on_forum_post_id_and_user_id ON public.forum_post_votes USING btree (forum_post_id, user_id);


--
-- Name: index_forum_posts_on_creator_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_forum_posts_on_creator_id ON public.forum_posts USING btree (creator_id);


--
-- Name: index_forum_posts_on_lower_body_trgm; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_forum_posts_on_lower_body_trgm ON public.forum_posts USING gin (lower(body) public.gin_trgm_ops);


--
-- Name: index_forum_posts_on_original_topic_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_forum_posts_on_original_topic_id ON public.forum_posts USING btree (original_topic_id);


--
-- Name: index_forum_posts_on_to_tsvector_english_body; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_forum_posts_on_to_tsvector_english_body ON public.forum_posts USING gin (to_tsvector('english'::regconfig, body));


--
-- Name: index_forum_posts_on_topic_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_forum_posts_on_topic_id ON public.forum_posts USING btree (topic_id);


--
-- Name: index_forum_topic_statuses_on_forum_topic_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_forum_topic_statuses_on_forum_topic_id ON public.forum_topic_statuses USING btree (forum_topic_id);


--
-- Name: index_forum_topic_statuses_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_forum_topic_statuses_on_user_id ON public.forum_topic_statuses USING btree (user_id);


--
-- Name: index_forum_topics_on_creator_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_forum_topics_on_creator_id ON public.forum_topics USING btree (creator_id);


--
-- Name: index_forum_topics_on_is_sticky_and_updated_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_forum_topics_on_is_sticky_and_updated_at ON public.forum_topics USING btree (is_sticky, updated_at);


--
-- Name: index_forum_topics_on_lower_title_trgm; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_forum_topics_on_lower_title_trgm ON public.forum_topics USING gin (lower((title)::text) public.gin_trgm_ops);


--
-- Name: index_forum_topics_on_merge_target_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_forum_topics_on_merge_target_id ON public.forum_topics USING btree (merge_target_id);


--
-- Name: index_forum_topics_on_to_tsvector_english_title; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_forum_topics_on_to_tsvector_english_title ON public.forum_topics USING gin (to_tsvector('english'::regconfig, (title)::text));


--
-- Name: index_forum_topics_on_updated_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_forum_topics_on_updated_at ON public.forum_topics USING btree (updated_at);


--
-- Name: index_good_job_executions_on_active_job_id_and_created_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_good_job_executions_on_active_job_id_and_created_at ON public.good_job_executions USING btree (active_job_id, created_at);


--
-- Name: index_good_job_executions_on_process_id_and_created_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_good_job_executions_on_process_id_and_created_at ON public.good_job_executions USING btree (process_id, created_at);


--
-- Name: index_good_job_jobs_for_candidate_lookup; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_good_job_jobs_for_candidate_lookup ON public.good_jobs USING btree (priority, created_at) WHERE (finished_at IS NULL);


--
-- Name: index_good_job_settings_on_key; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_good_job_settings_on_key ON public.good_job_settings USING btree (key);


--
-- Name: index_good_jobs_for_candidate_dequeue_unlocked; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_good_jobs_for_candidate_dequeue_unlocked ON public.good_jobs USING btree (priority, scheduled_at, id) WHERE ((finished_at IS NULL) AND (locked_by_id IS NULL));


--
-- Name: index_good_jobs_jobs_on_finished_at_only; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_good_jobs_jobs_on_finished_at_only ON public.good_jobs USING btree (finished_at) WHERE (finished_at IS NOT NULL);


--
-- Name: index_good_jobs_jobs_on_priority_created_at_when_unfinished; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_good_jobs_jobs_on_priority_created_at_when_unfinished ON public.good_jobs USING btree (priority DESC NULLS LAST, created_at) WHERE (finished_at IS NULL);


--
-- Name: index_good_jobs_on_active_job_id_and_created_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_good_jobs_on_active_job_id_and_created_at ON public.good_jobs USING btree (active_job_id, created_at);


--
-- Name: index_good_jobs_on_batch_callback_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_good_jobs_on_batch_callback_id ON public.good_jobs USING btree (batch_callback_id) WHERE (batch_callback_id IS NOT NULL);


--
-- Name: index_good_jobs_on_batch_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_good_jobs_on_batch_id ON public.good_jobs USING btree (batch_id) WHERE (batch_id IS NOT NULL);


--
-- Name: index_good_jobs_on_concurrency_key_and_created_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_good_jobs_on_concurrency_key_and_created_at ON public.good_jobs USING btree (concurrency_key, created_at);


--
-- Name: index_good_jobs_on_concurrency_key_when_unfinished; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_good_jobs_on_concurrency_key_when_unfinished ON public.good_jobs USING btree (concurrency_key) WHERE (finished_at IS NULL);


--
-- Name: index_good_jobs_on_created_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_good_jobs_on_created_at ON public.good_jobs USING btree (created_at);


--
-- Name: index_good_jobs_on_cron_key_and_created_at_cond; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_good_jobs_on_cron_key_and_created_at_cond ON public.good_jobs USING btree (cron_key, created_at) WHERE (cron_key IS NOT NULL);


--
-- Name: index_good_jobs_on_cron_key_and_cron_at_cond; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_good_jobs_on_cron_key_and_cron_at_cond ON public.good_jobs USING btree (cron_key, cron_at) WHERE (cron_key IS NOT NULL);


--
-- Name: index_good_jobs_on_discarded; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_good_jobs_on_discarded ON public.good_jobs USING btree (finished_at DESC) WHERE ((finished_at IS NOT NULL) AND (error IS NOT NULL));


--
-- Name: index_good_jobs_on_job_class; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_good_jobs_on_job_class ON public.good_jobs USING btree (job_class);


--
-- Name: index_good_jobs_on_labels; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_good_jobs_on_labels ON public.good_jobs USING gin (labels) WHERE (labels IS NOT NULL);


--
-- Name: index_good_jobs_on_locked_by_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_good_jobs_on_locked_by_id ON public.good_jobs USING btree (locked_by_id) WHERE (locked_by_id IS NOT NULL);


--
-- Name: index_good_jobs_on_priority_scheduled_at_unfinished; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_good_jobs_on_priority_scheduled_at_unfinished ON public.good_jobs USING btree (priority, scheduled_at, id) WHERE (finished_at IS NULL);


--
-- Name: index_good_jobs_on_priority_scheduled_at_unfinished_unlocked; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_good_jobs_on_priority_scheduled_at_unfinished_unlocked ON public.good_jobs USING btree (priority, scheduled_at) WHERE ((finished_at IS NULL) AND (locked_by_id IS NULL));


--
-- Name: index_good_jobs_on_queue_name; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_good_jobs_on_queue_name ON public.good_jobs USING btree (queue_name);


--
-- Name: index_good_jobs_on_queue_name_and_scheduled_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_good_jobs_on_queue_name_and_scheduled_at ON public.good_jobs USING btree (queue_name, scheduled_at) WHERE (finished_at IS NULL);


--
-- Name: index_good_jobs_on_queue_name_priority_scheduled_at_unfinished; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_good_jobs_on_queue_name_priority_scheduled_at_unfinished ON public.good_jobs USING btree (queue_name, scheduled_at, id) WHERE (finished_at IS NULL);


--
-- Name: index_good_jobs_on_scheduled_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_good_jobs_on_scheduled_at ON public.good_jobs USING btree (scheduled_at) WHERE (finished_at IS NULL);


--
-- Name: index_good_jobs_on_scheduled_at_and_queue_name; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_good_jobs_on_scheduled_at_and_queue_name ON public.good_jobs USING btree (scheduled_at, queue_name);


--
-- Name: index_good_jobs_on_unfinished_or_errored; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_good_jobs_on_unfinished_or_errored ON public.good_jobs USING btree (id) WHERE ((finished_at IS NULL) OR (error IS NOT NULL));


--
-- Name: index_help_pages_on_creator_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_help_pages_on_creator_id ON public.help_pages USING btree (creator_id);


--
-- Name: index_help_pages_on_updater_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_help_pages_on_updater_id ON public.help_pages USING btree (updater_id);


--
-- Name: index_help_pages_on_wiki_page_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_help_pages_on_wiki_page_id ON public.help_pages USING btree (wiki_page_id);


--
-- Name: index_ip_bans_on_ip_addr; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_ip_bans_on_ip_addr ON public.ip_bans USING btree (ip_addr);


--
-- Name: index_linked_accounts_on_provider_and_uid; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_linked_accounts_on_provider_and_uid ON public.linked_accounts USING btree (provider, uid);


--
-- Name: index_linked_accounts_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_linked_accounts_on_user_id ON public.linked_accounts USING btree (user_id);


--
-- Name: index_linked_accounts_on_user_id_and_provider; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_linked_accounts_on_user_id_and_provider ON public.linked_accounts USING btree (user_id, provider);


--
-- Name: index_mascot_media_assets_on_checksum; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_mascot_media_assets_on_checksum ON public.mascot_media_assets USING btree (checksum);


--
-- Name: index_mascot_media_assets_on_creator_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_mascot_media_assets_on_creator_id ON public.mascot_media_assets USING btree (creator_id);


--
-- Name: index_mascot_media_assets_on_md5; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_mascot_media_assets_on_md5 ON public.mascot_media_assets USING btree (md5) WHERE ((status)::text = 'active'::text);


--
-- Name: index_mascot_media_assets_on_media_metadata_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_mascot_media_assets_on_media_metadata_id ON public.mascot_media_assets USING btree (media_metadata_id);


--
-- Name: index_mascot_media_assets_on_pixel_hash; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_mascot_media_assets_on_pixel_hash ON public.mascot_media_assets USING btree (pixel_hash);


--
-- Name: index_mascots_on_creator_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_mascots_on_creator_id ON public.mascots USING btree (creator_id);


--
-- Name: index_mascots_on_lower_display_name; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_mascots_on_lower_display_name ON public.mascots USING btree (lower((display_name)::text));


--
-- Name: index_mascots_on_mascot_media_asset_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_mascots_on_mascot_media_asset_id ON public.mascots USING btree (mascot_media_asset_id);


--
-- Name: index_mascots_on_updater_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_mascots_on_updater_id ON public.mascots USING btree (updater_id);


--
-- Name: index_mod_actions_on_action; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_mod_actions_on_action ON public.mod_actions USING btree (action);


--
-- Name: index_news_updates_on_created_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_news_updates_on_created_at ON public.news_updates USING btree (created_at);


--
-- Name: index_note_versions_on_created_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_note_versions_on_created_at ON public.note_versions USING btree (created_at);


--
-- Name: index_note_versions_on_note_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_note_versions_on_note_id ON public.note_versions USING btree (note_id);


--
-- Name: index_note_versions_on_post_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_note_versions_on_post_id ON public.note_versions USING btree (post_id);


--
-- Name: index_note_versions_on_updater_id_and_post_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_note_versions_on_updater_id_and_post_id ON public.note_versions USING btree (updater_id, post_id);


--
-- Name: index_note_versions_on_updater_ip_addr; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_note_versions_on_updater_ip_addr ON public.note_versions USING btree (updater_ip_addr);


--
-- Name: index_notes_on_creator_id_and_post_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_notes_on_creator_id_and_post_id ON public.notes USING btree (creator_id, post_id);


--
-- Name: index_notes_on_lower_body_trgm; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_notes_on_lower_body_trgm ON public.notes USING gin (lower(body) public.gin_trgm_ops);


--
-- Name: index_notes_on_post_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_notes_on_post_id ON public.notes USING btree (post_id);


--
-- Name: index_notes_on_post_id_and_is_active; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_notes_on_post_id_and_is_active ON public.notes USING btree (post_id, is_active);


--
-- Name: index_notes_on_to_tsvector_english_body; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_notes_on_to_tsvector_english_body ON public.notes USING gin (to_tsvector('english'::regconfig, body));


--
-- Name: index_notifications_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_notifications_on_user_id ON public.notifications USING btree (user_id);


--
-- Name: index_pool_versions_on_pool_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_pool_versions_on_pool_id ON public.pool_versions USING btree (pool_id);


--
-- Name: index_pool_versions_on_updater_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_pool_versions_on_updater_id ON public.pool_versions USING btree (updater_id);


--
-- Name: index_pool_versions_on_updater_ip_addr; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_pool_versions_on_updater_ip_addr ON public.pool_versions USING btree (updater_ip_addr);


--
-- Name: index_pools_on_cover_post_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_pools_on_cover_post_id ON public.pools USING btree (cover_post_id);


--
-- Name: index_pools_on_creator_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_pools_on_creator_id ON public.pools USING btree (creator_id);


--
-- Name: index_pools_on_lower_name; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_pools_on_lower_name ON public.pools USING btree (lower((name)::text));


--
-- Name: index_pools_on_name; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_pools_on_name ON public.pools USING btree (name);


--
-- Name: index_pools_on_name_trgm; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_pools_on_name_trgm ON public.pools USING gin (lower((name)::text) public.gin_trgm_ops);


--
-- Name: index_pools_on_post_ids; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_pools_on_post_ids ON public.pools USING gin (post_ids);


--
-- Name: index_pools_on_updated_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_pools_on_updated_at ON public.pools USING btree (updated_at);


--
-- Name: index_post_appeals_on_creator_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_post_appeals_on_creator_id ON public.post_appeals USING btree (creator_id);


--
-- Name: index_post_appeals_on_post_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_post_appeals_on_post_id ON public.post_appeals USING btree (post_id);


--
-- Name: index_post_appeals_on_post_id_and_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_post_appeals_on_post_id_and_status ON public.post_appeals USING btree (post_id, status);


--
-- Name: index_post_appeals_on_updater_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_post_appeals_on_updater_id ON public.post_appeals USING btree (updater_id);


--
-- Name: index_post_approvals_on_post_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_post_approvals_on_post_id ON public.post_approvals USING btree (post_id);


--
-- Name: index_post_approvals_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_post_approvals_on_user_id ON public.post_approvals USING btree (user_id);


--
-- Name: index_post_deletion_reasons_on_creator_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_post_deletion_reasons_on_creator_id ON public.post_deletion_reasons USING btree (creator_id);


--
-- Name: index_post_deletion_reasons_on_lower_prompt; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_post_deletion_reasons_on_lower_prompt ON public.post_deletion_reasons USING btree (lower((prompt)::text)) WHERE ((title)::text <> ''::text);


--
-- Name: index_post_deletion_reasons_on_lower_reason; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_post_deletion_reasons_on_lower_reason ON public.post_deletion_reasons USING btree (lower((reason)::text));


--
-- Name: index_post_deletion_reasons_on_lower_title; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_post_deletion_reasons_on_lower_title ON public.post_deletion_reasons USING btree (lower((title)::text)) WHERE ((title)::text <> ''::text);


--
-- Name: index_post_deletion_reasons_on_order; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_post_deletion_reasons_on_order ON public.post_deletion_reasons USING btree ("order");


--
-- Name: index_post_deletion_reasons_on_updater_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_post_deletion_reasons_on_updater_id ON public.post_deletion_reasons USING btree (updater_id);


--
-- Name: index_post_disapprovals_on_post_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_post_disapprovals_on_post_id ON public.post_disapprovals USING btree (post_id);


--
-- Name: index_post_disapprovals_on_post_id_and_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_post_disapprovals_on_post_id_and_user_id ON public.post_disapprovals USING btree (post_id, user_id);


--
-- Name: index_post_disapprovals_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_post_disapprovals_on_user_id ON public.post_disapprovals USING btree (user_id);


--
-- Name: index_post_events_on_creator_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_post_events_on_creator_id ON public.post_events USING btree (creator_id);


--
-- Name: index_post_events_on_post_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_post_events_on_post_id ON public.post_events USING btree (post_id);


--
-- Name: index_post_flags_on_creator_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_post_flags_on_creator_id ON public.post_flags USING btree (creator_id);


--
-- Name: index_post_flags_on_creator_ip_addr; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_post_flags_on_creator_ip_addr ON public.post_flags USING btree (creator_ip_addr);


--
-- Name: index_post_flags_on_post_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_post_flags_on_post_id ON public.post_flags USING btree (post_id);


--
-- Name: index_post_flags_on_post_id_and_is_resolved_and_is_deletion; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_post_flags_on_post_id_and_is_resolved_and_is_deletion ON public.post_flags USING btree (post_id, is_resolved, is_deletion);


--
-- Name: index_post_flags_on_reason_tsvector; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_post_flags_on_reason_tsvector ON public.post_flags USING gin (to_tsvector('english'::regconfig, reason));


--
-- Name: index_post_replacement_media_assets_on_checksum; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_post_replacement_media_assets_on_checksum ON public.post_replacement_media_assets USING btree (checksum);


--
-- Name: index_post_replacement_media_assets_on_creator_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_post_replacement_media_assets_on_creator_id ON public.post_replacement_media_assets USING btree (creator_id);


--
-- Name: index_post_replacement_media_assets_on_md5; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_post_replacement_media_assets_on_md5 ON public.post_replacement_media_assets USING btree (md5);


--
-- Name: index_post_replacement_media_assets_on_media_metadata_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_post_replacement_media_assets_on_media_metadata_id ON public.post_replacement_media_assets USING btree (media_metadata_id);


--
-- Name: index_post_replacement_media_assets_on_pixel_hash; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_post_replacement_media_assets_on_pixel_hash ON public.post_replacement_media_assets USING btree (pixel_hash);


--
-- Name: index_post_replacement_media_assets_on_storage_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_post_replacement_media_assets_on_storage_id ON public.post_replacement_media_assets USING btree (storage_id);


--
-- Name: index_post_replacement_rejection_reasons_on_creator_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_post_replacement_rejection_reasons_on_creator_id ON public.post_replacement_rejection_reasons USING btree (creator_id);


--
-- Name: index_post_replacement_rejection_reasons_on_lower_reason; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_post_replacement_rejection_reasons_on_lower_reason ON public.post_replacement_rejection_reasons USING btree (lower((reason)::text));


--
-- Name: index_post_replacement_rejection_reasons_on_order; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_post_replacement_rejection_reasons_on_order ON public.post_replacement_rejection_reasons USING btree ("order");


--
-- Name: index_post_replacement_rejection_reasons_on_updater_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_post_replacement_rejection_reasons_on_updater_id ON public.post_replacement_rejection_reasons USING btree (updater_id);


--
-- Name: index_post_replacements_on_creator_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_post_replacements_on_creator_id ON public.post_replacements USING btree (creator_id);


--
-- Name: index_post_replacements_on_post_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_post_replacements_on_post_id ON public.post_replacements USING btree (post_id);


--
-- Name: index_post_replacements_on_post_id_and_sequence_number; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_post_replacements_on_post_id_and_sequence_number ON public.post_replacements USING btree (post_id, sequence_number);


--
-- Name: index_post_replacements_on_post_id_and_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_post_replacements_on_post_id_and_status ON public.post_replacements USING btree (post_id, status);


--
-- Name: index_post_replacements_on_post_replacement_media_asset_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_post_replacements_on_post_replacement_media_asset_id ON public.post_replacements USING btree (post_replacement_media_asset_id);


--
-- Name: index_post_replacements_on_rejector_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_post_replacements_on_rejector_id ON public.post_replacements USING btree (rejector_id);


--
-- Name: index_post_sets_on_post_ids; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_post_sets_on_post_ids ON public.post_sets USING gin (post_ids);


--
-- Name: index_post_sets_on_updater_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_post_sets_on_updater_id ON public.post_sets USING btree (updater_id);


--
-- Name: index_post_versions_on_post_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_post_versions_on_post_id ON public.post_versions USING btree (post_id);


--
-- Name: index_post_versions_on_updated_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_post_versions_on_updated_at ON public.post_versions USING btree (updated_at);


--
-- Name: index_post_versions_on_updater_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_post_versions_on_updater_id ON public.post_versions USING btree (updater_id);


--
-- Name: index_post_versions_on_updater_ip_addr; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_post_versions_on_updater_ip_addr ON public.post_versions USING btree (updater_ip_addr);


--
-- Name: index_post_votes_on_post_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_post_votes_on_post_id ON public.post_votes USING btree (post_id);


--
-- Name: index_post_votes_on_score; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_post_votes_on_score ON public.post_votes USING btree (score);


--
-- Name: index_post_votes_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_post_votes_on_user_id ON public.post_votes USING btree (user_id);


--
-- Name: index_post_votes_on_user_id_and_post_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_post_votes_on_user_id_and_post_id ON public.post_votes USING btree (user_id, post_id);


--
-- Name: index_posts_on_change_seq; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_posts_on_change_seq ON public.posts USING btree (change_seq);


--
-- Name: index_posts_on_created_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_posts_on_created_at ON public.posts USING btree (created_at);


--
-- Name: index_posts_on_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_posts_on_id ON public.posts USING btree (id);


--
-- Name: index_posts_on_is_flagged; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_posts_on_is_flagged ON public.posts USING btree (is_flagged) WHERE (is_flagged = true);


--
-- Name: index_posts_on_is_pending; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_posts_on_is_pending ON public.posts USING btree (is_pending) WHERE (is_pending = true);


--
-- Name: index_posts_on_parent_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_posts_on_parent_id ON public.posts USING btree (parent_id);


--
-- Name: index_posts_on_string_to_array_tag_string; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_posts_on_string_to_array_tag_string ON public.posts USING gin (string_to_array(tag_string, ' '::text));
ALTER INDEX public.index_posts_on_string_to_array_tag_string ALTER COLUMN 1 SET STATISTICS 3000;


--
-- Name: index_posts_on_updater_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_posts_on_updater_id ON public.posts USING btree (updater_id);


--
-- Name: index_posts_on_upload_media_asset_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_posts_on_upload_media_asset_id ON public.posts USING btree (upload_media_asset_id);


--
-- Name: index_posts_on_uploader_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_posts_on_uploader_id ON public.posts USING btree (uploader_id);


--
-- Name: index_posts_on_uploader_ip_addr; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_posts_on_uploader_ip_addr ON public.posts USING btree (uploader_ip_addr);


--
-- Name: index_quick_rules_on_creator_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_quick_rules_on_creator_id ON public.quick_rules USING btree (creator_id);


--
-- Name: index_quick_rules_on_order; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_quick_rules_on_order ON public.quick_rules USING btree ("order");


--
-- Name: index_quick_rules_on_rule_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_quick_rules_on_rule_id ON public.quick_rules USING btree (rule_id);


--
-- Name: index_quick_rules_on_updater_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_quick_rules_on_updater_id ON public.quick_rules USING btree (updater_id);


--
-- Name: index_rule_categories_on_creator_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_rule_categories_on_creator_id ON public.rule_categories USING btree (creator_id);


--
-- Name: index_rule_categories_on_lower_name; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_rule_categories_on_lower_name ON public.rule_categories USING btree (lower((name)::text));


--
-- Name: index_rule_categories_on_order; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_rule_categories_on_order ON public.rule_categories USING btree ("order");


--
-- Name: index_rule_categories_on_updater_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_rule_categories_on_updater_id ON public.rule_categories USING btree (updater_id);


--
-- Name: index_rules_on_category_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_rules_on_category_id ON public.rules USING btree (category_id);


--
-- Name: index_rules_on_creator_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_rules_on_creator_id ON public.rules USING btree (creator_id);


--
-- Name: index_rules_on_lower_name; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_rules_on_lower_name ON public.rules USING btree (lower((name)::text));


--
-- Name: index_rules_on_order_and_category_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_rules_on_order_and_category_id ON public.rules USING btree ("order", category_id);


--
-- Name: index_rules_on_updater_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_rules_on_updater_id ON public.rules USING btree (updater_id);


--
-- Name: index_staff_audit_logs_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_staff_audit_logs_on_user_id ON public.staff_audit_logs USING btree (user_id);


--
-- Name: index_staff_notes_on_creator_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_staff_notes_on_creator_id ON public.staff_notes USING btree (creator_id);


--
-- Name: index_staff_notes_on_updater_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_staff_notes_on_updater_id ON public.staff_notes USING btree (updater_id);


--
-- Name: index_staff_notes_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_staff_notes_on_user_id ON public.staff_notes USING btree (user_id);


--
-- Name: index_tag_aliases_on_antecedent_name; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_tag_aliases_on_antecedent_name ON public.tag_aliases USING btree (antecedent_name);


--
-- Name: index_tag_aliases_on_antecedent_name_pattern; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_tag_aliases_on_antecedent_name_pattern ON public.tag_aliases USING btree (antecedent_name text_pattern_ops);


--
-- Name: index_tag_aliases_on_consequent_name; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_tag_aliases_on_consequent_name ON public.tag_aliases USING btree (consequent_name);


--
-- Name: index_tag_aliases_on_forum_post_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_tag_aliases_on_forum_post_id ON public.tag_aliases USING btree (forum_post_id);


--
-- Name: index_tag_aliases_on_post_count; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_tag_aliases_on_post_count ON public.tag_aliases USING btree (post_count);


--
-- Name: index_tag_aliases_on_updater_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_tag_aliases_on_updater_id ON public.tag_aliases USING btree (updater_id);


--
-- Name: index_tag_followers_on_last_post_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_tag_followers_on_last_post_id ON public.tag_followers USING btree (last_post_id);


--
-- Name: index_tag_followers_on_tag_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_tag_followers_on_tag_id ON public.tag_followers USING btree (tag_id);


--
-- Name: index_tag_followers_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_tag_followers_on_user_id ON public.tag_followers USING btree (user_id);


--
-- Name: index_tag_implications_on_antecedent_name; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_tag_implications_on_antecedent_name ON public.tag_implications USING btree (antecedent_name);


--
-- Name: index_tag_implications_on_consequent_name; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_tag_implications_on_consequent_name ON public.tag_implications USING btree (consequent_name);


--
-- Name: index_tag_implications_on_forum_post_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_tag_implications_on_forum_post_id ON public.tag_implications USING btree (forum_post_id);


--
-- Name: index_tag_implications_on_updater_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_tag_implications_on_updater_id ON public.tag_implications USING btree (updater_id);


--
-- Name: index_tag_rel_undos_on_tag_rel_type_and_tag_rel_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_tag_rel_undos_on_tag_rel_type_and_tag_rel_id ON public.tag_rel_undos USING btree (tag_rel_type, tag_rel_id);


--
-- Name: index_tag_versions_on_tag_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_tag_versions_on_tag_id ON public.tag_versions USING btree (tag_id);


--
-- Name: index_tag_versions_on_updater_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_tag_versions_on_updater_id ON public.tag_versions USING btree (updater_id);


--
-- Name: index_tags_on_creator_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_tags_on_creator_id ON public.tags USING btree (creator_id);


--
-- Name: index_tags_on_name; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_tags_on_name ON public.tags USING btree (name);


--
-- Name: index_tags_on_name_pattern; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_tags_on_name_pattern ON public.tags USING btree (name text_pattern_ops);


--
-- Name: index_tags_on_name_prefix; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_tags_on_name_prefix ON public.tags USING gin (regexp_replace((name)::text, '([a-z0-9])[a-z0-9'']*($|[^a-z0-9'']+)'::text, '\1'::text, 'g'::text) public.gin_trgm_ops);


--
-- Name: index_tags_on_name_trgm; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_tags_on_name_trgm ON public.tags USING gin (name public.gin_trgm_ops);


--
-- Name: index_takedowns_on_updater_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_takedowns_on_updater_id ON public.takedowns USING btree (updater_id);


--
-- Name: index_upload_media_assets_on_checksum; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_upload_media_assets_on_checksum ON public.upload_media_assets USING btree (checksum);


--
-- Name: index_upload_media_assets_on_creator_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_upload_media_assets_on_creator_id ON public.upload_media_assets USING btree (creator_id);


--
-- Name: index_upload_media_assets_on_md5; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_upload_media_assets_on_md5 ON public.upload_media_assets USING btree (md5) WHERE ((status)::text = 'active'::text);


--
-- Name: index_upload_media_assets_on_media_metadata_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_upload_media_assets_on_media_metadata_id ON public.upload_media_assets USING btree (media_metadata_id);


--
-- Name: index_upload_media_assets_on_pixel_hash; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_upload_media_assets_on_pixel_hash ON public.upload_media_assets USING btree (pixel_hash);


--
-- Name: index_upload_whitelists_on_creator_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_upload_whitelists_on_creator_id ON public.upload_whitelists USING btree (creator_id);


--
-- Name: index_upload_whitelists_on_pattern; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_upload_whitelists_on_pattern ON public.upload_whitelists USING btree (pattern);


--
-- Name: index_upload_whitelists_on_updater_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_upload_whitelists_on_updater_id ON public.upload_whitelists USING btree (updater_id);


--
-- Name: index_uploads_on_source; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_uploads_on_source ON public.uploads USING btree (source);


--
-- Name: index_uploads_on_upload_media_asset_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_uploads_on_upload_media_asset_id ON public.uploads USING btree (upload_media_asset_id);


--
-- Name: index_uploads_on_uploader_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_uploads_on_uploader_id ON public.uploads USING btree (uploader_id);


--
-- Name: index_uploads_on_uploader_ip_addr; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_uploads_on_uploader_ip_addr ON public.uploads USING btree (uploader_ip_addr);


--
-- Name: index_user_approvals_on_updater_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_user_approvals_on_updater_id ON public.user_approvals USING btree (updater_id);


--
-- Name: index_user_approvals_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_user_approvals_on_user_id ON public.user_approvals USING btree (user_id);


--
-- Name: index_user_blocks_on_target_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_user_blocks_on_target_id ON public.user_blocks USING btree (target_id);


--
-- Name: index_user_blocks_on_target_id_and_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_user_blocks_on_target_id_and_user_id ON public.user_blocks USING btree (target_id, user_id);


--
-- Name: index_user_blocks_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_user_blocks_on_user_id ON public.user_blocks USING btree (user_id);


--
-- Name: index_user_events_on_category; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_user_events_on_category ON public.user_events USING btree (category);


--
-- Name: index_user_events_on_session_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_user_events_on_session_id ON public.user_events USING btree (session_id);


--
-- Name: index_user_events_on_user_agent; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_user_events_on_user_agent ON public.user_events USING btree (user_agent);


--
-- Name: index_user_events_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_user_events_on_user_id ON public.user_events USING btree (user_id);


--
-- Name: index_user_events_on_user_ip_addr; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_user_events_on_user_ip_addr ON public.user_events USING btree (user_ip_addr);


--
-- Name: index_user_events_on_user_session_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_user_events_on_user_session_id ON public.user_events USING btree (user_session_id);


--
-- Name: index_user_feedback_on_lower_body_trgm; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_user_feedback_on_lower_body_trgm ON public.user_feedbacks USING gin (lower(body) public.gin_trgm_ops);


--
-- Name: index_user_feedback_on_to_tsvector_english_body; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_user_feedback_on_to_tsvector_english_body ON public.user_feedbacks USING gin (to_tsvector('english'::regconfig, body));


--
-- Name: index_user_feedbacks_on_created_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_user_feedbacks_on_created_at ON public.user_feedbacks USING btree (created_at);


--
-- Name: index_user_feedbacks_on_creator_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_user_feedbacks_on_creator_id ON public.user_feedbacks USING btree (creator_id);


--
-- Name: index_user_feedbacks_on_creator_ip_addr; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_user_feedbacks_on_creator_ip_addr ON public.user_feedbacks USING btree (creator_ip_addr);


--
-- Name: index_user_feedbacks_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_user_feedbacks_on_user_id ON public.user_feedbacks USING btree (user_id);


--
-- Name: index_user_lower_email; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_user_lower_email ON public.users USING btree (lower((email)::text));


--
-- Name: index_user_name_change_requests_on_creator_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_user_name_change_requests_on_creator_id ON public.user_name_change_requests USING btree (creator_id);


--
-- Name: index_user_name_change_requests_on_original_name; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_user_name_change_requests_on_original_name ON public.user_name_change_requests USING btree (original_name);


--
-- Name: index_user_name_change_requests_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_user_name_change_requests_on_user_id ON public.user_name_change_requests USING btree (user_id);


--
-- Name: index_user_sessions_on_ip_addr; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_user_sessions_on_ip_addr ON public.user_sessions USING btree (ip_addr);


--
-- Name: index_user_sessions_on_session_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_user_sessions_on_session_id ON public.user_sessions USING btree (session_id);


--
-- Name: index_user_text_versions_on_updater_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_user_text_versions_on_updater_id ON public.user_text_versions USING btree (updater_id);


--
-- Name: index_user_text_versions_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_user_text_versions_on_user_id ON public.user_text_versions USING btree (user_id);


--
-- Name: index_users_on_bit_prefs_can_approve_posts_false; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_users_on_bit_prefs_can_approve_posts_false ON public.users USING btree (id) WHERE ((bit_prefs & (256)::bigint) = 0);


--
-- Name: index_users_on_bit_prefs_can_approve_posts_true; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_users_on_bit_prefs_can_approve_posts_true ON public.users USING btree (id) WHERE ((bit_prefs & (256)::bigint) = 256);


--
-- Name: index_users_on_bit_prefs_can_manage_aibur_false; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_users_on_bit_prefs_can_manage_aibur_false ON public.users USING btree (id) WHERE ((bit_prefs & (4194304)::bigint) = 0);


--
-- Name: index_users_on_bit_prefs_can_manage_aibur_true; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_users_on_bit_prefs_can_manage_aibur_true ON public.users USING btree (id) WHERE ((bit_prefs & (4194304)::bigint) = 4194304);


--
-- Name: index_users_on_bit_prefs_enable_privacy_mode_false; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_users_on_bit_prefs_enable_privacy_mode_false ON public.users USING btree (id) WHERE ((bit_prefs & (32)::bigint) = 0);


--
-- Name: index_users_on_bit_prefs_enable_privacy_mode_true; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_users_on_bit_prefs_enable_privacy_mode_true ON public.users USING btree (id) WHERE ((bit_prefs & (32)::bigint) = 32);


--
-- Name: index_users_on_bit_prefs_unrestricted_uploads_false; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_users_on_bit_prefs_unrestricted_uploads_false ON public.users USING btree (id) WHERE ((bit_prefs & (512)::bigint) = 0);


--
-- Name: index_users_on_bit_prefs_unrestricted_uploads_true; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_users_on_bit_prefs_unrestricted_uploads_true ON public.users USING btree (id) WHERE ((bit_prefs & (512)::bigint) = 512);


--
-- Name: index_users_on_email; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_users_on_email ON public.users USING btree (email);


--
-- Name: index_users_on_last_ip_addr; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_users_on_last_ip_addr ON public.users USING btree (last_ip_addr) WHERE (last_ip_addr IS NOT NULL);


--
-- Name: index_users_on_lower_profile_about_trgm; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_users_on_lower_profile_about_trgm ON public.users USING gin (lower(profile_about) public.gin_trgm_ops);


--
-- Name: index_users_on_lower_profile_artinfo_trgm; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_users_on_lower_profile_artinfo_trgm ON public.users USING gin (lower(profile_artinfo) public.gin_trgm_ops);


--
-- Name: index_users_on_name; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_users_on_name ON public.users USING btree (lower((name)::text));


--
-- Name: index_users_on_to_tsvector_english_profile_about; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_users_on_to_tsvector_english_profile_about ON public.users USING gin (to_tsvector('english'::regconfig, profile_about));


--
-- Name: index_users_on_to_tsvector_english_profile_artinfo; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_users_on_to_tsvector_english_profile_artinfo ON public.users USING gin (to_tsvector('english'::regconfig, profile_artinfo));


--
-- Name: index_wiki_page_versions_on_created_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_wiki_page_versions_on_created_at ON public.wiki_page_versions USING btree (created_at);


--
-- Name: index_wiki_page_versions_on_merged_from_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_wiki_page_versions_on_merged_from_id ON public.wiki_page_versions USING btree (merged_from_id);


--
-- Name: index_wiki_page_versions_on_updater_ip_addr; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_wiki_page_versions_on_updater_ip_addr ON public.wiki_page_versions USING btree (updater_ip_addr);


--
-- Name: index_wiki_page_versions_on_wiki_page_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_wiki_page_versions_on_wiki_page_id ON public.wiki_page_versions USING btree (wiki_page_id);


--
-- Name: index_wiki_pages_on_lower_body_trgm; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_wiki_pages_on_lower_body_trgm ON public.wiki_pages USING gin (lower(body) public.gin_trgm_ops);


--
-- Name: index_wiki_pages_on_lower_title_trgm; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_wiki_pages_on_lower_title_trgm ON public.wiki_pages USING gin (lower((title)::text) public.gin_trgm_ops);


--
-- Name: index_wiki_pages_on_title; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_wiki_pages_on_title ON public.wiki_pages USING btree (title);


--
-- Name: index_wiki_pages_on_title_pattern; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_wiki_pages_on_title_pattern ON public.wiki_pages USING btree (title text_pattern_ops);


--
-- Name: index_wiki_pages_on_to_tsvector_english_body; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_wiki_pages_on_to_tsvector_english_body ON public.wiki_pages USING gin (to_tsvector('english'::regconfig, body));


--
-- Name: index_wiki_pages_on_updated_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_wiki_pages_on_updated_at ON public.wiki_pages USING btree (updated_at);


--
-- Name: posts posts_update_change_seq; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER posts_update_change_seq BEFORE UPDATE ON public.posts FOR EACH ROW EXECUTE FUNCTION public.posts_trigger_change_seq();


--
-- Name: tag_aliases fk_rails_0157a2fd88; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tag_aliases
    ADD CONSTRAINT fk_rails_0157a2fd88 FOREIGN KEY (creator_id) REFERENCES public.users(id);


--
-- Name: post_replacements fk_rails_021e64be42; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.post_replacements
    ADD CONSTRAINT fk_rails_021e64be42 FOREIGN KEY (approver_id) REFERENCES public.users(id);


--
-- Name: staff_audit_logs fk_rails_02329e5ef9; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.staff_audit_logs
    ADD CONSTRAINT fk_rails_02329e5ef9 FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: bulk_update_requests fk_rails_02aba1d3e0; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.bulk_update_requests
    ADD CONSTRAINT fk_rails_02aba1d3e0 FOREIGN KEY (creator_id) REFERENCES public.users(id);


--
-- Name: tickets fk_rails_0320cb2c4e; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tickets
    ADD CONSTRAINT fk_rails_0320cb2c4e FOREIGN KEY (creator_id) REFERENCES public.users(id);


--
-- Name: destroyed_posts fk_rails_055f35f666; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.destroyed_posts
    ADD CONSTRAINT fk_rails_055f35f666 FOREIGN KEY (uploader_id) REFERENCES public.users(id);


--
-- Name: bans fk_rails_070022cd76; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.bans
    ADD CONSTRAINT fk_rails_070022cd76 FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: comment_votes fk_rails_0873e64a40; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.comment_votes
    ADD CONSTRAINT fk_rails_0873e64a40 FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: posts fk_rails_087c1f7550; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.posts
    ADD CONSTRAINT fk_rails_087c1f7550 FOREIGN KEY (updater_id) REFERENCES public.users(id);


--
-- Name: bulk_update_request_imports fk_rails_08b1320e63; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.bulk_update_request_imports
    ADD CONSTRAINT fk_rails_08b1320e63 FOREIGN KEY (updater_id) REFERENCES public.users(id);


--
-- Name: posts fk_rails_0a1365d9c4; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.posts
    ADD CONSTRAINT fk_rails_0a1365d9c4 FOREIGN KEY (upload_media_asset_id) REFERENCES public.upload_media_assets(id);


--
-- Name: help_pages fk_rails_0a25bf2cb5; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.help_pages
    ADD CONSTRAINT fk_rails_0a25bf2cb5 FOREIGN KEY (wiki_page_id) REFERENCES public.wiki_pages(id);


--
-- Name: tag_followers fk_rails_0a453c2219; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tag_followers
    ADD CONSTRAINT fk_rails_0a453c2219 FOREIGN KEY (last_post_id) REFERENCES public.posts(id);


--
-- Name: help_pages fk_rails_10de26473a; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.help_pages
    ADD CONSTRAINT fk_rails_10de26473a FOREIGN KEY (updater_id) REFERENCES public.users(id);


--
-- Name: tag_followers fk_rails_12486be0da; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tag_followers
    ADD CONSTRAINT fk_rails_12486be0da FOREIGN KEY (tag_id) REFERENCES public.tags(id);


--
-- Name: uploads fk_rails_127111e6ac; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.uploads
    ADD CONSTRAINT fk_rails_127111e6ac FOREIGN KEY (post_id) REFERENCES public.posts(id);


--
-- Name: bulk_update_request_imports fk_rails_132718aca7; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.bulk_update_request_imports
    ADD CONSTRAINT fk_rails_132718aca7 FOREIGN KEY (forum_topic_id) REFERENCES public.forum_topics(id);


--
-- Name: post_replacement_media_assets fk_rails_14a51f0bf4; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.post_replacement_media_assets
    ADD CONSTRAINT fk_rails_14a51f0bf4 FOREIGN KEY (creator_id) REFERENCES public.users(id);


--
-- Name: user_text_versions fk_rails_14b63528c4; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_text_versions
    ADD CONSTRAINT fk_rails_14b63528c4 FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: post_replacements fk_rails_15e768a414; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.post_replacements
    ADD CONSTRAINT fk_rails_15e768a414 FOREIGN KEY (post_replacement_media_asset_id) REFERENCES public.post_replacement_media_assets(id);


--
-- Name: takedowns fk_rails_168424c541; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.takedowns
    ADD CONSTRAINT fk_rails_168424c541 FOREIGN KEY (creator_id) REFERENCES public.users(id);


--
-- Name: tags fk_rails_187412be99; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tags
    ADD CONSTRAINT fk_rails_187412be99 FOREIGN KEY (creator_id) REFERENCES public.users(id);


--
-- Name: user_name_change_requests fk_rails_18d9682b1c; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_name_change_requests
    ADD CONSTRAINT fk_rails_18d9682b1c FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: avoid_posting_versions fk_rails_1d1f54e17a; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.avoid_posting_versions
    ADD CONSTRAINT fk_rails_1d1f54e17a FOREIGN KEY (updater_id) REFERENCES public.users(id);


--
-- Name: post_deletion_reasons fk_rails_1d9b3de04b; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.post_deletion_reasons
    ADD CONSTRAINT fk_rails_1d9b3de04b FOREIGN KEY (creator_id) REFERENCES public.users(id);


--
-- Name: wiki_pages fk_rails_1ea2b5ff6b; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.wiki_pages
    ADD CONSTRAINT fk_rails_1ea2b5ff6b FOREIGN KEY (creator_id) REFERENCES public.users(id);


--
-- Name: rule_categories fk_rails_21909079f3; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.rule_categories
    ADD CONSTRAINT fk_rails_21909079f3 FOREIGN KEY (creator_id) REFERENCES public.users(id);


--
-- Name: bans fk_rails_2234692cb1; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.bans
    ADD CONSTRAINT fk_rails_2234692cb1 FOREIGN KEY (banner_id) REFERENCES public.users(id);


--
-- Name: upload_whitelists fk_rails_2258ca913d; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.upload_whitelists
    ADD CONSTRAINT fk_rails_2258ca913d FOREIGN KEY (updater_id) REFERENCES public.users(id);


--
-- Name: forum_topic_statuses fk_rails_228ffc67d5; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.forum_topic_statuses
    ADD CONSTRAINT fk_rails_228ffc67d5 FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: bulk_update_requests fk_rails_22b3b2a525; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.bulk_update_requests
    ADD CONSTRAINT fk_rails_22b3b2a525 FOREIGN KEY (forum_post_id) REFERENCES public.forum_posts(id) ON DELETE SET NULL;


--
-- Name: dmails fk_rails_22dbb958ad; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.dmails
    ADD CONSTRAINT fk_rails_22dbb958ad FOREIGN KEY (from_id) REFERENCES public.users(id);


--
-- Name: rules fk_rails_272189fc55; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.rules
    ADD CONSTRAINT fk_rails_272189fc55 FOREIGN KEY (creator_id) REFERENCES public.users(id);


--
-- Name: post_appeals fk_rails_2794bb6745; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.post_appeals
    ADD CONSTRAINT fk_rails_2794bb6745 FOREIGN KEY (creator_id) REFERENCES public.users(id);


--
-- Name: post_replacements fk_rails_286111af77; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.post_replacements
    ADD CONSTRAINT fk_rails_286111af77 FOREIGN KEY (post_id) REFERENCES public.posts(id);


--
-- Name: mod_actions fk_rails_290059ebb5; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.mod_actions
    ADD CONSTRAINT fk_rails_290059ebb5 FOREIGN KEY (creator_id) REFERENCES public.users(id);


--
-- Name: posts fk_rails_299f071108; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.posts
    ADD CONSTRAINT fk_rails_299f071108 FOREIGN KEY (uploader_id) REFERENCES public.users(id);


--
-- Name: forum_categories fk_rails_2ad0fcb4ad; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.forum_categories
    ADD CONSTRAINT fk_rails_2ad0fcb4ad FOREIGN KEY (creator_id) REFERENCES public.users(id);


--
-- Name: mascot_media_assets fk_rails_2c1fc79c52; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.mascot_media_assets
    ADD CONSTRAINT fk_rails_2c1fc79c52 FOREIGN KEY (media_metadata_id) REFERENCES public.media_metadata(id);


--
-- Name: forum_posts fk_rails_2ddd2b5687; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.forum_posts
    ADD CONSTRAINT fk_rails_2ddd2b5687 FOREIGN KEY (topic_id) REFERENCES public.forum_topics(id);


--
-- Name: tag_versions fk_rails_2e7ebfd4dd; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tag_versions
    ADD CONSTRAINT fk_rails_2e7ebfd4dd FOREIGN KEY (tag_id) REFERENCES public.tags(id);


--
-- Name: wiki_page_versions fk_rails_2fc7c35d5a; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.wiki_page_versions
    ADD CONSTRAINT fk_rails_2fc7c35d5a FOREIGN KEY (wiki_page_id) REFERENCES public.wiki_pages(id);


--
-- Name: comments fk_rails_2fd19c0db7; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.comments
    ADD CONSTRAINT fk_rails_2fd19c0db7 FOREIGN KEY (post_id) REFERENCES public.posts(id);


--
-- Name: api_keys fk_rails_32c28d0dc2; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.api_keys
    ADD CONSTRAINT fk_rails_32c28d0dc2 FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: uploads fk_rails_36fad23424; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.uploads
    ADD CONSTRAINT fk_rails_36fad23424 FOREIGN KEY (upload_media_asset_id) REFERENCES public.upload_media_assets(id);


--
-- Name: tag_versions fk_rails_373a0aa141; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tag_versions
    ADD CONSTRAINT fk_rails_373a0aa141 FOREIGN KEY (updater_id) REFERENCES public.users(id);


--
-- Name: forum_posts fk_rails_37bba5409c; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.forum_posts
    ADD CONSTRAINT fk_rails_37bba5409c FOREIGN KEY (warning_user_id) REFERENCES public.users(id);


--
-- Name: post_replacements fk_rails_3ddcb25767; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.post_replacements
    ADD CONSTRAINT fk_rails_3ddcb25767 FOREIGN KEY (creator_id) REFERENCES public.users(id);


--
-- Name: email_blacklists fk_rails_400153925a; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.email_blacklists
    ADD CONSTRAINT fk_rails_400153925a FOREIGN KEY (creator_id) REFERENCES public.users(id);


--
-- Name: post_disapprovals fk_rails_408a205f48; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.post_disapprovals
    ADD CONSTRAINT fk_rails_408a205f48 FOREIGN KEY (post_id) REFERENCES public.posts(id);


--
-- Name: post_appeals fk_rails_4153b9e5a4; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.post_appeals
    ADD CONSTRAINT fk_rails_4153b9e5a4 FOREIGN KEY (post_id) REFERENCES public.posts(id);


--
-- Name: user_events fk_rails_41fefee740; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_events
    ADD CONSTRAINT fk_rails_41fefee740 FOREIGN KEY (user_session_id) REFERENCES public.user_sessions(id);


--
-- Name: user_approvals fk_rails_43c6809d8a; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_approvals
    ADD CONSTRAINT fk_rails_43c6809d8a FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: tag_followers fk_rails_452fb80809; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tag_followers
    ADD CONSTRAINT fk_rails_452fb80809 FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: tickets fk_rails_45cd696dba; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tickets
    ADD CONSTRAINT fk_rails_45cd696dba FOREIGN KEY (accused_id) REFERENCES public.users(id);


--
-- Name: forum_topics fk_rails_462bff5325; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.forum_topics
    ADD CONSTRAINT fk_rails_462bff5325 FOREIGN KEY (category_id) REFERENCES public.forum_categories(id);


--
-- Name: dmails fk_rails_46910c4d2c; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.dmails
    ADD CONSTRAINT fk_rails_46910c4d2c FOREIGN KEY (to_id) REFERENCES public.users(id);


--
-- Name: forum_post_votes fk_rails_46ac054a95; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.forum_post_votes
    ADD CONSTRAINT fk_rails_46ac054a95 FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: post_appeals fk_rails_47c5198d12; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.post_appeals
    ADD CONSTRAINT fk_rails_47c5198d12 FOREIGN KEY (updater_id) REFERENCES public.users(id);


--
-- Name: rules fk_rails_48ba033e3f; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.rules
    ADD CONSTRAINT fk_rails_48ba033e3f FOREIGN KEY (updater_id) REFERENCES public.users(id);


--
-- Name: wiki_pages fk_rails_49594bc61f; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.wiki_pages
    ADD CONSTRAINT fk_rails_49594bc61f FOREIGN KEY (updater_id) REFERENCES public.users(id);


--
-- Name: post_flags fk_rails_4a92b4b725; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.post_flags
    ADD CONSTRAINT fk_rails_4a92b4b725 FOREIGN KEY (post_id) REFERENCES public.posts(id);


--
-- Name: comments fk_rails_4b8a638a8b; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.comments
    ADD CONSTRAINT fk_rails_4b8a638a8b FOREIGN KEY (creator_id) REFERENCES public.users(id);


--
-- Name: avoid_posting_versions fk_rails_4c48affea5; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.avoid_posting_versions
    ADD CONSTRAINT fk_rails_4c48affea5 FOREIGN KEY (avoid_posting_id) REFERENCES public.avoid_postings(id);


--
-- Name: post_approvals fk_rails_4cda56c76c; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.post_approvals
    ADD CONSTRAINT fk_rails_4cda56c76c FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: artists fk_rails_4e3f72966d; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.artists
    ADD CONSTRAINT fk_rails_4e3f72966d FOREIGN KEY (creator_id) REFERENCES public.users(id);


--
-- Name: news_updates fk_rails_502e0a41d1; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.news_updates
    ADD CONSTRAINT fk_rails_502e0a41d1 FOREIGN KEY (updater_id) REFERENCES public.users(id);


--
-- Name: post_replacements fk_rails_5283f71ca8; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.post_replacements
    ADD CONSTRAINT fk_rails_5283f71ca8 FOREIGN KEY (uploader_id_on_approve) REFERENCES public.users(id);


--
-- Name: forum_topics fk_rails_53d4e863cd; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.forum_topics
    ADD CONSTRAINT fk_rails_53d4e863cd FOREIGN KEY (updater_id) REFERENCES public.users(id);


--
-- Name: user_approvals fk_rails_5575a00260; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_approvals
    ADD CONSTRAINT fk_rails_5575a00260 FOREIGN KEY (updater_id) REFERENCES public.users(id);


--
-- Name: tag_implications fk_rails_567423c3a3; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tag_implications
    ADD CONSTRAINT fk_rails_567423c3a3 FOREIGN KEY (approver_id) REFERENCES public.users(id);


--
-- Name: comments fk_rails_56c1cf09bc; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.comments
    ADD CONSTRAINT fk_rails_56c1cf09bc FOREIGN KEY (updater_id) REFERENCES public.users(id);


--
-- Name: rule_categories fk_rails_599a487368; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.rule_categories
    ADD CONSTRAINT fk_rails_599a487368 FOREIGN KEY (updater_id) REFERENCES public.users(id);


--
-- Name: forum_posts fk_rails_5badbb08d8; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.forum_posts
    ADD CONSTRAINT fk_rails_5badbb08d8 FOREIGN KEY (creator_id) REFERENCES public.users(id);


--
-- Name: forum_post_votes fk_rails_5c3f90ef3f; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.forum_post_votes
    ADD CONSTRAINT fk_rails_5c3f90ef3f FOREIGN KEY (forum_post_id) REFERENCES public.forum_posts(id);


--
-- Name: notes fk_rails_5d4a723a34; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.notes
    ADD CONSTRAINT fk_rails_5d4a723a34 FOREIGN KEY (creator_id) REFERENCES public.users(id);


--
-- Name: post_versions fk_rails_5f7c4b6bbb; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.post_versions
    ADD CONSTRAINT fk_rails_5f7c4b6bbb FOREIGN KEY (post_id) REFERENCES public.posts(id);


--
-- Name: post_set_maintainers fk_rails_5fdbb10ec8; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.post_set_maintainers
    ADD CONSTRAINT fk_rails_5fdbb10ec8 FOREIGN KEY (post_set_id) REFERENCES public.post_sets(id);


--
-- Name: note_versions fk_rails_611f87a5ae; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.note_versions
    ADD CONSTRAINT fk_rails_611f87a5ae FOREIGN KEY (note_id) REFERENCES public.notes(id);


--
-- Name: rules fk_rails_62bf5195cf; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.rules
    ADD CONSTRAINT fk_rails_62bf5195cf FOREIGN KEY (category_id) REFERENCES public.rule_categories(id);


--
-- Name: mascots fk_rails_6373694140; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.mascots
    ADD CONSTRAINT fk_rails_6373694140 FOREIGN KEY (updater_id) REFERENCES public.users(id);


--
-- Name: dmails fk_rails_64867f7932; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.dmails
    ADD CONSTRAINT fk_rails_64867f7932 FOREIGN KEY (respond_to_id) REFERENCES public.users(id);


--
-- Name: users fk_rails_6527170f4d; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT fk_rails_6527170f4d FOREIGN KEY (avatar_id) REFERENCES public.posts(id);


--
-- Name: user_name_change_requests fk_rails_664bf0839b; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_name_change_requests
    ADD CONSTRAINT fk_rails_664bf0839b FOREIGN KEY (approver_id) REFERENCES public.users(id);


--
-- Name: post_flags fk_rails_68fe8072b5; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.post_flags
    ADD CONSTRAINT fk_rails_68fe8072b5 FOREIGN KEY (creator_id) REFERENCES public.users(id);


--
-- Name: dmail_filters fk_rails_6a7e17c8ba; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.dmail_filters
    ADD CONSTRAINT fk_rails_6a7e17c8ba FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: post_set_maintainers fk_rails_6b31c178f0; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.post_set_maintainers
    ADD CONSTRAINT fk_rails_6b31c178f0 FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: user_events fk_rails_717ccf5f73; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_events
    ADD CONSTRAINT fk_rails_717ccf5f73 FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: note_versions fk_rails_71b80cd026; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.note_versions
    ADD CONSTRAINT fk_rails_71b80cd026 FOREIGN KEY (post_id) REFERENCES public.posts(id);


--
-- Name: ip_bans fk_rails_73e3027d29; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ip_bans
    ADD CONSTRAINT fk_rails_73e3027d29 FOREIGN KEY (creator_id) REFERENCES public.users(id);


--
-- Name: mascots fk_rails_73ec62c5c5; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.mascots
    ADD CONSTRAINT fk_rails_73ec62c5c5 FOREIGN KEY (mascot_media_asset_id) REFERENCES public.mascot_media_assets(id);


--
-- Name: post_approvals fk_rails_74f76ef71e; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.post_approvals
    ADD CONSTRAINT fk_rails_74f76ef71e FOREIGN KEY (post_id) REFERENCES public.posts(id);


--
-- Name: user_feedbacks fk_rails_78967910a0; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_feedbacks
    ADD CONSTRAINT fk_rails_78967910a0 FOREIGN KEY (creator_id) REFERENCES public.users(id);


--
-- Name: post_versions fk_rails_7a0eb97ff1; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.post_versions
    ADD CONSTRAINT fk_rails_7a0eb97ff1 FOREIGN KEY (updater_id) REFERENCES public.users(id);


--
-- Name: takedowns fk_rails_81949de190; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.takedowns
    ADD CONSTRAINT fk_rails_81949de190 FOREIGN KEY (approver_id) REFERENCES public.users(id);


--
-- Name: bulk_update_requests fk_rails_87084cb039; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.bulk_update_requests
    ADD CONSTRAINT fk_rails_87084cb039 FOREIGN KEY (approver_id) REFERENCES public.users(id);


--
-- Name: tag_aliases fk_rails_90fd158a45; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tag_aliases
    ADD CONSTRAINT fk_rails_90fd158a45 FOREIGN KEY (forum_topic_id) REFERENCES public.forum_topics(id) ON DELETE SET NULL;


--
-- Name: edit_histories fk_rails_92d53c2439; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.edit_histories
    ADD CONSTRAINT fk_rails_92d53c2439 FOREIGN KEY (updater_id) REFERENCES public.users(id);


--
-- Name: user_feedbacks fk_rails_9329a36823; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_feedbacks
    ADD CONSTRAINT fk_rails_9329a36823 FOREIGN KEY (updater_id) REFERENCES public.users(id);


--
-- Name: bulk_update_request_imports fk_rails_9460e9eacc; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.bulk_update_request_imports
    ADD CONSTRAINT fk_rails_9460e9eacc FOREIGN KEY (creator_id) REFERENCES public.users(id);


--
-- Name: post_replacement_rejection_reasons fk_rails_95ac45c762; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.post_replacement_rejection_reasons
    ADD CONSTRAINT fk_rails_95ac45c762 FOREIGN KEY (creator_id) REFERENCES public.users(id);


--
-- Name: mascots fk_rails_9901e810fa; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.mascots
    ADD CONSTRAINT fk_rails_9901e810fa FOREIGN KEY (creator_id) REFERENCES public.users(id);


--
-- Name: post_sets fk_rails_9d358f9c61; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.post_sets
    ADD CONSTRAINT fk_rails_9d358f9c61 FOREIGN KEY (creator_id) REFERENCES public.users(id);


--
-- Name: upload_media_assets fk_rails_9d505dc8fb; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.upload_media_assets
    ADD CONSTRAINT fk_rails_9d505dc8fb FOREIGN KEY (creator_id) REFERENCES public.users(id);


--
-- Name: comment_votes fk_rails_a0196e2ef9; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.comment_votes
    ADD CONSTRAINT fk_rails_a0196e2ef9 FOREIGN KEY (comment_id) REFERENCES public.comments(id);


--
-- Name: forum_topics fk_rails_a0e236112e; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.forum_topics
    ADD CONSTRAINT fk_rails_a0e236112e FOREIGN KEY (creator_id) REFERENCES public.users(id);


--
-- Name: notes fk_rails_a167a78679; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.notes
    ADD CONSTRAINT fk_rails_a167a78679 FOREIGN KEY (post_id) REFERENCES public.posts(id);


--
-- Name: artists fk_rails_a35f3bc56d; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.artists
    ADD CONSTRAINT fk_rails_a35f3bc56d FOREIGN KEY (linked_user_id) REFERENCES public.users(id);


--
-- Name: user_password_reset_nonces fk_rails_a3abea38bd; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_password_reset_nonces
    ADD CONSTRAINT fk_rails_a3abea38bd FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: quick_rules fk_rails_a512afa9bf; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.quick_rules
    ADD CONSTRAINT fk_rails_a512afa9bf FOREIGN KEY (rule_id) REFERENCES public.rules(id);


--
-- Name: forum_category_visits fk_rails_a66488d470; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.forum_category_visits
    ADD CONSTRAINT fk_rails_a66488d470 FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: user_text_versions fk_rails_a72e6f79a8; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_text_versions
    ADD CONSTRAINT fk_rails_a72e6f79a8 FOREIGN KEY (updater_id) REFERENCES public.users(id);


--
-- Name: favorites fk_rails_a7668ef613; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.favorites
    ADD CONSTRAINT fk_rails_a7668ef613 FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: tag_implications fk_rails_aa452a83e5; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tag_implications
    ADD CONSTRAINT fk_rails_aa452a83e5 FOREIGN KEY (creator_id) REFERENCES public.users(id);


--
-- Name: destroyed_posts fk_rails_ab76c3c44e; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.destroyed_posts
    ADD CONSTRAINT fk_rails_ab76c3c44e FOREIGN KEY (destroyer_id) REFERENCES public.users(id);


--
-- Name: bulk_update_requests fk_rails_ad41b77f74; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.bulk_update_requests
    ADD CONSTRAINT fk_rails_ad41b77f74 FOREIGN KEY (forum_topic_id) REFERENCES public.forum_topics(id) ON DELETE SET NULL;


--
-- Name: pools fk_rails_ad7dc8a6af; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pools
    ADD CONSTRAINT fk_rails_ad7dc8a6af FOREIGN KEY (cover_post_id) REFERENCES public.posts(id);


--
-- Name: notifications fk_rails_b080fb4855; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.notifications
    ADD CONSTRAINT fk_rails_b080fb4855 FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: pools fk_rails_b13feac396; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pools
    ADD CONSTRAINT fk_rails_b13feac396 FOREIGN KEY (creator_id) REFERENCES public.users(id);


--
-- Name: pool_versions fk_rails_b14c9ef3fd; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pool_versions
    ADD CONSTRAINT fk_rails_b14c9ef3fd FOREIGN KEY (updater_id) REFERENCES public.users(id);


--
-- Name: tickets fk_rails_b15b1ff6f5; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tickets
    ADD CONSTRAINT fk_rails_b15b1ff6f5 FOREIGN KEY (handler_id) REFERENCES public.users(id);


--
-- Name: user_name_change_requests fk_rails_b19a1d6239; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_name_change_requests
    ADD CONSTRAINT fk_rails_b19a1d6239 FOREIGN KEY (creator_id) REFERENCES public.users(id);


--
-- Name: artist_versions fk_rails_b1cda9510c; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.artist_versions
    ADD CONSTRAINT fk_rails_b1cda9510c FOREIGN KEY (artist_id) REFERENCES public.artists(id);


--
-- Name: avoid_postings fk_rails_b2ebf2bc30; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.avoid_postings
    ADD CONSTRAINT fk_rails_b2ebf2bc30 FOREIGN KEY (artist_id) REFERENCES public.artists(id);


--
-- Name: bulk_update_request_versions fk_rails_b49b8f1b85; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.bulk_update_request_versions
    ADD CONSTRAINT fk_rails_b49b8f1b85 FOREIGN KEY (updater_id) REFERENCES public.users(id);


--
-- Name: post_deletion_reasons fk_rails_b52713e204; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.post_deletion_reasons
    ADD CONSTRAINT fk_rails_b52713e204 FOREIGN KEY (updater_id) REFERENCES public.users(id);


--
-- Name: post_votes fk_rails_b550730fb8; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.post_votes
    ADD CONSTRAINT fk_rails_b550730fb8 FOREIGN KEY (post_id) REFERENCES public.posts(id);


--
-- Name: staff_notes fk_rails_bab7e2d92a; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.staff_notes
    ADD CONSTRAINT fk_rails_bab7e2d92a FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: post_replacement_media_assets fk_rails_bbe64e4056; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.post_replacement_media_assets
    ADD CONSTRAINT fk_rails_bbe64e4056 FOREIGN KEY (media_metadata_id) REFERENCES public.media_metadata(id);


--
-- Name: takedowns fk_rails_bcce0f9528; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.takedowns
    ADD CONSTRAINT fk_rails_bcce0f9528 FOREIGN KEY (updater_id) REFERENCES public.users(id);


--
-- Name: post_events fk_rails_bd327ccee6; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.post_events
    ADD CONSTRAINT fk_rails_bd327ccee6 FOREIGN KEY (creator_id) REFERENCES public.users(id);


--
-- Name: tag_implications fk_rails_bec6ee1cbe; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tag_implications
    ADD CONSTRAINT fk_rails_bec6ee1cbe FOREIGN KEY (forum_post_id) REFERENCES public.forum_posts(id) ON DELETE SET NULL;


--
-- Name: news_updates fk_rails_c008307ac5; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.news_updates
    ADD CONSTRAINT fk_rails_c008307ac5 FOREIGN KEY (creator_id) REFERENCES public.users(id);


--
-- Name: forum_topic_statuses fk_rails_c1a67d4773; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.forum_topic_statuses
    ADD CONSTRAINT fk_rails_c1a67d4773 FOREIGN KEY (forum_topic_id) REFERENCES public.forum_topics(id);


--
-- Name: dmails fk_rails_c303efc12e; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.dmails
    ADD CONSTRAINT fk_rails_c303efc12e FOREIGN KEY (owner_id) REFERENCES public.users(id);


--
-- Name: tag_aliases fk_rails_c6bacf1da2; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tag_aliases
    ADD CONSTRAINT fk_rails_c6bacf1da2 FOREIGN KEY (updater_id) REFERENCES public.users(id);


--
-- Name: wiki_page_versions fk_rails_c6ed6113f4; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.wiki_page_versions
    ADD CONSTRAINT fk_rails_c6ed6113f4 FOREIGN KEY (updater_id) REFERENCES public.users(id);


--
-- Name: exception_logs fk_rails_c720bf523c; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.exception_logs
    ADD CONSTRAINT fk_rails_c720bf523c FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: quick_rules fk_rails_c8bfb2cfbe; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.quick_rules
    ADD CONSTRAINT fk_rails_c8bfb2cfbe FOREIGN KEY (updater_id) REFERENCES public.users(id);


--
-- Name: tag_aliases fk_rails_ca93879f64; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tag_aliases
    ADD CONSTRAINT fk_rails_ca93879f64 FOREIGN KEY (approver_id) REFERENCES public.users(id);


--
-- Name: artist_versions fk_rails_cb0c5f540b; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.artist_versions
    ADD CONSTRAINT fk_rails_cb0c5f540b FOREIGN KEY (linked_user_id) REFERENCES public.users(id);


--
-- Name: avoid_postings fk_rails_cccc6419c8; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.avoid_postings
    ADD CONSTRAINT fk_rails_cccc6419c8 FOREIGN KEY (updater_id) REFERENCES public.users(id);


--
-- Name: post_sets fk_rails_cd0224dbf4; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.post_sets
    ADD CONSTRAINT fk_rails_cd0224dbf4 FOREIGN KEY (updater_id) REFERENCES public.users(id);


--
-- Name: upload_whitelists fk_rails_ce26e3e923; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.upload_whitelists
    ADD CONSTRAINT fk_rails_ce26e3e923 FOREIGN KEY (creator_id) REFERENCES public.users(id);


--
-- Name: favorites fk_rails_d20e53bb68; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.favorites
    ADD CONSTRAINT fk_rails_d20e53bb68 FOREIGN KEY (post_id) REFERENCES public.posts(id);


--
-- Name: user_blocks fk_rails_d2416b669a; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_blocks
    ADD CONSTRAINT fk_rails_d2416b669a FOREIGN KEY (target_id) REFERENCES public.users(id);


--
-- Name: uploads fk_rails_d29b037216; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.uploads
    ADD CONSTRAINT fk_rails_d29b037216 FOREIGN KEY (uploader_id) REFERENCES public.users(id);


--
-- Name: forum_categories fk_rails_d45c1024af; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.forum_categories
    ADD CONSTRAINT fk_rails_d45c1024af FOREIGN KEY (updater_id) REFERENCES public.users(id);


--
-- Name: avoid_postings fk_rails_d45cc0f1a1; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.avoid_postings
    ADD CONSTRAINT fk_rails_d45cc0f1a1 FOREIGN KEY (creator_id) REFERENCES public.users(id);


--
-- Name: staff_notes fk_rails_d617489f3b; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.staff_notes
    ADD CONSTRAINT fk_rails_d617489f3b FOREIGN KEY (creator_id) REFERENCES public.users(id);


--
-- Name: linked_accounts fk_rails_d68dcf73fa; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.linked_accounts
    ADD CONSTRAINT fk_rails_d68dcf73fa FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: user_blocks fk_rails_d98a90b4c8; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_blocks
    ADD CONSTRAINT fk_rails_d98a90b4c8 FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: bulk_update_requests fk_rails_da45672df5; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.bulk_update_requests
    ADD CONSTRAINT fk_rails_da45672df5 FOREIGN KEY (updater_id) REFERENCES public.users(id);


--
-- Name: tag_implications fk_rails_dba2c19f93; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tag_implications
    ADD CONSTRAINT fk_rails_dba2c19f93 FOREIGN KEY (forum_topic_id) REFERENCES public.forum_topics(id) ON DELETE SET NULL;


--
-- Name: tag_implications fk_rails_dc36b558a4; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tag_implications
    ADD CONSTRAINT fk_rails_dc36b558a4 FOREIGN KEY (updater_id) REFERENCES public.users(id);


--
-- Name: forum_category_visits fk_rails_dd0b57110c; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.forum_category_visits
    ADD CONSTRAINT fk_rails_dd0b57110c FOREIGN KEY (forum_category_id) REFERENCES public.forum_categories(id);


--
-- Name: user_feedbacks fk_rails_dd3177a5f3; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_feedbacks
    ADD CONSTRAINT fk_rails_dd3177a5f3 FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: quick_rules fk_rails_de073a1db3; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.quick_rules
    ADD CONSTRAINT fk_rails_de073a1db3 FOREIGN KEY (creator_id) REFERENCES public.users(id);


--
-- Name: post_replacements fk_rails_e2177a7d4b; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.post_replacements
    ADD CONSTRAINT fk_rails_e2177a7d4b FOREIGN KEY (rejector_id) REFERENCES public.users(id);


--
-- Name: pool_versions fk_rails_e3d7f5bb05; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pool_versions
    ADD CONSTRAINT fk_rails_e3d7f5bb05 FOREIGN KEY (pool_id) REFERENCES public.pools(id);


--
-- Name: note_versions fk_rails_e4a6971555; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.note_versions
    ADD CONSTRAINT fk_rails_e4a6971555 FOREIGN KEY (updater_id) REFERENCES public.users(id);


--
-- Name: artist_urls fk_rails_e4e6c00d41; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.artist_urls
    ADD CONSTRAINT fk_rails_e4e6c00d41 FOREIGN KEY (artist_id) REFERENCES public.artists(id);


--
-- Name: tag_aliases fk_rails_e5a732a43b; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tag_aliases
    ADD CONSTRAINT fk_rails_e5a732a43b FOREIGN KEY (forum_post_id) REFERENCES public.forum_posts(id) ON DELETE SET NULL;


--
-- Name: comments fk_rails_e60a6a2a4f; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.comments
    ADD CONSTRAINT fk_rails_e60a6a2a4f FOREIGN KEY (warning_user_id) REFERENCES public.users(id);


--
-- Name: post_disapprovals fk_rails_e6a71f8147; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.post_disapprovals
    ADD CONSTRAINT fk_rails_e6a71f8147 FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: staff_notes fk_rails_eaa7223eea; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.staff_notes
    ADD CONSTRAINT fk_rails_eaa7223eea FOREIGN KEY (updater_id) REFERENCES public.users(id);


--
-- Name: bulk_update_request_versions fk_rails_eda9d99712; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.bulk_update_request_versions
    ADD CONSTRAINT fk_rails_eda9d99712 FOREIGN KEY (bulk_update_request_id) REFERENCES public.bulk_update_requests(id);


--
-- Name: forum_posts fk_rails_eef947df00; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.forum_posts
    ADD CONSTRAINT fk_rails_eef947df00 FOREIGN KEY (updater_id) REFERENCES public.users(id);


--
-- Name: posts fk_rails_f23dabc609; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.posts
    ADD CONSTRAINT fk_rails_f23dabc609 FOREIGN KEY (approver_id) REFERENCES public.users(id);


--
-- Name: upload_media_assets fk_rails_f30297ef4e; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.upload_media_assets
    ADD CONSTRAINT fk_rails_f30297ef4e FOREIGN KEY (media_metadata_id) REFERENCES public.media_metadata(id);


--
-- Name: artist_versions fk_rails_f37d58ea23; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.artist_versions
    ADD CONSTRAINT fk_rails_f37d58ea23 FOREIGN KEY (updater_id) REFERENCES public.users(id);


--
-- Name: post_votes fk_rails_f3edc07390; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.post_votes
    ADD CONSTRAINT fk_rails_f3edc07390 FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: post_replacement_rejection_reasons fk_rails_f971dd8ed4; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.post_replacement_rejection_reasons
    ADD CONSTRAINT fk_rails_f971dd8ed4 FOREIGN KEY (updater_id) REFERENCES public.users(id);


--
-- Name: mascot_media_assets fk_rails_fec114ca06; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.mascot_media_assets
    ADD CONSTRAINT fk_rails_fec114ca06 FOREIGN KEY (creator_id) REFERENCES public.users(id);


--
-- Name: help_pages fk_rails_ff7065e97b; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.help_pages
    ADD CONSTRAINT fk_rails_ff7065e97b FOREIGN KEY (creator_id) REFERENCES public.users(id);


--
-- PostgreSQL database dump complete
--

SET search_path TO "$user", public;

INSERT INTO "schema_migrations" (version) VALUES
('20260820010000'),
('20260820000000'),
('20260819200000'),
('20260819190000'),
('20260819170000'),
('20260819160100'),
('20260819160000'),
('20260818151000'),
('20260818150000'),
('20260818140000'),
('20260717130000'),
('20260717120000'),
('20260717023930'),
('20260714101404'),
('20260713005427'),
('20260509060732'),
('20260508155823'),
('20260217212220'),
('20251227053741'),
('20251027050630'),
('20251024060615'),
('20251024042421'),
('20251024004655'),
('20251023230141'),
('20251022125008'),
('20251017055837'),
('20251017041942'),
('20251017021932'),
('20251017021457'),
('20251016215522'),
('20251016005855'),
('20251005070316'),
('20251005055245'),
('20251002093244'),
('20251002085332'),
('20250923161649'),
('20250722120905'),
('20250620164659'),
('20250620164658'),
('20250616092017'),
('20250602092107'),
('20250526212423'),
('20250426152444'),
('20250421070836'),
('20250421055132'),
('20250419141249'),
('20250405234709'),
('20250405234650'),
('20250405230648'),
('20250328122554'),
('20250316020401'),
('20250310001915'),
('20250206010144'),
('20250127230137'),
('20250126005334'),
('20241229224443'),
('20241229215034'),
('20241229194747'),
('20241227035943'),
('20241202170148'),
('20241016165142'),
('20240906184638'),
('20240905160626'),
('20240904232217'),
('20240903075408'),
('20240903030722'),
('20240902180015'),
('20240830234032'),
('20240830162111'),
('20240828151201'),
('20240828150626'),
('20240828144918'),
('20240827201623'),
('20240827182333'),
('20240827164832'),
('20240827144113'),
('20240825012820'),
('20240824192520'),
('20240824173724'),
('20240804065554'),
('20240725183134'),
('20240709134926'),
('20240706061122'),
('20240630084744'),
('20240627052741'),
('20240627045124'),
('20240622005608'),
('20240617181703'),
('20240614223206'),
('20240614185647'),
('20240614154755'),
('20240613223218'),
('20240612201430'),
('20240612175355'),
('20240612044339'),
('20240612044331'),
('20240516010953'),
('20240514063636'),
('20240513033445'),
('20240513023551'),
('20240510062438'),
('20240510030953'),
('20240422110202'),
('20240418103518'),
('20240417101613'),
('20240413150945'),
('20240411061400'),
('20240411041819'),
('20240410140320'),
('20240410120726'),
('20240410100924'),
('20240410050656'),
('20240307133355'),
('20240306215111'),
('20240306204814'),
('20240302152238'),
('20240302150135'),
('20240302142453'),
('20240302084449'),
('20240229070342'),
('20240227091418'),
('20240217235926'),
('20240217025400'),
('20240214190653'),
('20240214023511'),
('20240210054643'),
('20240206035357'),
('20240205174652'),
('20240205165127'),
('20240205164313'),
('20240205030536'),
('20240205015902'),
('20240204214246'),
('20240127150517'),
('20240127134104'),
('20240126174807'),
('20240119211758'),
('20240113112949'),
('20240103002049'),
('20240103002040'),
('20240101042716'),
('20231213010430'),
('20231201235926'),
('20231002181447'),
('20230531081706'),
('20230531080817'),
('20230518182034'),
('20230517155547'),
('20230513074838'),
('20230506161827'),
('20230316084945'),
('20230314170352'),
('20230312103728'),
('20230226152600'),
('20230221153458'),
('20230221145226'),
('20230219115601'),
('20230210092829'),
('20230204141325'),
('20230203162010'),
('20221014085948'),
('20220810131625'),
('20220710133556'),
('20220516103329'),
('20220316162257'),
('20220219202441'),
('20220203154846'),
('20220106081415');

INSERT INTO "fixes" (id, index) VALUES
(232, NULL),
(231, 2),
(231, 1),
(230, 2),
(230, 1),
(229, NULL),
(228, NULL),
(227, NULL),
(226, NULL),
(225, 2),
(225, 1),
(224, NULL),
(223, NULL),
(222, NULL),
(221, NULL),
(220, 2),
(220, 1),
(219, NULL),
(218, NULL),
(217, NULL),
(216, NULL),
(215, NULL),
(214, NULL),
(213, NULL),
(212, NULL),
(211, 2),
(211, 1),
(210, NULL),
(209, NULL),
(208, NULL),
(207, 2),
(207, 1),
(206, NULL),
(205, NULL),
(204, NULL),
(203, 2),
(203, 1),
(202, NULL),
(201, NULL),
(200, NULL),
(119, NULL),
(118, NULL),
(116, NULL),
(115, NULL),
(114, 2),
(114, 1),
(113, NULL),
(112, NULL),
(111, NULL),
(110, NULL),
(109, NULL),
(108, NULL),
(107, NULL),
(106, NULL),
(105, NULL),
(104, 2),
(104, 1),
(103, NULL),
(102, NULL),
(101, NULL),
(100, NULL);

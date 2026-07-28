
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


CREATE EXTENSION IF NOT EXISTS pg_stat_statements WITH SCHEMA public;



CREATE EXTENSION IF NOT EXISTS pg_trgm WITH SCHEMA public;


SET default_tablespace = '';

SET default_table_access_method = heap;


CREATE TABLE public.active_storage_attachments (
    id bigint NOT NULL,
    blob_id bigint NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    name character varying NOT NULL,
    record_id bigint NOT NULL,
    record_type character varying NOT NULL
);



CREATE SEQUENCE public.active_storage_attachments_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;



ALTER SEQUENCE public.active_storage_attachments_id_seq OWNED BY public.active_storage_attachments.id;



CREATE TABLE public.active_storage_blobs (
    id bigint NOT NULL,
    byte_size bigint NOT NULL,
    checksum character varying,
    content_type character varying,
    created_at timestamp(6) without time zone NOT NULL,
    filename character varying NOT NULL,
    key character varying NOT NULL,
    metadata text,
    service_name character varying NOT NULL
);



CREATE SEQUENCE public.active_storage_blobs_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;



ALTER SEQUENCE public.active_storage_blobs_id_seq OWNED BY public.active_storage_blobs.id;



CREATE TABLE public.active_storage_variant_records (
    id bigint NOT NULL,
    blob_id bigint NOT NULL,
    variation_digest character varying NOT NULL
);



CREATE SEQUENCE public.active_storage_variant_records_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;



ALTER SEQUENCE public.active_storage_variant_records_id_seq OWNED BY public.active_storage_variant_records.id;



CREATE TABLE public.admin_api_keys (
    id bigint NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    name text NOT NULL,
    revoked_at timestamp(6) without time zone,
    token text NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    user_id bigint NOT NULL
);



CREATE SEQUENCE public.admin_api_keys_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;



ALTER SEQUENCE public.admin_api_keys_id_seq OWNED BY public.admin_api_keys.id;



CREATE TABLE public.api_keys (
    id bigint NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    name text NOT NULL,
    token text NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    user_id bigint NOT NULL
);



CREATE SEQUENCE public.api_keys_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;



ALTER SEQUENCE public.api_keys_id_seq OWNED BY public.api_keys.id;



CREATE TABLE public.ar_internal_metadata (
    key character varying NOT NULL,
    value character varying,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);



CREATE TABLE public.commits (
    sha character varying NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    github_raw jsonb,
    repository_id bigint,
    updated_at timestamp(6) without time zone NOT NULL,
    user_id bigint NOT NULL
);



CREATE TABLE public.dashboard_rollups (
    id bigint NOT NULL,
    bucket_value text DEFAULT ''::text NOT NULL,
    bucket_value_present boolean DEFAULT true NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    dimension character varying NOT NULL,
    payload jsonb,
    source_heartbeats_count integer,
    source_max_heartbeat_time double precision,
    total_seconds integer DEFAULT 0 NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    user_id bigint NOT NULL
);



CREATE SEQUENCE public.dashboard_rollups_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;



ALTER SEQUENCE public.dashboard_rollups_id_seq OWNED BY public.dashboard_rollups.id;



CREATE TABLE public.deletion_requests (
    id bigint NOT NULL,
    admin_approved_at timestamp(6) without time zone,
    admin_approved_by_id bigint,
    cancelled_at timestamp(6) without time zone,
    completed_at timestamp(6) without time zone,
    created_at timestamp(6) without time zone NOT NULL,
    reason text,
    reason_details text,
    requested_at timestamp(6) without time zone NOT NULL,
    scheduled_deletion_at timestamp(6) without time zone,
    status integer DEFAULT 0 NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    user_id bigint NOT NULL
);



CREATE SEQUENCE public.deletion_requests_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;



ALTER SEQUENCE public.deletion_requests_id_seq OWNED BY public.deletion_requests.id;



CREATE TABLE public.email_addresses (
    id bigint NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    email character varying,
    source integer,
    updated_at timestamp(6) without time zone NOT NULL,
    user_id bigint NOT NULL
);



CREATE SEQUENCE public.email_addresses_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;



ALTER SEQUENCE public.email_addresses_id_seq OWNED BY public.email_addresses.id;



CREATE TABLE public.email_verification_requests (
    id bigint NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    deleted_at timestamp(6) without time zone,
    email character varying,
    expires_at timestamp(6) without time zone,
    token character varying,
    updated_at timestamp(6) without time zone NOT NULL,
    user_id bigint NOT NULL
);



CREATE SEQUENCE public.email_verification_requests_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;



ALTER SEQUENCE public.email_verification_requests_id_seq OWNED BY public.email_verification_requests.id;



CREATE TABLE public.flipper_features (
    id bigint NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    key character varying NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);



CREATE SEQUENCE public.flipper_features_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;



ALTER SEQUENCE public.flipper_features_id_seq OWNED BY public.flipper_features.id;



CREATE TABLE public.flipper_gates (
    id bigint NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    feature_key character varying NOT NULL,
    key character varying NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    value text
);



CREATE SEQUENCE public.flipper_gates_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;



ALTER SEQUENCE public.flipper_gates_id_seq OWNED BY public.flipper_gates.id;



CREATE TABLE public.goals (
    id bigint NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    languages character varying[] DEFAULT '{}'::character varying[] NOT NULL,
    period character varying NOT NULL,
    projects character varying[] DEFAULT '{}'::character varying[] NOT NULL,
    target_seconds integer NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    user_id bigint NOT NULL
);



CREATE SEQUENCE public.goals_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;



ALTER SEQUENCE public.goals_id_seq OWNED BY public.goals.id;



CREATE TABLE public.good_job_batches (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    callback_priority integer,
    callback_queue_name text,
    created_at timestamp(6) without time zone NOT NULL,
    description text,
    discarded_at timestamp(6) without time zone,
    enqueued_at timestamp(6) without time zone,
    finished_at timestamp(6) without time zone,
    jobs_finished_at timestamp(6) without time zone,
    on_discard text,
    on_finish text,
    on_success text,
    serialized_properties jsonb,
    updated_at timestamp(6) without time zone NOT NULL
);



CREATE TABLE public.good_job_executions (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    active_job_id uuid NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    duration interval,
    error text,
    error_backtrace text[],
    error_event smallint,
    finished_at timestamp(6) without time zone,
    job_class text,
    process_id uuid,
    queue_name text,
    scheduled_at timestamp(6) without time zone,
    serialized_params jsonb,
    updated_at timestamp(6) without time zone NOT NULL
);



CREATE TABLE public.good_job_processes (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    lock_type smallint,
    state jsonb,
    updated_at timestamp(6) without time zone NOT NULL
);



CREATE TABLE public.good_job_settings (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    key text,
    updated_at timestamp(6) without time zone NOT NULL,
    value jsonb
);



CREATE TABLE public.good_jobs (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    active_job_id uuid,
    batch_callback_id uuid,
    batch_id uuid,
    concurrency_key text,
    created_at timestamp(6) without time zone NOT NULL,
    cron_at timestamp(6) without time zone,
    cron_key text,
    error text,
    error_event smallint,
    executions_count integer,
    finished_at timestamp(6) without time zone,
    is_discrete boolean,
    job_class text,
    labels text[],
    locked_at timestamp(6) without time zone,
    locked_by_id uuid,
    performed_at timestamp(6) without time zone,
    priority integer,
    queue_name text,
    retried_good_job_id uuid,
    scheduled_at timestamp(6) without time zone,
    serialized_params jsonb,
    updated_at timestamp(6) without time zone NOT NULL
);



CREATE TABLE public.heartbeat_import_runs (
    id bigint NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    encrypted_api_key character varying,
    error_message text,
    errors_count integer DEFAULT 0 NOT NULL,
    finished_at timestamp(6) without time zone,
    imported_count integer,
    message text,
    processed_count integer DEFAULT 0 NOT NULL,
    remote_dump_id character varying,
    remote_dump_status character varying,
    remote_percent_complete double precision,
    remote_requested_at timestamp(6) without time zone,
    skipped_count integer,
    source_filename character varying,
    source_kind integer NOT NULL,
    started_at timestamp(6) without time zone,
    state integer DEFAULT 0 NOT NULL,
    total_count integer,
    updated_at timestamp(6) without time zone NOT NULL,
    user_id bigint NOT NULL
);



CREATE SEQUENCE public.heartbeat_import_runs_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;



ALTER SEQUENCE public.heartbeat_import_runs_id_seq OWNED BY public.heartbeat_import_runs.id;



CREATE TABLE public.heartbeat_import_sources (
    id bigint NOT NULL,
    backfill_cursor_date date,
    consecutive_failures integer DEFAULT 0 NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    encrypted_api_key character varying NOT NULL,
    endpoint_url character varying NOT NULL,
    initial_backfill_end_date date,
    initial_backfill_start_date date,
    last_error_at timestamp(6) without time zone,
    last_error_message text,
    last_synced_at timestamp(6) without time zone,
    provider integer DEFAULT 0 NOT NULL,
    status integer DEFAULT 0 NOT NULL,
    sync_enabled boolean DEFAULT true NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    user_id bigint NOT NULL
);



CREATE SEQUENCE public.heartbeat_import_sources_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;



ALTER SEQUENCE public.heartbeat_import_sources_id_seq OWNED BY public.heartbeat_import_sources.id;



CREATE TABLE public.instance_import_sources (
    id bigint NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    encrypted_api_key character varying NOT NULL,
    endpoint_url character varying NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    user_id bigint NOT NULL
);



CREATE SEQUENCE public.instance_import_sources_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;



ALTER SEQUENCE public.instance_import_sources_id_seq OWNED BY public.instance_import_sources.id;



CREATE TABLE public.ja4s (
    id integer NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    fingerprint text NOT NULL,
    name text,
    updated_at timestamp(6) without time zone NOT NULL
);



CREATE SEQUENCE public.ja4s_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;



ALTER SEQUENCE public.ja4s_id_seq OWNED BY public.ja4s.id;



CREATE TABLE public.leaderboard_entries (
    id bigint NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    leaderboard_id bigint NOT NULL,
    rank integer,
    streak_count integer DEFAULT 0,
    total_seconds integer DEFAULT 0 NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    user_id bigint NOT NULL
);



CREATE SEQUENCE public.leaderboard_entries_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;



ALTER SEQUENCE public.leaderboard_entries_id_seq OWNED BY public.leaderboard_entries.id;



CREATE TABLE public.leaderboards (
    id bigint NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    deleted_at timestamp(6) without time zone,
    finished_generating_at timestamp(6) without time zone,
    generation_duration_seconds integer,
    period_type integer DEFAULT 0 NOT NULL,
    start_date date NOT NULL,
    timezone_offset integer,
    timezone_utc_offset integer,
    updated_at timestamp(6) without time zone NOT NULL
);



CREATE SEQUENCE public.leaderboards_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;



ALTER SEQUENCE public.leaderboards_id_seq OWNED BY public.leaderboards.id;



CREATE TABLE public.mailkick_subscriptions (
    id bigint NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    list character varying,
    subscriber_id bigint,
    subscriber_type character varying,
    updated_at timestamp(6) without time zone NOT NULL
);



CREATE SEQUENCE public.mailkick_subscriptions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;



ALTER SEQUENCE public.mailkick_subscriptions_id_seq OWNED BY public.mailkick_subscriptions.id;



CREATE TABLE public.notable_jobs (
    id bigint NOT NULL,
    created_at timestamp(6) without time zone,
    job text,
    job_id character varying,
    note text,
    note_type character varying,
    queue character varying,
    queued_time double precision,
    runtime double precision
);



CREATE SEQUENCE public.notable_jobs_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;



ALTER SEQUENCE public.notable_jobs_id_seq OWNED BY public.notable_jobs.id;



CREATE TABLE public.notable_requests (
    id bigint NOT NULL,
    action text,
    created_at timestamp(6) without time zone,
    ip character varying,
    note text,
    note_type character varying,
    params text,
    referrer text,
    request_id character varying,
    request_time double precision,
    status integer,
    url text,
    user_agent text,
    user_id bigint,
    user_type character varying
);



CREATE SEQUENCE public.notable_requests_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;



ALTER SEQUENCE public.notable_requests_id_seq OWNED BY public.notable_requests.id;



CREATE TABLE public.oauth_access_grants (
    id bigint NOT NULL,
    application_id bigint NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    expires_in integer NOT NULL,
    redirect_uri text NOT NULL,
    resource_owner_id bigint NOT NULL,
    revoked_at timestamp(6) without time zone,
    scopes character varying DEFAULT ''::character varying NOT NULL,
    token character varying NOT NULL
);



CREATE SEQUENCE public.oauth_access_grants_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;



ALTER SEQUENCE public.oauth_access_grants_id_seq OWNED BY public.oauth_access_grants.id;



CREATE TABLE public.oauth_access_tokens (
    id bigint NOT NULL,
    application_id bigint NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    expires_in integer,
    previous_refresh_token character varying DEFAULT ''::character varying NOT NULL,
    refresh_token character varying,
    resource_owner_id bigint,
    revoked_at timestamp(6) without time zone,
    scopes character varying,
    token character varying NOT NULL
);



CREATE SEQUENCE public.oauth_access_tokens_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;



ALTER SEQUENCE public.oauth_access_tokens_id_seq OWNED BY public.oauth_access_tokens.id;



CREATE TABLE public.oauth_applications (
    id bigint NOT NULL,
    confidential boolean DEFAULT true NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    name character varying NOT NULL,
    owner_id bigint,
    owner_type character varying,
    redirect_to_hca_login boolean DEFAULT false NOT NULL,
    redirect_uri text NOT NULL,
    scopes character varying DEFAULT ''::character varying NOT NULL,
    secret character varying NOT NULL,
    uid character varying NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    verified boolean DEFAULT false NOT NULL
);



CREATE SEQUENCE public.oauth_applications_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;



ALTER SEQUENCE public.oauth_applications_id_seq OWNED BY public.oauth_applications.id;



CREATE TABLE public.pghero_query_stats (
    id bigint NOT NULL,
    calls bigint,
    captured_at timestamp without time zone,
    database text,
    query text,
    query_hash bigint,
    total_time double precision,
    "user" text
);



CREATE SEQUENCE public.pghero_query_stats_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;



ALTER SEQUENCE public.pghero_query_stats_id_seq OWNED BY public.pghero_query_stats.id;



CREATE TABLE public.pghero_space_stats (
    id bigint NOT NULL,
    captured_at timestamp without time zone,
    database text,
    relation text,
    schema text,
    size bigint
);



CREATE SEQUENCE public.pghero_space_stats_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;



ALTER SEQUENCE public.pghero_space_stats_id_seq OWNED BY public.pghero_space_stats.id;



CREATE TABLE public.project_labels (
    id bigint NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    label character varying,
    project_key character varying,
    updated_at timestamp(6) without time zone NOT NULL,
    user_id character varying
);



CREATE SEQUENCE public.project_labels_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;



ALTER SEQUENCE public.project_labels_id_seq OWNED BY public.project_labels.id;



CREATE TABLE public.project_repo_mappings (
    id bigint NOT NULL,
    archived_at timestamp(6) without time zone,
    created_at timestamp(6) without time zone NOT NULL,
    project_name character varying NOT NULL,
    public_shared_at timestamp(6) without time zone,
    repo_url character varying,
    repository_id bigint,
    updated_at timestamp(6) without time zone NOT NULL,
    user_id bigint NOT NULL
);



CREATE SEQUENCE public.project_repo_mappings_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;



ALTER SEQUENCE public.project_repo_mappings_id_seq OWNED BY public.project_repo_mappings.id;



CREATE TABLE public.repo_host_events (
    id character varying NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    provider integer DEFAULT 0 NOT NULL,
    raw_event_payload jsonb NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    user_id bigint NOT NULL
);



CREATE TABLE public.repositories (
    id bigint NOT NULL,
    commit_count integer,
    created_at timestamp(6) without time zone NOT NULL,
    description text,
    homepage character varying,
    host character varying,
    language character varying,
    languages text,
    last_commit_at timestamp(6) without time zone,
    last_synced_at timestamp(6) without time zone,
    name character varying,
    owner character varying,
    stars integer,
    updated_at timestamp(6) without time zone NOT NULL,
    url character varying
);



CREATE SEQUENCE public.repositories_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;



ALTER SEQUENCE public.repositories_id_seq OWNED BY public.repositories.id;



CREATE TABLE public.sailors_log_leaderboards (
    id bigint NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    deleted_at timestamp(6) without time zone,
    message text,
    slack_channel_id character varying,
    slack_uid character varying,
    updated_at timestamp(6) without time zone NOT NULL
);



CREATE SEQUENCE public.sailors_log_leaderboards_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;



ALTER SEQUENCE public.sailors_log_leaderboards_id_seq OWNED BY public.sailors_log_leaderboards.id;



CREATE TABLE public.sailors_log_notification_preferences (
    id bigint NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    enabled boolean DEFAULT true NOT NULL,
    slack_channel_id character varying NOT NULL,
    slack_uid character varying NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);



CREATE SEQUENCE public.sailors_log_notification_preferences_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;



ALTER SEQUENCE public.sailors_log_notification_preferences_id_seq OWNED BY public.sailors_log_notification_preferences.id;



CREATE TABLE public.sailors_log_slack_notifications (
    id bigint NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    project_duration integer NOT NULL,
    project_name character varying NOT NULL,
    sent boolean DEFAULT false NOT NULL,
    slack_channel_id character varying NOT NULL,
    slack_uid character varying NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);



CREATE SEQUENCE public.sailors_log_slack_notifications_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;



ALTER SEQUENCE public.sailors_log_slack_notifications_id_seq OWNED BY public.sailors_log_slack_notifications.id;



CREATE TABLE public.sailors_logs (
    id bigint NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    projects_summary jsonb DEFAULT '{}'::jsonb NOT NULL,
    slack_uid character varying NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);



CREATE SEQUENCE public.sailors_logs_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;



ALTER SEQUENCE public.sailors_logs_id_seq OWNED BY public.sailors_logs.id;



CREATE TABLE public.schema_migrations (
    version character varying NOT NULL
);



CREATE TABLE public.sign_in_tokens (
    id bigint NOT NULL,
    auth_type integer,
    continue_param character varying,
    created_at timestamp(6) without time zone NOT NULL,
    expires_at timestamp(6) without time zone,
    return_data jsonb,
    token character varying,
    updated_at timestamp(6) without time zone NOT NULL,
    used_at timestamp(6) without time zone,
    user_id bigint NOT NULL
);



CREATE SEQUENCE public.sign_in_tokens_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;



ALTER SEQUENCE public.sign_in_tokens_id_seq OWNED BY public.sign_in_tokens.id;



CREATE TABLE public.solid_cache_entries (
    id bigint NOT NULL,
    byte_size integer NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    key bytea NOT NULL,
    key_hash bigint NOT NULL,
    value bytea NOT NULL
);



CREATE SEQUENCE public.solid_cache_entries_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;



ALTER SEQUENCE public.solid_cache_entries_id_seq OWNED BY public.solid_cache_entries.id;



CREATE TABLE public.trust_level_audit_logs (
    id bigint NOT NULL,
    changed_by_id bigint NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    new_trust_level character varying NOT NULL,
    notes text,
    previous_trust_level character varying NOT NULL,
    reason text,
    updated_at timestamp(6) without time zone NOT NULL,
    user_id bigint NOT NULL
);



CREATE SEQUENCE public.trust_level_audit_logs_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;



ALTER SEQUENCE public.trust_level_audit_logs_id_seq OWNED BY public.trust_level_audit_logs.id;



CREATE TABLE public.users (
    id bigint NOT NULL,
    admin_level integer DEFAULT 0 NOT NULL,
    allow_public_stats_lookup boolean DEFAULT true NOT NULL,
    country_code character varying,
    created_at timestamp(6) without time zone NOT NULL,
    default_timezone_leaderboard boolean DEFAULT true NOT NULL,
    deprecated_name character varying,
    display_name_override character varying,
    github_access_token text,
    github_avatar_url character varying,
    github_uid character varying,
    github_username character varying,
    hackatime_extension_text_type integer DEFAULT 0 NOT NULL,
    hca_access_token character varying,
    hca_id character varying,
    hca_scopes character varying[] DEFAULT '{}'::character varying[],
    leaderboard_shadowban_expires_at timestamp(6) without time zone,
    leaderboard_shadowban_reason text,
    leaderboard_shadowbanned boolean DEFAULT false NOT NULL,
    leaderboard_shadowbanned_by_id bigint,
    profile_bio text,
    profile_bluesky_url character varying,
    profile_discord_url character varying,
    profile_github_url character varying,
    profile_linkedin_url character varying,
    profile_twitter_url character varying,
    profile_website_url character varying,
    show_goals_in_statusbar boolean DEFAULT true NOT NULL,
    slack_access_token text,
    slack_avatar_url character varying,
    slack_scopes character varying[] DEFAULT '{}'::character varying[],
    slack_synced_at timestamp(6) without time zone,
    slack_uid character varying,
    slack_username character varying,
    theme integer DEFAULT 8 NOT NULL,
    timezone character varying DEFAULT 'UTC'::character varying,
    trust_level integer DEFAULT 0 NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    username character varying,
    uses_slack_status boolean DEFAULT false NOT NULL,
    weekly_summary_email_enabled boolean DEFAULT true NOT NULL
);



CREATE SEQUENCE public.users_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;



ALTER SEQUENCE public.users_id_seq OWNED BY public.users.id;



CREATE TABLE public.versions (
    id bigint NOT NULL,
    created_at timestamp(6) without time zone,
    event character varying NOT NULL,
    item_id bigint NOT NULL,
    item_type character varying NOT NULL,
    object text,
    object_changes text,
    whodunnit character varying
);



CREATE SEQUENCE public.versions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;



ALTER SEQUENCE public.versions_id_seq OWNED BY public.versions.id;



CREATE TABLE public.wakatime_mirrors (
    id bigint NOT NULL,
    consecutive_failures integer DEFAULT 0 NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    enabled boolean DEFAULT true NOT NULL,
    encrypted_api_key character varying NOT NULL,
    endpoint_url character varying DEFAULT 'https://wakatime.com/api/v1'::character varying NOT NULL,
    last_error_at timestamp(6) without time zone,
    last_error_message text,
    last_synced_at timestamp(6) without time zone,
    last_synced_heartbeat_id bigint,
    updated_at timestamp(6) without time zone NOT NULL,
    user_id bigint NOT NULL
);



CREATE SEQUENCE public.wakatime_mirrors_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;



ALTER SEQUENCE public.wakatime_mirrors_id_seq OWNED BY public.wakatime_mirrors.id;



ALTER TABLE ONLY public.active_storage_attachments ALTER COLUMN id SET DEFAULT nextval('public.active_storage_attachments_id_seq'::regclass);



ALTER TABLE ONLY public.active_storage_blobs ALTER COLUMN id SET DEFAULT nextval('public.active_storage_blobs_id_seq'::regclass);



ALTER TABLE ONLY public.active_storage_variant_records ALTER COLUMN id SET DEFAULT nextval('public.active_storage_variant_records_id_seq'::regclass);



ALTER TABLE ONLY public.admin_api_keys ALTER COLUMN id SET DEFAULT nextval('public.admin_api_keys_id_seq'::regclass);



ALTER TABLE ONLY public.api_keys ALTER COLUMN id SET DEFAULT nextval('public.api_keys_id_seq'::regclass);



ALTER TABLE ONLY public.dashboard_rollups ALTER COLUMN id SET DEFAULT nextval('public.dashboard_rollups_id_seq'::regclass);



ALTER TABLE ONLY public.deletion_requests ALTER COLUMN id SET DEFAULT nextval('public.deletion_requests_id_seq'::regclass);



ALTER TABLE ONLY public.email_addresses ALTER COLUMN id SET DEFAULT nextval('public.email_addresses_id_seq'::regclass);



ALTER TABLE ONLY public.email_verification_requests ALTER COLUMN id SET DEFAULT nextval('public.email_verification_requests_id_seq'::regclass);



ALTER TABLE ONLY public.flipper_features ALTER COLUMN id SET DEFAULT nextval('public.flipper_features_id_seq'::regclass);



ALTER TABLE ONLY public.flipper_gates ALTER COLUMN id SET DEFAULT nextval('public.flipper_gates_id_seq'::regclass);



ALTER TABLE ONLY public.goals ALTER COLUMN id SET DEFAULT nextval('public.goals_id_seq'::regclass);



ALTER TABLE ONLY public.heartbeat_import_runs ALTER COLUMN id SET DEFAULT nextval('public.heartbeat_import_runs_id_seq'::regclass);



ALTER TABLE ONLY public.heartbeat_import_sources ALTER COLUMN id SET DEFAULT nextval('public.heartbeat_import_sources_id_seq'::regclass);



ALTER TABLE ONLY public.instance_import_sources ALTER COLUMN id SET DEFAULT nextval('public.instance_import_sources_id_seq'::regclass);



ALTER TABLE ONLY public.ja4s ALTER COLUMN id SET DEFAULT nextval('public.ja4s_id_seq'::regclass);



ALTER TABLE ONLY public.leaderboard_entries ALTER COLUMN id SET DEFAULT nextval('public.leaderboard_entries_id_seq'::regclass);



ALTER TABLE ONLY public.leaderboards ALTER COLUMN id SET DEFAULT nextval('public.leaderboards_id_seq'::regclass);



ALTER TABLE ONLY public.mailkick_subscriptions ALTER COLUMN id SET DEFAULT nextval('public.mailkick_subscriptions_id_seq'::regclass);



ALTER TABLE ONLY public.notable_jobs ALTER COLUMN id SET DEFAULT nextval('public.notable_jobs_id_seq'::regclass);



ALTER TABLE ONLY public.notable_requests ALTER COLUMN id SET DEFAULT nextval('public.notable_requests_id_seq'::regclass);



ALTER TABLE ONLY public.oauth_access_grants ALTER COLUMN id SET DEFAULT nextval('public.oauth_access_grants_id_seq'::regclass);



ALTER TABLE ONLY public.oauth_access_tokens ALTER COLUMN id SET DEFAULT nextval('public.oauth_access_tokens_id_seq'::regclass);



ALTER TABLE ONLY public.oauth_applications ALTER COLUMN id SET DEFAULT nextval('public.oauth_applications_id_seq'::regclass);



ALTER TABLE ONLY public.pghero_query_stats ALTER COLUMN id SET DEFAULT nextval('public.pghero_query_stats_id_seq'::regclass);



ALTER TABLE ONLY public.pghero_space_stats ALTER COLUMN id SET DEFAULT nextval('public.pghero_space_stats_id_seq'::regclass);



ALTER TABLE ONLY public.project_labels ALTER COLUMN id SET DEFAULT nextval('public.project_labels_id_seq'::regclass);



ALTER TABLE ONLY public.project_repo_mappings ALTER COLUMN id SET DEFAULT nextval('public.project_repo_mappings_id_seq'::regclass);



ALTER TABLE ONLY public.repositories ALTER COLUMN id SET DEFAULT nextval('public.repositories_id_seq'::regclass);



ALTER TABLE ONLY public.sailors_log_leaderboards ALTER COLUMN id SET DEFAULT nextval('public.sailors_log_leaderboards_id_seq'::regclass);



ALTER TABLE ONLY public.sailors_log_notification_preferences ALTER COLUMN id SET DEFAULT nextval('public.sailors_log_notification_preferences_id_seq'::regclass);



ALTER TABLE ONLY public.sailors_log_slack_notifications ALTER COLUMN id SET DEFAULT nextval('public.sailors_log_slack_notifications_id_seq'::regclass);



ALTER TABLE ONLY public.sailors_logs ALTER COLUMN id SET DEFAULT nextval('public.sailors_logs_id_seq'::regclass);



ALTER TABLE ONLY public.sign_in_tokens ALTER COLUMN id SET DEFAULT nextval('public.sign_in_tokens_id_seq'::regclass);



ALTER TABLE ONLY public.solid_cache_entries ALTER COLUMN id SET DEFAULT nextval('public.solid_cache_entries_id_seq'::regclass);



ALTER TABLE ONLY public.trust_level_audit_logs ALTER COLUMN id SET DEFAULT nextval('public.trust_level_audit_logs_id_seq'::regclass);



ALTER TABLE ONLY public.users ALTER COLUMN id SET DEFAULT nextval('public.users_id_seq'::regclass);



ALTER TABLE ONLY public.versions ALTER COLUMN id SET DEFAULT nextval('public.versions_id_seq'::regclass);



ALTER TABLE ONLY public.wakatime_mirrors ALTER COLUMN id SET DEFAULT nextval('public.wakatime_mirrors_id_seq'::regclass);



ALTER TABLE ONLY public.active_storage_attachments
    ADD CONSTRAINT active_storage_attachments_pkey PRIMARY KEY (id);



ALTER TABLE ONLY public.active_storage_blobs
    ADD CONSTRAINT active_storage_blobs_pkey PRIMARY KEY (id);



ALTER TABLE ONLY public.active_storage_variant_records
    ADD CONSTRAINT active_storage_variant_records_pkey PRIMARY KEY (id);



ALTER TABLE ONLY public.admin_api_keys
    ADD CONSTRAINT admin_api_keys_pkey PRIMARY KEY (id);



ALTER TABLE ONLY public.api_keys
    ADD CONSTRAINT api_keys_pkey PRIMARY KEY (id);



ALTER TABLE ONLY public.ar_internal_metadata
    ADD CONSTRAINT ar_internal_metadata_pkey PRIMARY KEY (key);



ALTER TABLE ONLY public.commits
    ADD CONSTRAINT commits_pkey PRIMARY KEY (sha);



ALTER TABLE ONLY public.dashboard_rollups
    ADD CONSTRAINT dashboard_rollups_pkey PRIMARY KEY (id);



ALTER TABLE ONLY public.deletion_requests
    ADD CONSTRAINT deletion_requests_pkey PRIMARY KEY (id);



ALTER TABLE ONLY public.email_addresses
    ADD CONSTRAINT email_addresses_pkey PRIMARY KEY (id);



ALTER TABLE ONLY public.email_verification_requests
    ADD CONSTRAINT email_verification_requests_pkey PRIMARY KEY (id);



ALTER TABLE ONLY public.flipper_features
    ADD CONSTRAINT flipper_features_pkey PRIMARY KEY (id);



ALTER TABLE ONLY public.flipper_gates
    ADD CONSTRAINT flipper_gates_pkey PRIMARY KEY (id);



ALTER TABLE ONLY public.goals
    ADD CONSTRAINT goals_pkey PRIMARY KEY (id);



ALTER TABLE ONLY public.good_job_batches
    ADD CONSTRAINT good_job_batches_pkey PRIMARY KEY (id);



ALTER TABLE ONLY public.good_job_executions
    ADD CONSTRAINT good_job_executions_pkey PRIMARY KEY (id);



ALTER TABLE ONLY public.good_job_processes
    ADD CONSTRAINT good_job_processes_pkey PRIMARY KEY (id);



ALTER TABLE ONLY public.good_job_settings
    ADD CONSTRAINT good_job_settings_pkey PRIMARY KEY (id);



ALTER TABLE ONLY public.good_jobs
    ADD CONSTRAINT good_jobs_pkey PRIMARY KEY (id);



ALTER TABLE ONLY public.heartbeat_import_runs
    ADD CONSTRAINT heartbeat_import_runs_pkey PRIMARY KEY (id);



ALTER TABLE ONLY public.heartbeat_import_sources
    ADD CONSTRAINT heartbeat_import_sources_pkey PRIMARY KEY (id);



ALTER TABLE ONLY public.instance_import_sources
    ADD CONSTRAINT instance_import_sources_pkey PRIMARY KEY (id);



ALTER TABLE ONLY public.ja4s
    ADD CONSTRAINT ja4s_pkey PRIMARY KEY (id);



ALTER TABLE ONLY public.leaderboard_entries
    ADD CONSTRAINT leaderboard_entries_pkey PRIMARY KEY (id);



ALTER TABLE ONLY public.leaderboards
    ADD CONSTRAINT leaderboards_pkey PRIMARY KEY (id);



ALTER TABLE ONLY public.mailkick_subscriptions
    ADD CONSTRAINT mailkick_subscriptions_pkey PRIMARY KEY (id);



ALTER TABLE ONLY public.notable_jobs
    ADD CONSTRAINT notable_jobs_pkey PRIMARY KEY (id);



ALTER TABLE ONLY public.notable_requests
    ADD CONSTRAINT notable_requests_pkey PRIMARY KEY (id);



ALTER TABLE ONLY public.oauth_access_grants
    ADD CONSTRAINT oauth_access_grants_pkey PRIMARY KEY (id);



ALTER TABLE ONLY public.oauth_access_tokens
    ADD CONSTRAINT oauth_access_tokens_pkey PRIMARY KEY (id);



ALTER TABLE ONLY public.oauth_applications
    ADD CONSTRAINT oauth_applications_pkey PRIMARY KEY (id);



ALTER TABLE ONLY public.pghero_query_stats
    ADD CONSTRAINT pghero_query_stats_pkey PRIMARY KEY (id);



ALTER TABLE ONLY public.pghero_space_stats
    ADD CONSTRAINT pghero_space_stats_pkey PRIMARY KEY (id);



ALTER TABLE ONLY public.project_labels
    ADD CONSTRAINT project_labels_pkey PRIMARY KEY (id);



ALTER TABLE ONLY public.project_repo_mappings
    ADD CONSTRAINT project_repo_mappings_pkey PRIMARY KEY (id);



ALTER TABLE ONLY public.repo_host_events
    ADD CONSTRAINT repo_host_events_pkey PRIMARY KEY (id);



ALTER TABLE ONLY public.repositories
    ADD CONSTRAINT repositories_pkey PRIMARY KEY (id);



ALTER TABLE ONLY public.sailors_log_leaderboards
    ADD CONSTRAINT sailors_log_leaderboards_pkey PRIMARY KEY (id);



ALTER TABLE ONLY public.sailors_log_notification_preferences
    ADD CONSTRAINT sailors_log_notification_preferences_pkey PRIMARY KEY (id);



ALTER TABLE ONLY public.sailors_log_slack_notifications
    ADD CONSTRAINT sailors_log_slack_notifications_pkey PRIMARY KEY (id);



ALTER TABLE ONLY public.sailors_logs
    ADD CONSTRAINT sailors_logs_pkey PRIMARY KEY (id);



ALTER TABLE ONLY public.schema_migrations
    ADD CONSTRAINT schema_migrations_pkey PRIMARY KEY (version);



ALTER TABLE ONLY public.sign_in_tokens
    ADD CONSTRAINT sign_in_tokens_pkey PRIMARY KEY (id);



ALTER TABLE ONLY public.solid_cache_entries
    ADD CONSTRAINT solid_cache_entries_pkey PRIMARY KEY (id);



ALTER TABLE ONLY public.trust_level_audit_logs
    ADD CONSTRAINT trust_level_audit_logs_pkey PRIMARY KEY (id);



ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);



ALTER TABLE ONLY public.versions
    ADD CONSTRAINT versions_pkey PRIMARY KEY (id);



ALTER TABLE ONLY public.wakatime_mirrors
    ADD CONSTRAINT wakatime_mirrors_pkey PRIMARY KEY (id);



CREATE UNIQUE INDEX idx_dashboard_rollups_user_dimension_bucket ON public.dashboard_rollups USING btree (user_id, dimension, bucket_value_present, bucket_value);



CREATE UNIQUE INDEX idx_leaderboard_entries_on_leaderboard_and_user ON public.leaderboard_entries USING btree (leaderboard_id, user_id);



CREATE UNIQUE INDEX idx_sailors_log_notification_preferences_unique_user_channel ON public.sailors_log_notification_preferences USING btree (slack_uid, slack_channel_id);



CREATE INDEX index_active_storage_attachments_on_blob_id ON public.active_storage_attachments USING btree (blob_id);



CREATE UNIQUE INDEX index_active_storage_attachments_uniqueness ON public.active_storage_attachments USING btree (record_type, record_id, name, blob_id);



CREATE UNIQUE INDEX index_active_storage_blobs_on_key ON public.active_storage_blobs USING btree (key);



CREATE UNIQUE INDEX index_active_storage_variant_records_uniqueness ON public.active_storage_variant_records USING btree (blob_id, variation_digest);



CREATE UNIQUE INDEX index_admin_api_keys_on_token ON public.admin_api_keys USING btree (token);



CREATE INDEX index_admin_api_keys_on_user_id ON public.admin_api_keys USING btree (user_id);



CREATE UNIQUE INDEX index_admin_api_keys_on_user_id_and_name ON public.admin_api_keys USING btree (user_id, name);



CREATE UNIQUE INDEX index_api_keys_on_token ON public.api_keys USING btree (token);



CREATE INDEX index_api_keys_on_user_id ON public.api_keys USING btree (user_id);



CREATE UNIQUE INDEX index_api_keys_on_user_id_and_name ON public.api_keys USING btree (user_id, name);



CREATE UNIQUE INDEX index_api_keys_on_user_id_and_token ON public.api_keys USING btree (user_id, token);



CREATE INDEX index_commits_on_repository_id ON public.commits USING btree (repository_id);



CREATE INDEX index_commits_on_user_id ON public.commits USING btree (user_id);



CREATE INDEX index_commits_on_user_id_and_created_at ON public.commits USING btree (user_id, created_at);



CREATE INDEX index_dashboard_rollups_on_bucket_value ON public.dashboard_rollups USING btree (bucket_value);



CREATE INDEX index_dashboard_rollups_on_dimension_total ON public.dashboard_rollups USING btree (dimension) WHERE (((dimension)::text = 'total'::text) AND (total_seconds > 0));



CREATE INDEX index_dashboard_rollups_on_user_id ON public.dashboard_rollups USING btree (user_id);



CREATE INDEX index_dashboard_rollups_on_user_id_and_dimension ON public.dashboard_rollups USING btree (user_id, dimension);



CREATE INDEX index_deletion_requests_on_status ON public.deletion_requests USING btree (status);



CREATE INDEX index_deletion_requests_on_user_id ON public.deletion_requests USING btree (user_id);



CREATE INDEX index_deletion_requests_on_user_id_and_status ON public.deletion_requests USING btree (user_id, status);



CREATE UNIQUE INDEX index_email_addresses_on_email ON public.email_addresses USING btree (email);



CREATE INDEX index_email_addresses_on_email_trgm ON public.email_addresses USING gin (email public.gin_trgm_ops);



CREATE INDEX index_email_addresses_on_user_id ON public.email_addresses USING btree (user_id);



CREATE UNIQUE INDEX index_email_verification_requests_on_email_active ON public.email_verification_requests USING btree (email) WHERE (deleted_at IS NULL);



CREATE INDEX index_email_verification_requests_on_user_id ON public.email_verification_requests USING btree (user_id);



CREATE UNIQUE INDEX index_flipper_features_on_key ON public.flipper_features USING btree (key);



CREATE UNIQUE INDEX index_flipper_gates_on_feature_key_and_key_and_value ON public.flipper_gates USING btree (feature_key, key, value);



CREATE UNIQUE INDEX index_goals_on_user_and_scope ON public.goals USING btree (user_id, period, target_seconds, languages, projects);



CREATE INDEX index_goals_on_user_id ON public.goals USING btree (user_id);



CREATE INDEX index_good_job_executions_on_active_job_id_and_created_at ON public.good_job_executions USING btree (active_job_id, created_at);



CREATE INDEX index_good_job_executions_on_process_id_and_created_at ON public.good_job_executions USING btree (process_id, created_at);



CREATE INDEX index_good_job_jobs_for_candidate_lookup ON public.good_jobs USING btree (priority, created_at) WHERE (finished_at IS NULL);



CREATE UNIQUE INDEX index_good_job_settings_on_key ON public.good_job_settings USING btree (key);



CREATE INDEX index_good_jobs_finished_at_with_error ON public.good_jobs USING btree (finished_at) WHERE (error IS NOT NULL);



CREATE INDEX index_good_jobs_jobs_on_finished_at ON public.good_jobs USING btree (finished_at) WHERE ((retried_good_job_id IS NULL) AND (finished_at IS NOT NULL));



CREATE INDEX index_good_jobs_jobs_on_priority_created_at_when_unfinished ON public.good_jobs USING btree (priority DESC NULLS LAST, created_at) WHERE (finished_at IS NULL);



CREATE INDEX index_good_jobs_on_active_job_id_and_created_at ON public.good_jobs USING btree (active_job_id, created_at);



CREATE INDEX index_good_jobs_on_batch_callback_id ON public.good_jobs USING btree (batch_callback_id) WHERE (batch_callback_id IS NOT NULL);



CREATE INDEX index_good_jobs_on_batch_id ON public.good_jobs USING btree (batch_id) WHERE (batch_id IS NOT NULL);



CREATE INDEX index_good_jobs_on_concurrency_key_when_unfinished ON public.good_jobs USING btree (concurrency_key) WHERE (finished_at IS NULL);



CREATE INDEX index_good_jobs_on_cron_key_and_created_at_cond ON public.good_jobs USING btree (cron_key, created_at) WHERE (cron_key IS NOT NULL);



CREATE UNIQUE INDEX index_good_jobs_on_cron_key_and_cron_at_cond ON public.good_jobs USING btree (cron_key, cron_at) WHERE (cron_key IS NOT NULL);



CREATE INDEX index_good_jobs_on_labels ON public.good_jobs USING gin (labels) WHERE (labels IS NOT NULL);



CREATE INDEX index_good_jobs_on_locked_by_id ON public.good_jobs USING btree (locked_by_id) WHERE (locked_by_id IS NOT NULL);



CREATE INDEX index_good_jobs_on_priority_scheduled_at_unfinished_unlocked ON public.good_jobs USING btree (priority, scheduled_at) WHERE ((finished_at IS NULL) AND (locked_by_id IS NULL));



CREATE INDEX index_good_jobs_on_queue_name_and_scheduled_at ON public.good_jobs USING btree (queue_name, scheduled_at) WHERE (finished_at IS NULL);



CREATE INDEX index_good_jobs_on_scheduled_at ON public.good_jobs USING btree (scheduled_at) WHERE (finished_at IS NULL);



CREATE INDEX index_good_jobs_on_scheduled_at_all ON public.good_jobs USING btree (scheduled_at);



CREATE INDEX index_good_jobs_on_scheduled_at_unfinished_unperformed ON public.good_jobs USING btree (scheduled_at) WHERE ((finished_at IS NULL) AND (performed_at IS NULL));



CREATE INDEX index_heartbeat_import_runs_on_user_id ON public.heartbeat_import_runs USING btree (user_id);



CREATE UNIQUE INDEX index_heartbeat_import_runs_on_user_id_active ON public.heartbeat_import_runs USING btree (user_id) WHERE (state = ANY (ARRAY[0, 1, 2, 3, 4]));



CREATE INDEX index_heartbeat_import_runs_on_user_id_and_created_at ON public.heartbeat_import_runs USING btree (user_id, created_at);



CREATE INDEX index_heartbeat_import_runs_on_user_id_and_state ON public.heartbeat_import_runs USING btree (user_id, state);



CREATE UNIQUE INDEX index_heartbeat_import_sources_on_user_id ON public.heartbeat_import_sources USING btree (user_id);



CREATE UNIQUE INDEX index_instance_import_sources_on_user_id ON public.instance_import_sources USING btree (user_id);



CREATE UNIQUE INDEX index_ja4s_on_fingerprint ON public.ja4s USING btree (fingerprint);



CREATE INDEX index_leaderboard_entries_on_leaderboard_id ON public.leaderboard_entries USING btree (leaderboard_id);



CREATE INDEX index_leaderboards_on_start_date ON public.leaderboards USING btree (start_date) WHERE (deleted_at IS NULL);



CREATE INDEX index_leaderboards_on_start_date_all ON public.leaderboards USING btree (start_date);



CREATE INDEX index_leaderboards_on_start_date_period_type_timezone_offset ON public.leaderboards USING btree (start_date, period_type, timezone_offset) WHERE (deleted_at IS NULL);



CREATE INDEX index_mailkick_subscriptions_on_subscriber ON public.mailkick_subscriptions USING btree (subscriber_type, subscriber_id);



CREATE UNIQUE INDEX index_mailkick_subscriptions_on_subscriber_and_list ON public.mailkick_subscriptions USING btree (subscriber_type, subscriber_id, list);



CREATE INDEX index_notable_requests_on_user ON public.notable_requests USING btree (user_type, user_id);



CREATE INDEX index_oauth_access_grants_on_application_id ON public.oauth_access_grants USING btree (application_id);



CREATE INDEX index_oauth_access_grants_on_resource_owner_id ON public.oauth_access_grants USING btree (resource_owner_id);



CREATE UNIQUE INDEX index_oauth_access_grants_on_token ON public.oauth_access_grants USING btree (token);



CREATE INDEX index_oauth_access_tokens_on_application_id ON public.oauth_access_tokens USING btree (application_id);



CREATE UNIQUE INDEX index_oauth_access_tokens_on_refresh_token ON public.oauth_access_tokens USING btree (refresh_token);



CREATE INDEX index_oauth_access_tokens_on_resource_owner_id ON public.oauth_access_tokens USING btree (resource_owner_id);



CREATE UNIQUE INDEX index_oauth_access_tokens_on_token ON public.oauth_access_tokens USING btree (token);



CREATE INDEX index_oauth_applications_on_owner ON public.oauth_applications USING btree (owner_type, owner_id);



CREATE UNIQUE INDEX index_oauth_applications_on_uid ON public.oauth_applications USING btree (uid);



CREATE INDEX index_pghero_query_stats_on_database_and_captured_at ON public.pghero_query_stats USING btree (database, captured_at);



CREATE INDEX index_pghero_space_stats_on_database_and_captured_at ON public.pghero_space_stats USING btree (database, captured_at);



CREATE INDEX index_project_labels_on_user_id ON public.project_labels USING btree (user_id);



CREATE UNIQUE INDEX index_project_labels_on_user_id_and_project_key ON public.project_labels USING btree (user_id, project_key);



CREATE INDEX index_project_repo_mappings_on_project_name ON public.project_repo_mappings USING btree (project_name);



CREATE INDEX index_project_repo_mappings_on_repository_id ON public.project_repo_mappings USING btree (repository_id);



CREATE INDEX index_project_repo_mappings_on_user_id ON public.project_repo_mappings USING btree (user_id);



CREATE INDEX index_project_repo_mappings_on_user_id_and_archived_at ON public.project_repo_mappings USING btree (user_id, archived_at);



CREATE UNIQUE INDEX index_project_repo_mappings_on_user_id_and_project_name ON public.project_repo_mappings USING btree (user_id, project_name);



CREATE INDEX index_repo_host_events_on_provider ON public.repo_host_events USING btree (provider);



CREATE INDEX index_repo_host_events_on_user_id ON public.repo_host_events USING btree (user_id);



CREATE INDEX index_repo_host_events_on_user_provider_created_at ON public.repo_host_events USING btree (user_id, provider, created_at);



CREATE UNIQUE INDEX index_repositories_on_url ON public.repositories USING btree (url);



CREATE UNIQUE INDEX index_sailors_logs_on_slack_uid ON public.sailors_logs USING btree (slack_uid);



CREATE INDEX index_sign_in_tokens_on_token ON public.sign_in_tokens USING btree (token);



CREATE INDEX index_sign_in_tokens_on_user_id ON public.sign_in_tokens USING btree (user_id);



CREATE INDEX index_solid_cache_entries_on_byte_size ON public.solid_cache_entries USING btree (byte_size);



CREATE UNIQUE INDEX index_solid_cache_entries_on_key_hash ON public.solid_cache_entries USING btree (key_hash);



CREATE INDEX index_solid_cache_entries_on_key_hash_and_byte_size ON public.solid_cache_entries USING btree (key_hash, byte_size);



CREATE INDEX index_trust_level_audit_logs_on_changed_by_and_created_at ON public.trust_level_audit_logs USING btree (changed_by_id, created_at);



CREATE INDEX index_trust_level_audit_logs_on_changed_by_id ON public.trust_level_audit_logs USING btree (changed_by_id);



CREATE INDEX index_trust_level_audit_logs_on_user_and_created_at ON public.trust_level_audit_logs USING btree (user_id, created_at);



CREATE INDEX index_trust_level_audit_logs_on_user_id ON public.trust_level_audit_logs USING btree (user_id);



CREATE INDEX index_users_on_github_uid ON public.users USING btree (github_uid);



CREATE INDEX index_users_on_github_uid_and_access_token ON public.users USING btree (github_uid, github_access_token);



CREATE INDEX index_users_on_github_username_trgm ON public.users USING gin (github_username public.gin_trgm_ops);



CREATE INDEX index_users_on_hca_id ON public.users USING btree (hca_id);



CREATE INDEX index_users_on_leaderboard_shadowbanned ON public.users USING btree (leaderboard_shadowbanned) WHERE (leaderboard_shadowbanned = true);



CREATE INDEX index_users_on_leaderboard_shadowbanned_by_id ON public.users USING btree (leaderboard_shadowbanned_by_id);



CREATE UNIQUE INDEX index_users_on_slack_uid ON public.users USING btree (slack_uid);



CREATE INDEX index_users_on_slack_username_trgm ON public.users USING gin (slack_username public.gin_trgm_ops);



CREATE INDEX index_users_on_timezone ON public.users USING btree (timezone);



CREATE INDEX index_users_on_timezone_trust_level ON public.users USING btree (timezone, trust_level);



CREATE INDEX index_users_on_username ON public.users USING btree (username);



CREATE INDEX index_users_on_username_trgm ON public.users USING gin (username public.gin_trgm_ops);



CREATE INDEX index_versions_on_item_type_and_item_id ON public.versions USING btree (item_type, item_id);



CREATE INDEX index_wakatime_mirrors_on_user_id ON public.wakatime_mirrors USING btree (user_id);



CREATE UNIQUE INDEX index_wakatime_mirrors_on_user_id_and_endpoint_url ON public.wakatime_mirrors USING btree (user_id, endpoint_url);



ALTER TABLE ONLY public.deletion_requests
    ADD CONSTRAINT fk_rails_0aa4839f87 FOREIGN KEY (user_id) REFERENCES public.users(id);



ALTER TABLE ONLY public.leaderboard_entries
    ADD CONSTRAINT fk_rails_1620868c64 FOREIGN KEY (user_id) REFERENCES public.users(id);



ALTER TABLE ONLY public.heartbeat_import_runs
    ADD CONSTRAINT fk_rails_16254168fb FOREIGN KEY (user_id) REFERENCES public.users(id);



ALTER TABLE ONLY public.users
    ADD CONSTRAINT fk_rails_1725e44f77 FOREIGN KEY (leaderboard_shadowbanned_by_id) REFERENCES public.users(id);



ALTER TABLE ONLY public.trust_level_audit_logs
    ADD CONSTRAINT fk_rails_202efc347d FOREIGN KEY (user_id) REFERENCES public.users(id);



ALTER TABLE ONLY public.instance_import_sources
    ADD CONSTRAINT fk_rails_25e93d19b0 FOREIGN KEY (user_id) REFERENCES public.users(id);



ALTER TABLE ONLY public.dashboard_rollups
    ADD CONSTRAINT fk_rails_2dca6f99bc FOREIGN KEY (user_id) REFERENCES public.users(id);



ALTER TABLE ONLY public.api_keys
    ADD CONSTRAINT fk_rails_32c28d0dc2 FOREIGN KEY (user_id) REFERENCES public.users(id);



ALTER TABLE ONLY public.oauth_access_grants
    ADD CONSTRAINT fk_rails_330c32d8d9 FOREIGN KEY (resource_owner_id) REFERENCES public.users(id);



ALTER TABLE ONLY public.commits
    ADD CONSTRAINT fk_rails_409a66d7e3 FOREIGN KEY (user_id) REFERENCES public.users(id);



ALTER TABLE ONLY public.repo_host_events
    ADD CONSTRAINT fk_rails_5d4e3eae11 FOREIGN KEY (user_id) REFERENCES public.users(id);



ALTER TABLE ONLY public.wakatime_mirrors
    ADD CONSTRAINT fk_rails_5e703ce14b FOREIGN KEY (user_id) REFERENCES public.users(id);



ALTER TABLE ONLY public.email_verification_requests
    ADD CONSTRAINT fk_rails_64ad1fa810 FOREIGN KEY (user_id) REFERENCES public.users(id);



ALTER TABLE ONLY public.oauth_access_tokens
    ADD CONSTRAINT fk_rails_732cb83ab7 FOREIGN KEY (application_id) REFERENCES public.oauth_applications(id);



ALTER TABLE ONLY public.project_repo_mappings
    ADD CONSTRAINT fk_rails_7ff6743abb FOREIGN KEY (repository_id) REFERENCES public.repositories(id);



ALTER TABLE ONLY public.active_storage_variant_records
    ADD CONSTRAINT fk_rails_993965df05 FOREIGN KEY (blob_id) REFERENCES public.active_storage_blobs(id);



ALTER TABLE ONLY public.commits
    ADD CONSTRAINT fk_rails_a8299bc69b FOREIGN KEY (repository_id) REFERENCES public.repositories(id);



ALTER TABLE ONLY public.sign_in_tokens
    ADD CONSTRAINT fk_rails_a9860dd74e FOREIGN KEY (user_id) REFERENCES public.users(id);



ALTER TABLE ONLY public.deletion_requests
    ADD CONSTRAINT fk_rails_adddd9e8ef FOREIGN KEY (admin_approved_by_id) REFERENCES public.users(id);



ALTER TABLE ONLY public.project_repo_mappings
    ADD CONSTRAINT fk_rails_aee8f6ca5b FOREIGN KEY (user_id) REFERENCES public.users(id);



ALTER TABLE ONLY public.oauth_access_grants
    ADD CONSTRAINT fk_rails_b4b53e07b8 FOREIGN KEY (application_id) REFERENCES public.oauth_applications(id);



ALTER TABLE ONLY public.trust_level_audit_logs
    ADD CONSTRAINT fk_rails_b8bf9dd115 FOREIGN KEY (changed_by_id) REFERENCES public.users(id);



ALTER TABLE ONLY public.active_storage_attachments
    ADD CONSTRAINT fk_rails_c3b3935057 FOREIGN KEY (blob_id) REFERENCES public.active_storage_blobs(id);



ALTER TABLE ONLY public.goals
    ADD CONSTRAINT fk_rails_c5fd9c8a38 FOREIGN KEY (user_id) REFERENCES public.users(id);



ALTER TABLE ONLY public.email_addresses
    ADD CONSTRAINT fk_rails_de643267e7 FOREIGN KEY (user_id) REFERENCES public.users(id);



ALTER TABLE ONLY public.heartbeat_import_sources
    ADD CONSTRAINT fk_rails_e731e6a5ad FOREIGN KEY (user_id) REFERENCES public.users(id);



ALTER TABLE ONLY public.oauth_access_tokens
    ADD CONSTRAINT fk_rails_ee63f25419 FOREIGN KEY (resource_owner_id) REFERENCES public.users(id);



ALTER TABLE ONLY public.leaderboard_entries
    ADD CONSTRAINT fk_rails_f523f294cc FOREIGN KEY (leaderboard_id) REFERENCES public.leaderboards(id);



ALTER TABLE ONLY public.admin_api_keys
    ADD CONSTRAINT fk_rails_fc8be7fc55 FOREIGN KEY (user_id) REFERENCES public.users(id);

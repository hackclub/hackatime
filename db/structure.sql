SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: pg_stat_statements; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS pg_stat_statements WITH SCHEMA public;


--
-- Name: EXTENSION pg_stat_statements; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION pg_stat_statements IS 'track planning and execution statistics of all SQL statements executed';


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: active_storage_attachments; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.active_storage_attachments (
    id bigint NOT NULL,
    blob_id bigint NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    name character varying NOT NULL,
    record_id bigint NOT NULL,
    record_type character varying NOT NULL
);


--
-- Name: active_storage_attachments_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.active_storage_attachments_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: active_storage_attachments_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.active_storage_attachments_id_seq OWNED BY public.active_storage_attachments.id;


--
-- Name: active_storage_blobs; Type: TABLE; Schema: public; Owner: -
--

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


--
-- Name: active_storage_blobs_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.active_storage_blobs_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: active_storage_blobs_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.active_storage_blobs_id_seq OWNED BY public.active_storage_blobs.id;


--
-- Name: active_storage_variant_records; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.active_storage_variant_records (
    id bigint NOT NULL,
    blob_id bigint NOT NULL,
    variation_digest character varying NOT NULL
);


--
-- Name: active_storage_variant_records_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.active_storage_variant_records_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: active_storage_variant_records_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.active_storage_variant_records_id_seq OWNED BY public.active_storage_variant_records.id;


--
-- Name: admin_api_keys; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.admin_api_keys (
    id bigint NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    name text NOT NULL,
    revoked_at timestamp(6) without time zone,
    token text NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    user_id bigint NOT NULL
);


--
-- Name: admin_api_keys_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.admin_api_keys_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: admin_api_keys_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.admin_api_keys_id_seq OWNED BY public.admin_api_keys.id;


--
-- Name: api_keys; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.api_keys (
    id bigint NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    name text NOT NULL,
    token text NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    user_id bigint NOT NULL
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
-- Name: commits; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.commits (
    sha character varying NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    github_raw jsonb,
    repository_id bigint,
    updated_at timestamp(6) without time zone NOT NULL,
    user_id bigint NOT NULL
);


--
-- Name: deletion_requests; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.deletion_requests (
    id bigint NOT NULL,
    admin_approved_at timestamp(6) without time zone,
    admin_approved_by_id bigint,
    cancelled_at timestamp(6) without time zone,
    completed_at timestamp(6) without time zone,
    created_at timestamp(6) without time zone NOT NULL,
    requested_at timestamp(6) without time zone NOT NULL,
    scheduled_deletion_at timestamp(6) without time zone,
    status integer DEFAULT 0 NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    user_id bigint NOT NULL
);


--
-- Name: deletion_requests_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.deletion_requests_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: deletion_requests_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.deletion_requests_id_seq OWNED BY public.deletion_requests.id;


--
-- Name: email_addresses; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.email_addresses (
    id bigint NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    email character varying,
    source integer,
    updated_at timestamp(6) without time zone NOT NULL,
    user_id bigint NOT NULL
);


--
-- Name: email_addresses_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.email_addresses_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: email_addresses_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.email_addresses_id_seq OWNED BY public.email_addresses.id;


--
-- Name: email_verification_requests; Type: TABLE; Schema: public; Owner: -
--

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


--
-- Name: email_verification_requests_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.email_verification_requests_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: email_verification_requests_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.email_verification_requests_id_seq OWNED BY public.email_verification_requests.id;


--
-- Name: flipper_features; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.flipper_features (
    id bigint NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    key character varying NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: flipper_features_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.flipper_features_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: flipper_features_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.flipper_features_id_seq OWNED BY public.flipper_features.id;


--
-- Name: flipper_gates; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.flipper_gates (
    id bigint NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    feature_key character varying NOT NULL,
    key character varying NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    value text
);


--
-- Name: flipper_gates_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.flipper_gates_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: flipper_gates_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.flipper_gates_id_seq OWNED BY public.flipper_gates.id;


--
-- Name: goals; Type: TABLE; Schema: public; Owner: -
--

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


--
-- Name: goals_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.goals_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: goals_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.goals_id_seq OWNED BY public.goals.id;


--
-- Name: good_job_batches; Type: TABLE; Schema: public; Owner: -
--

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


--
-- Name: good_job_executions; Type: TABLE; Schema: public; Owner: -
--

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


--
-- Name: good_job_processes; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.good_job_processes (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    lock_type smallint,
    state jsonb,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: good_job_settings; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.good_job_settings (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    key text,
    updated_at timestamp(6) without time zone NOT NULL,
    value jsonb
);


--
-- Name: good_jobs; Type: TABLE; Schema: public; Owner: -
--

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


--
-- Name: heartbeat_branches; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.heartbeat_branches (
    id bigint NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    name character varying NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    user_id bigint NOT NULL
);


--
-- Name: heartbeat_branches_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.heartbeat_branches_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: heartbeat_branches_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.heartbeat_branches_id_seq OWNED BY public.heartbeat_branches.id;


--
-- Name: heartbeat_categories; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.heartbeat_categories (
    id bigint NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    name character varying NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: heartbeat_categories_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.heartbeat_categories_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: heartbeat_categories_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.heartbeat_categories_id_seq OWNED BY public.heartbeat_categories.id;


--
-- Name: heartbeat_editors; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.heartbeat_editors (
    id bigint NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    name character varying NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: heartbeat_editors_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.heartbeat_editors_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: heartbeat_editors_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.heartbeat_editors_id_seq OWNED BY public.heartbeat_editors.id;


--
-- Name: heartbeat_import_sources; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.heartbeat_import_sources (
    id bigint NOT NULL,
    backfill_cursor_date date,
    consecutive_failures integer DEFAULT 0 NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    encrypted_api_key character varying NOT NULL,
    endpoint_url character varying NOT NULL,
    last_error_at timestamp(6) without time zone,
    last_error_message text,
    last_synced_at timestamp(6) without time zone,
    provider integer DEFAULT 0 NOT NULL,
    status integer DEFAULT 0 NOT NULL,
    sync_enabled boolean DEFAULT true NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    user_id bigint NOT NULL
);


--
-- Name: heartbeat_import_sources_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.heartbeat_import_sources_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: heartbeat_import_sources_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.heartbeat_import_sources_id_seq OWNED BY public.heartbeat_import_sources.id;


--
-- Name: heartbeat_languages; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.heartbeat_languages (
    id bigint NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    name character varying NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: heartbeat_languages_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.heartbeat_languages_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: heartbeat_languages_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.heartbeat_languages_id_seq OWNED BY public.heartbeat_languages.id;


--
-- Name: heartbeat_machines; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.heartbeat_machines (
    id bigint NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    name character varying NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    user_id bigint NOT NULL
);


--
-- Name: heartbeat_machines_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.heartbeat_machines_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: heartbeat_machines_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.heartbeat_machines_id_seq OWNED BY public.heartbeat_machines.id;


--
-- Name: heartbeat_operating_systems; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.heartbeat_operating_systems (
    id bigint NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    name character varying NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: heartbeat_operating_systems_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.heartbeat_operating_systems_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: heartbeat_operating_systems_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.heartbeat_operating_systems_id_seq OWNED BY public.heartbeat_operating_systems.id;


--
-- Name: heartbeat_projects; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.heartbeat_projects (
    id bigint NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    name character varying NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    user_id bigint NOT NULL
);


--
-- Name: heartbeat_projects_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.heartbeat_projects_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: heartbeat_projects_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.heartbeat_projects_id_seq OWNED BY public.heartbeat_projects.id;


--
-- Name: heartbeat_user_agents; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.heartbeat_user_agents (
    id bigint NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    value character varying NOT NULL
);


--
-- Name: heartbeat_user_agents_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.heartbeat_user_agents_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: heartbeat_user_agents_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.heartbeat_user_agents_id_seq OWNED BY public.heartbeat_user_agents.id;


--
-- Name: heartbeats; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.heartbeats (
    id bigint NOT NULL,
    branch character varying,
    category character varying,
    created_at timestamp(6) without time zone NOT NULL,
    cursorpos integer,
    deleted_at timestamp(6) without time zone,
    dependencies character varying[] DEFAULT '{}'::character varying[],
    editor character varying,
    entity character varying,
    fields_hash text,
    ip_address inet,
    is_write boolean,
    language character varying,
    line_additions integer,
    line_deletions integer,
    lineno integer,
    lines integer,
    machine character varying,
    operating_system character varying,
    project character varying,
    project_root_count integer,
    raw_heartbeat_upload_id bigint,
    source_type integer NOT NULL,
    "time" double precision NOT NULL,
    type character varying,
    updated_at timestamp(6) without time zone NOT NULL,
    user_agent character varying,
    user_id bigint NOT NULL,
    ysws_program integer DEFAULT 0 NOT NULL
)
PARTITION BY RANGE ("time");


--
-- Name: heartbeats_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.heartbeats_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: heartbeats_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.heartbeats_id_seq OWNED BY public.heartbeats.id;


--
-- Name: heartbeats_2024_01; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.heartbeats_2024_01 (
    id bigint DEFAULT nextval('public.heartbeats_id_seq'::regclass) NOT NULL,
    branch character varying,
    category character varying,
    created_at timestamp(6) without time zone NOT NULL,
    cursorpos integer,
    deleted_at timestamp(6) without time zone,
    dependencies character varying[] DEFAULT '{}'::character varying[],
    editor character varying,
    entity character varying,
    fields_hash text,
    ip_address inet,
    is_write boolean,
    language character varying,
    line_additions integer,
    line_deletions integer,
    lineno integer,
    lines integer,
    machine character varying,
    operating_system character varying,
    project character varying,
    project_root_count integer,
    raw_heartbeat_upload_id bigint,
    source_type integer NOT NULL,
    "time" double precision NOT NULL,
    type character varying,
    updated_at timestamp(6) without time zone NOT NULL,
    user_agent character varying,
    user_id bigint NOT NULL,
    ysws_program integer DEFAULT 0 NOT NULL
);


--
-- Name: heartbeats_2024_02; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.heartbeats_2024_02 (
    id bigint DEFAULT nextval('public.heartbeats_id_seq'::regclass) NOT NULL,
    branch character varying,
    category character varying,
    created_at timestamp(6) without time zone NOT NULL,
    cursorpos integer,
    deleted_at timestamp(6) without time zone,
    dependencies character varying[] DEFAULT '{}'::character varying[],
    editor character varying,
    entity character varying,
    fields_hash text,
    ip_address inet,
    is_write boolean,
    language character varying,
    line_additions integer,
    line_deletions integer,
    lineno integer,
    lines integer,
    machine character varying,
    operating_system character varying,
    project character varying,
    project_root_count integer,
    raw_heartbeat_upload_id bigint,
    source_type integer NOT NULL,
    "time" double precision NOT NULL,
    type character varying,
    updated_at timestamp(6) without time zone NOT NULL,
    user_agent character varying,
    user_id bigint NOT NULL,
    ysws_program integer DEFAULT 0 NOT NULL
);


--
-- Name: heartbeats_2024_03; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.heartbeats_2024_03 (
    id bigint DEFAULT nextval('public.heartbeats_id_seq'::regclass) NOT NULL,
    branch character varying,
    category character varying,
    created_at timestamp(6) without time zone NOT NULL,
    cursorpos integer,
    deleted_at timestamp(6) without time zone,
    dependencies character varying[] DEFAULT '{}'::character varying[],
    editor character varying,
    entity character varying,
    fields_hash text,
    ip_address inet,
    is_write boolean,
    language character varying,
    line_additions integer,
    line_deletions integer,
    lineno integer,
    lines integer,
    machine character varying,
    operating_system character varying,
    project character varying,
    project_root_count integer,
    raw_heartbeat_upload_id bigint,
    source_type integer NOT NULL,
    "time" double precision NOT NULL,
    type character varying,
    updated_at timestamp(6) without time zone NOT NULL,
    user_agent character varying,
    user_id bigint NOT NULL,
    ysws_program integer DEFAULT 0 NOT NULL
);


--
-- Name: heartbeats_2024_04; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.heartbeats_2024_04 (
    id bigint DEFAULT nextval('public.heartbeats_id_seq'::regclass) NOT NULL,
    branch character varying,
    category character varying,
    created_at timestamp(6) without time zone NOT NULL,
    cursorpos integer,
    deleted_at timestamp(6) without time zone,
    dependencies character varying[] DEFAULT '{}'::character varying[],
    editor character varying,
    entity character varying,
    fields_hash text,
    ip_address inet,
    is_write boolean,
    language character varying,
    line_additions integer,
    line_deletions integer,
    lineno integer,
    lines integer,
    machine character varying,
    operating_system character varying,
    project character varying,
    project_root_count integer,
    raw_heartbeat_upload_id bigint,
    source_type integer NOT NULL,
    "time" double precision NOT NULL,
    type character varying,
    updated_at timestamp(6) without time zone NOT NULL,
    user_agent character varying,
    user_id bigint NOT NULL,
    ysws_program integer DEFAULT 0 NOT NULL
);


--
-- Name: heartbeats_2024_05; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.heartbeats_2024_05 (
    id bigint DEFAULT nextval('public.heartbeats_id_seq'::regclass) NOT NULL,
    branch character varying,
    category character varying,
    created_at timestamp(6) without time zone NOT NULL,
    cursorpos integer,
    deleted_at timestamp(6) without time zone,
    dependencies character varying[] DEFAULT '{}'::character varying[],
    editor character varying,
    entity character varying,
    fields_hash text,
    ip_address inet,
    is_write boolean,
    language character varying,
    line_additions integer,
    line_deletions integer,
    lineno integer,
    lines integer,
    machine character varying,
    operating_system character varying,
    project character varying,
    project_root_count integer,
    raw_heartbeat_upload_id bigint,
    source_type integer NOT NULL,
    "time" double precision NOT NULL,
    type character varying,
    updated_at timestamp(6) without time zone NOT NULL,
    user_agent character varying,
    user_id bigint NOT NULL,
    ysws_program integer DEFAULT 0 NOT NULL
);


--
-- Name: heartbeats_2024_06; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.heartbeats_2024_06 (
    id bigint DEFAULT nextval('public.heartbeats_id_seq'::regclass) NOT NULL,
    branch character varying,
    category character varying,
    created_at timestamp(6) without time zone NOT NULL,
    cursorpos integer,
    deleted_at timestamp(6) without time zone,
    dependencies character varying[] DEFAULT '{}'::character varying[],
    editor character varying,
    entity character varying,
    fields_hash text,
    ip_address inet,
    is_write boolean,
    language character varying,
    line_additions integer,
    line_deletions integer,
    lineno integer,
    lines integer,
    machine character varying,
    operating_system character varying,
    project character varying,
    project_root_count integer,
    raw_heartbeat_upload_id bigint,
    source_type integer NOT NULL,
    "time" double precision NOT NULL,
    type character varying,
    updated_at timestamp(6) without time zone NOT NULL,
    user_agent character varying,
    user_id bigint NOT NULL,
    ysws_program integer DEFAULT 0 NOT NULL
);


--
-- Name: heartbeats_2024_07; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.heartbeats_2024_07 (
    id bigint DEFAULT nextval('public.heartbeats_id_seq'::regclass) NOT NULL,
    branch character varying,
    category character varying,
    created_at timestamp(6) without time zone NOT NULL,
    cursorpos integer,
    deleted_at timestamp(6) without time zone,
    dependencies character varying[] DEFAULT '{}'::character varying[],
    editor character varying,
    entity character varying,
    fields_hash text,
    ip_address inet,
    is_write boolean,
    language character varying,
    line_additions integer,
    line_deletions integer,
    lineno integer,
    lines integer,
    machine character varying,
    operating_system character varying,
    project character varying,
    project_root_count integer,
    raw_heartbeat_upload_id bigint,
    source_type integer NOT NULL,
    "time" double precision NOT NULL,
    type character varying,
    updated_at timestamp(6) without time zone NOT NULL,
    user_agent character varying,
    user_id bigint NOT NULL,
    ysws_program integer DEFAULT 0 NOT NULL
);


--
-- Name: heartbeats_2024_08; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.heartbeats_2024_08 (
    id bigint DEFAULT nextval('public.heartbeats_id_seq'::regclass) NOT NULL,
    branch character varying,
    category character varying,
    created_at timestamp(6) without time zone NOT NULL,
    cursorpos integer,
    deleted_at timestamp(6) without time zone,
    dependencies character varying[] DEFAULT '{}'::character varying[],
    editor character varying,
    entity character varying,
    fields_hash text,
    ip_address inet,
    is_write boolean,
    language character varying,
    line_additions integer,
    line_deletions integer,
    lineno integer,
    lines integer,
    machine character varying,
    operating_system character varying,
    project character varying,
    project_root_count integer,
    raw_heartbeat_upload_id bigint,
    source_type integer NOT NULL,
    "time" double precision NOT NULL,
    type character varying,
    updated_at timestamp(6) without time zone NOT NULL,
    user_agent character varying,
    user_id bigint NOT NULL,
    ysws_program integer DEFAULT 0 NOT NULL
);


--
-- Name: heartbeats_2024_09; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.heartbeats_2024_09 (
    id bigint DEFAULT nextval('public.heartbeats_id_seq'::regclass) NOT NULL,
    branch character varying,
    category character varying,
    created_at timestamp(6) without time zone NOT NULL,
    cursorpos integer,
    deleted_at timestamp(6) without time zone,
    dependencies character varying[] DEFAULT '{}'::character varying[],
    editor character varying,
    entity character varying,
    fields_hash text,
    ip_address inet,
    is_write boolean,
    language character varying,
    line_additions integer,
    line_deletions integer,
    lineno integer,
    lines integer,
    machine character varying,
    operating_system character varying,
    project character varying,
    project_root_count integer,
    raw_heartbeat_upload_id bigint,
    source_type integer NOT NULL,
    "time" double precision NOT NULL,
    type character varying,
    updated_at timestamp(6) without time zone NOT NULL,
    user_agent character varying,
    user_id bigint NOT NULL,
    ysws_program integer DEFAULT 0 NOT NULL
);


--
-- Name: heartbeats_2024_10; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.heartbeats_2024_10 (
    id bigint DEFAULT nextval('public.heartbeats_id_seq'::regclass) NOT NULL,
    branch character varying,
    category character varying,
    created_at timestamp(6) without time zone NOT NULL,
    cursorpos integer,
    deleted_at timestamp(6) without time zone,
    dependencies character varying[] DEFAULT '{}'::character varying[],
    editor character varying,
    entity character varying,
    fields_hash text,
    ip_address inet,
    is_write boolean,
    language character varying,
    line_additions integer,
    line_deletions integer,
    lineno integer,
    lines integer,
    machine character varying,
    operating_system character varying,
    project character varying,
    project_root_count integer,
    raw_heartbeat_upload_id bigint,
    source_type integer NOT NULL,
    "time" double precision NOT NULL,
    type character varying,
    updated_at timestamp(6) without time zone NOT NULL,
    user_agent character varying,
    user_id bigint NOT NULL,
    ysws_program integer DEFAULT 0 NOT NULL
);


--
-- Name: heartbeats_2024_11; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.heartbeats_2024_11 (
    id bigint DEFAULT nextval('public.heartbeats_id_seq'::regclass) NOT NULL,
    branch character varying,
    category character varying,
    created_at timestamp(6) without time zone NOT NULL,
    cursorpos integer,
    deleted_at timestamp(6) without time zone,
    dependencies character varying[] DEFAULT '{}'::character varying[],
    editor character varying,
    entity character varying,
    fields_hash text,
    ip_address inet,
    is_write boolean,
    language character varying,
    line_additions integer,
    line_deletions integer,
    lineno integer,
    lines integer,
    machine character varying,
    operating_system character varying,
    project character varying,
    project_root_count integer,
    raw_heartbeat_upload_id bigint,
    source_type integer NOT NULL,
    "time" double precision NOT NULL,
    type character varying,
    updated_at timestamp(6) without time zone NOT NULL,
    user_agent character varying,
    user_id bigint NOT NULL,
    ysws_program integer DEFAULT 0 NOT NULL
);


--
-- Name: heartbeats_2024_12; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.heartbeats_2024_12 (
    id bigint DEFAULT nextval('public.heartbeats_id_seq'::regclass) NOT NULL,
    branch character varying,
    category character varying,
    created_at timestamp(6) without time zone NOT NULL,
    cursorpos integer,
    deleted_at timestamp(6) without time zone,
    dependencies character varying[] DEFAULT '{}'::character varying[],
    editor character varying,
    entity character varying,
    fields_hash text,
    ip_address inet,
    is_write boolean,
    language character varying,
    line_additions integer,
    line_deletions integer,
    lineno integer,
    lines integer,
    machine character varying,
    operating_system character varying,
    project character varying,
    project_root_count integer,
    raw_heartbeat_upload_id bigint,
    source_type integer NOT NULL,
    "time" double precision NOT NULL,
    type character varying,
    updated_at timestamp(6) without time zone NOT NULL,
    user_agent character varying,
    user_id bigint NOT NULL,
    ysws_program integer DEFAULT 0 NOT NULL
);


--
-- Name: heartbeats_2025_01; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.heartbeats_2025_01 (
    id bigint DEFAULT nextval('public.heartbeats_id_seq'::regclass) NOT NULL,
    branch character varying,
    category character varying,
    created_at timestamp(6) without time zone NOT NULL,
    cursorpos integer,
    deleted_at timestamp(6) without time zone,
    dependencies character varying[] DEFAULT '{}'::character varying[],
    editor character varying,
    entity character varying,
    fields_hash text,
    ip_address inet,
    is_write boolean,
    language character varying,
    line_additions integer,
    line_deletions integer,
    lineno integer,
    lines integer,
    machine character varying,
    operating_system character varying,
    project character varying,
    project_root_count integer,
    raw_heartbeat_upload_id bigint,
    source_type integer NOT NULL,
    "time" double precision NOT NULL,
    type character varying,
    updated_at timestamp(6) without time zone NOT NULL,
    user_agent character varying,
    user_id bigint NOT NULL,
    ysws_program integer DEFAULT 0 NOT NULL
);


--
-- Name: heartbeats_2025_02; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.heartbeats_2025_02 (
    id bigint DEFAULT nextval('public.heartbeats_id_seq'::regclass) NOT NULL,
    branch character varying,
    category character varying,
    created_at timestamp(6) without time zone NOT NULL,
    cursorpos integer,
    deleted_at timestamp(6) without time zone,
    dependencies character varying[] DEFAULT '{}'::character varying[],
    editor character varying,
    entity character varying,
    fields_hash text,
    ip_address inet,
    is_write boolean,
    language character varying,
    line_additions integer,
    line_deletions integer,
    lineno integer,
    lines integer,
    machine character varying,
    operating_system character varying,
    project character varying,
    project_root_count integer,
    raw_heartbeat_upload_id bigint,
    source_type integer NOT NULL,
    "time" double precision NOT NULL,
    type character varying,
    updated_at timestamp(6) without time zone NOT NULL,
    user_agent character varying,
    user_id bigint NOT NULL,
    ysws_program integer DEFAULT 0 NOT NULL
);


--
-- Name: heartbeats_2025_03; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.heartbeats_2025_03 (
    id bigint DEFAULT nextval('public.heartbeats_id_seq'::regclass) NOT NULL,
    branch character varying,
    category character varying,
    created_at timestamp(6) without time zone NOT NULL,
    cursorpos integer,
    deleted_at timestamp(6) without time zone,
    dependencies character varying[] DEFAULT '{}'::character varying[],
    editor character varying,
    entity character varying,
    fields_hash text,
    ip_address inet,
    is_write boolean,
    language character varying,
    line_additions integer,
    line_deletions integer,
    lineno integer,
    lines integer,
    machine character varying,
    operating_system character varying,
    project character varying,
    project_root_count integer,
    raw_heartbeat_upload_id bigint,
    source_type integer NOT NULL,
    "time" double precision NOT NULL,
    type character varying,
    updated_at timestamp(6) without time zone NOT NULL,
    user_agent character varying,
    user_id bigint NOT NULL,
    ysws_program integer DEFAULT 0 NOT NULL
);


--
-- Name: heartbeats_2025_04; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.heartbeats_2025_04 (
    id bigint DEFAULT nextval('public.heartbeats_id_seq'::regclass) NOT NULL,
    branch character varying,
    category character varying,
    created_at timestamp(6) without time zone NOT NULL,
    cursorpos integer,
    deleted_at timestamp(6) without time zone,
    dependencies character varying[] DEFAULT '{}'::character varying[],
    editor character varying,
    entity character varying,
    fields_hash text,
    ip_address inet,
    is_write boolean,
    language character varying,
    line_additions integer,
    line_deletions integer,
    lineno integer,
    lines integer,
    machine character varying,
    operating_system character varying,
    project character varying,
    project_root_count integer,
    raw_heartbeat_upload_id bigint,
    source_type integer NOT NULL,
    "time" double precision NOT NULL,
    type character varying,
    updated_at timestamp(6) without time zone NOT NULL,
    user_agent character varying,
    user_id bigint NOT NULL,
    ysws_program integer DEFAULT 0 NOT NULL
);


--
-- Name: heartbeats_2025_05; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.heartbeats_2025_05 (
    id bigint DEFAULT nextval('public.heartbeats_id_seq'::regclass) NOT NULL,
    branch character varying,
    category character varying,
    created_at timestamp(6) without time zone NOT NULL,
    cursorpos integer,
    deleted_at timestamp(6) without time zone,
    dependencies character varying[] DEFAULT '{}'::character varying[],
    editor character varying,
    entity character varying,
    fields_hash text,
    ip_address inet,
    is_write boolean,
    language character varying,
    line_additions integer,
    line_deletions integer,
    lineno integer,
    lines integer,
    machine character varying,
    operating_system character varying,
    project character varying,
    project_root_count integer,
    raw_heartbeat_upload_id bigint,
    source_type integer NOT NULL,
    "time" double precision NOT NULL,
    type character varying,
    updated_at timestamp(6) without time zone NOT NULL,
    user_agent character varying,
    user_id bigint NOT NULL,
    ysws_program integer DEFAULT 0 NOT NULL
);


--
-- Name: heartbeats_2025_06; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.heartbeats_2025_06 (
    id bigint DEFAULT nextval('public.heartbeats_id_seq'::regclass) NOT NULL,
    branch character varying,
    category character varying,
    created_at timestamp(6) without time zone NOT NULL,
    cursorpos integer,
    deleted_at timestamp(6) without time zone,
    dependencies character varying[] DEFAULT '{}'::character varying[],
    editor character varying,
    entity character varying,
    fields_hash text,
    ip_address inet,
    is_write boolean,
    language character varying,
    line_additions integer,
    line_deletions integer,
    lineno integer,
    lines integer,
    machine character varying,
    operating_system character varying,
    project character varying,
    project_root_count integer,
    raw_heartbeat_upload_id bigint,
    source_type integer NOT NULL,
    "time" double precision NOT NULL,
    type character varying,
    updated_at timestamp(6) without time zone NOT NULL,
    user_agent character varying,
    user_id bigint NOT NULL,
    ysws_program integer DEFAULT 0 NOT NULL
);


--
-- Name: heartbeats_2025_07; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.heartbeats_2025_07 (
    id bigint DEFAULT nextval('public.heartbeats_id_seq'::regclass) NOT NULL,
    branch character varying,
    category character varying,
    created_at timestamp(6) without time zone NOT NULL,
    cursorpos integer,
    deleted_at timestamp(6) without time zone,
    dependencies character varying[] DEFAULT '{}'::character varying[],
    editor character varying,
    entity character varying,
    fields_hash text,
    ip_address inet,
    is_write boolean,
    language character varying,
    line_additions integer,
    line_deletions integer,
    lineno integer,
    lines integer,
    machine character varying,
    operating_system character varying,
    project character varying,
    project_root_count integer,
    raw_heartbeat_upload_id bigint,
    source_type integer NOT NULL,
    "time" double precision NOT NULL,
    type character varying,
    updated_at timestamp(6) without time zone NOT NULL,
    user_agent character varying,
    user_id bigint NOT NULL,
    ysws_program integer DEFAULT 0 NOT NULL
);


--
-- Name: heartbeats_2025_08; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.heartbeats_2025_08 (
    id bigint DEFAULT nextval('public.heartbeats_id_seq'::regclass) NOT NULL,
    branch character varying,
    category character varying,
    created_at timestamp(6) without time zone NOT NULL,
    cursorpos integer,
    deleted_at timestamp(6) without time zone,
    dependencies character varying[] DEFAULT '{}'::character varying[],
    editor character varying,
    entity character varying,
    fields_hash text,
    ip_address inet,
    is_write boolean,
    language character varying,
    line_additions integer,
    line_deletions integer,
    lineno integer,
    lines integer,
    machine character varying,
    operating_system character varying,
    project character varying,
    project_root_count integer,
    raw_heartbeat_upload_id bigint,
    source_type integer NOT NULL,
    "time" double precision NOT NULL,
    type character varying,
    updated_at timestamp(6) without time zone NOT NULL,
    user_agent character varying,
    user_id bigint NOT NULL,
    ysws_program integer DEFAULT 0 NOT NULL
);


--
-- Name: heartbeats_2025_09; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.heartbeats_2025_09 (
    id bigint DEFAULT nextval('public.heartbeats_id_seq'::regclass) NOT NULL,
    branch character varying,
    category character varying,
    created_at timestamp(6) without time zone NOT NULL,
    cursorpos integer,
    deleted_at timestamp(6) without time zone,
    dependencies character varying[] DEFAULT '{}'::character varying[],
    editor character varying,
    entity character varying,
    fields_hash text,
    ip_address inet,
    is_write boolean,
    language character varying,
    line_additions integer,
    line_deletions integer,
    lineno integer,
    lines integer,
    machine character varying,
    operating_system character varying,
    project character varying,
    project_root_count integer,
    raw_heartbeat_upload_id bigint,
    source_type integer NOT NULL,
    "time" double precision NOT NULL,
    type character varying,
    updated_at timestamp(6) without time zone NOT NULL,
    user_agent character varying,
    user_id bigint NOT NULL,
    ysws_program integer DEFAULT 0 NOT NULL
);


--
-- Name: heartbeats_2025_10; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.heartbeats_2025_10 (
    id bigint DEFAULT nextval('public.heartbeats_id_seq'::regclass) NOT NULL,
    branch character varying,
    category character varying,
    created_at timestamp(6) without time zone NOT NULL,
    cursorpos integer,
    deleted_at timestamp(6) without time zone,
    dependencies character varying[] DEFAULT '{}'::character varying[],
    editor character varying,
    entity character varying,
    fields_hash text,
    ip_address inet,
    is_write boolean,
    language character varying,
    line_additions integer,
    line_deletions integer,
    lineno integer,
    lines integer,
    machine character varying,
    operating_system character varying,
    project character varying,
    project_root_count integer,
    raw_heartbeat_upload_id bigint,
    source_type integer NOT NULL,
    "time" double precision NOT NULL,
    type character varying,
    updated_at timestamp(6) without time zone NOT NULL,
    user_agent character varying,
    user_id bigint NOT NULL,
    ysws_program integer DEFAULT 0 NOT NULL
);


--
-- Name: heartbeats_2025_11; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.heartbeats_2025_11 (
    id bigint DEFAULT nextval('public.heartbeats_id_seq'::regclass) NOT NULL,
    branch character varying,
    category character varying,
    created_at timestamp(6) without time zone NOT NULL,
    cursorpos integer,
    deleted_at timestamp(6) without time zone,
    dependencies character varying[] DEFAULT '{}'::character varying[],
    editor character varying,
    entity character varying,
    fields_hash text,
    ip_address inet,
    is_write boolean,
    language character varying,
    line_additions integer,
    line_deletions integer,
    lineno integer,
    lines integer,
    machine character varying,
    operating_system character varying,
    project character varying,
    project_root_count integer,
    raw_heartbeat_upload_id bigint,
    source_type integer NOT NULL,
    "time" double precision NOT NULL,
    type character varying,
    updated_at timestamp(6) without time zone NOT NULL,
    user_agent character varying,
    user_id bigint NOT NULL,
    ysws_program integer DEFAULT 0 NOT NULL
);


--
-- Name: heartbeats_2025_12; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.heartbeats_2025_12 (
    id bigint DEFAULT nextval('public.heartbeats_id_seq'::regclass) NOT NULL,
    branch character varying,
    category character varying,
    created_at timestamp(6) without time zone NOT NULL,
    cursorpos integer,
    deleted_at timestamp(6) without time zone,
    dependencies character varying[] DEFAULT '{}'::character varying[],
    editor character varying,
    entity character varying,
    fields_hash text,
    ip_address inet,
    is_write boolean,
    language character varying,
    line_additions integer,
    line_deletions integer,
    lineno integer,
    lines integer,
    machine character varying,
    operating_system character varying,
    project character varying,
    project_root_count integer,
    raw_heartbeat_upload_id bigint,
    source_type integer NOT NULL,
    "time" double precision NOT NULL,
    type character varying,
    updated_at timestamp(6) without time zone NOT NULL,
    user_agent character varying,
    user_id bigint NOT NULL,
    ysws_program integer DEFAULT 0 NOT NULL
);


--
-- Name: heartbeats_2026_01; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.heartbeats_2026_01 (
    id bigint DEFAULT nextval('public.heartbeats_id_seq'::regclass) NOT NULL,
    branch character varying,
    category character varying,
    created_at timestamp(6) without time zone NOT NULL,
    cursorpos integer,
    deleted_at timestamp(6) without time zone,
    dependencies character varying[] DEFAULT '{}'::character varying[],
    editor character varying,
    entity character varying,
    fields_hash text,
    ip_address inet,
    is_write boolean,
    language character varying,
    line_additions integer,
    line_deletions integer,
    lineno integer,
    lines integer,
    machine character varying,
    operating_system character varying,
    project character varying,
    project_root_count integer,
    raw_heartbeat_upload_id bigint,
    source_type integer NOT NULL,
    "time" double precision NOT NULL,
    type character varying,
    updated_at timestamp(6) without time zone NOT NULL,
    user_agent character varying,
    user_id bigint NOT NULL,
    ysws_program integer DEFAULT 0 NOT NULL
);


--
-- Name: heartbeats_2026_02; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.heartbeats_2026_02 (
    id bigint DEFAULT nextval('public.heartbeats_id_seq'::regclass) NOT NULL,
    branch character varying,
    category character varying,
    created_at timestamp(6) without time zone NOT NULL,
    cursorpos integer,
    deleted_at timestamp(6) without time zone,
    dependencies character varying[] DEFAULT '{}'::character varying[],
    editor character varying,
    entity character varying,
    fields_hash text,
    ip_address inet,
    is_write boolean,
    language character varying,
    line_additions integer,
    line_deletions integer,
    lineno integer,
    lines integer,
    machine character varying,
    operating_system character varying,
    project character varying,
    project_root_count integer,
    raw_heartbeat_upload_id bigint,
    source_type integer NOT NULL,
    "time" double precision NOT NULL,
    type character varying,
    updated_at timestamp(6) without time zone NOT NULL,
    user_agent character varying,
    user_id bigint NOT NULL,
    ysws_program integer DEFAULT 0 NOT NULL
);


--
-- Name: heartbeats_2026_03; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.heartbeats_2026_03 (
    id bigint DEFAULT nextval('public.heartbeats_id_seq'::regclass) NOT NULL,
    branch character varying,
    category character varying,
    created_at timestamp(6) without time zone NOT NULL,
    cursorpos integer,
    deleted_at timestamp(6) without time zone,
    dependencies character varying[] DEFAULT '{}'::character varying[],
    editor character varying,
    entity character varying,
    fields_hash text,
    ip_address inet,
    is_write boolean,
    language character varying,
    line_additions integer,
    line_deletions integer,
    lineno integer,
    lines integer,
    machine character varying,
    operating_system character varying,
    project character varying,
    project_root_count integer,
    raw_heartbeat_upload_id bigint,
    source_type integer NOT NULL,
    "time" double precision NOT NULL,
    type character varying,
    updated_at timestamp(6) without time zone NOT NULL,
    user_agent character varying,
    user_id bigint NOT NULL,
    ysws_program integer DEFAULT 0 NOT NULL
);


--
-- Name: heartbeats_2026_04; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.heartbeats_2026_04 (
    id bigint DEFAULT nextval('public.heartbeats_id_seq'::regclass) NOT NULL,
    branch character varying,
    category character varying,
    created_at timestamp(6) without time zone NOT NULL,
    cursorpos integer,
    deleted_at timestamp(6) without time zone,
    dependencies character varying[] DEFAULT '{}'::character varying[],
    editor character varying,
    entity character varying,
    fields_hash text,
    ip_address inet,
    is_write boolean,
    language character varying,
    line_additions integer,
    line_deletions integer,
    lineno integer,
    lines integer,
    machine character varying,
    operating_system character varying,
    project character varying,
    project_root_count integer,
    raw_heartbeat_upload_id bigint,
    source_type integer NOT NULL,
    "time" double precision NOT NULL,
    type character varying,
    updated_at timestamp(6) without time zone NOT NULL,
    user_agent character varying,
    user_id bigint NOT NULL,
    ysws_program integer DEFAULT 0 NOT NULL
);


--
-- Name: heartbeats_2026_05; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.heartbeats_2026_05 (
    id bigint DEFAULT nextval('public.heartbeats_id_seq'::regclass) NOT NULL,
    branch character varying,
    category character varying,
    created_at timestamp(6) without time zone NOT NULL,
    cursorpos integer,
    deleted_at timestamp(6) without time zone,
    dependencies character varying[] DEFAULT '{}'::character varying[],
    editor character varying,
    entity character varying,
    fields_hash text,
    ip_address inet,
    is_write boolean,
    language character varying,
    line_additions integer,
    line_deletions integer,
    lineno integer,
    lines integer,
    machine character varying,
    operating_system character varying,
    project character varying,
    project_root_count integer,
    raw_heartbeat_upload_id bigint,
    source_type integer NOT NULL,
    "time" double precision NOT NULL,
    type character varying,
    updated_at timestamp(6) without time zone NOT NULL,
    user_agent character varying,
    user_id bigint NOT NULL,
    ysws_program integer DEFAULT 0 NOT NULL
);


--
-- Name: heartbeats_2026_06; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.heartbeats_2026_06 (
    id bigint DEFAULT nextval('public.heartbeats_id_seq'::regclass) NOT NULL,
    branch character varying,
    category character varying,
    created_at timestamp(6) without time zone NOT NULL,
    cursorpos integer,
    deleted_at timestamp(6) without time zone,
    dependencies character varying[] DEFAULT '{}'::character varying[],
    editor character varying,
    entity character varying,
    fields_hash text,
    ip_address inet,
    is_write boolean,
    language character varying,
    line_additions integer,
    line_deletions integer,
    lineno integer,
    lines integer,
    machine character varying,
    operating_system character varying,
    project character varying,
    project_root_count integer,
    raw_heartbeat_upload_id bigint,
    source_type integer NOT NULL,
    "time" double precision NOT NULL,
    type character varying,
    updated_at timestamp(6) without time zone NOT NULL,
    user_agent character varying,
    user_id bigint NOT NULL,
    ysws_program integer DEFAULT 0 NOT NULL
);


--
-- Name: heartbeats_2026_07; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.heartbeats_2026_07 (
    id bigint DEFAULT nextval('public.heartbeats_id_seq'::regclass) NOT NULL,
    branch character varying,
    category character varying,
    created_at timestamp(6) without time zone NOT NULL,
    cursorpos integer,
    deleted_at timestamp(6) without time zone,
    dependencies character varying[] DEFAULT '{}'::character varying[],
    editor character varying,
    entity character varying,
    fields_hash text,
    ip_address inet,
    is_write boolean,
    language character varying,
    line_additions integer,
    line_deletions integer,
    lineno integer,
    lines integer,
    machine character varying,
    operating_system character varying,
    project character varying,
    project_root_count integer,
    raw_heartbeat_upload_id bigint,
    source_type integer NOT NULL,
    "time" double precision NOT NULL,
    type character varying,
    updated_at timestamp(6) without time zone NOT NULL,
    user_agent character varying,
    user_id bigint NOT NULL,
    ysws_program integer DEFAULT 0 NOT NULL
);


--
-- Name: heartbeats_before_2024; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.heartbeats_before_2024 (
    id bigint DEFAULT nextval('public.heartbeats_id_seq'::regclass) NOT NULL,
    branch character varying,
    category character varying,
    created_at timestamp(6) without time zone NOT NULL,
    cursorpos integer,
    deleted_at timestamp(6) without time zone,
    dependencies character varying[] DEFAULT '{}'::character varying[],
    editor character varying,
    entity character varying,
    fields_hash text,
    ip_address inet,
    is_write boolean,
    language character varying,
    line_additions integer,
    line_deletions integer,
    lineno integer,
    lines integer,
    machine character varying,
    operating_system character varying,
    project character varying,
    project_root_count integer,
    raw_heartbeat_upload_id bigint,
    source_type integer NOT NULL,
    "time" double precision NOT NULL,
    type character varying,
    updated_at timestamp(6) without time zone NOT NULL,
    user_agent character varying,
    user_id bigint NOT NULL,
    ysws_program integer DEFAULT 0 NOT NULL
);


--
-- Name: heartbeats_default; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.heartbeats_default (
    id bigint DEFAULT nextval('public.heartbeats_id_seq'::regclass) NOT NULL,
    branch character varying,
    category character varying,
    created_at timestamp(6) without time zone NOT NULL,
    cursorpos integer,
    deleted_at timestamp(6) without time zone,
    dependencies character varying[] DEFAULT '{}'::character varying[],
    editor character varying,
    entity character varying,
    fields_hash text,
    ip_address inet,
    is_write boolean,
    language character varying,
    line_additions integer,
    line_deletions integer,
    lineno integer,
    lines integer,
    machine character varying,
    operating_system character varying,
    project character varying,
    project_root_count integer,
    raw_heartbeat_upload_id bigint,
    source_type integer NOT NULL,
    "time" double precision NOT NULL,
    type character varying,
    updated_at timestamp(6) without time zone NOT NULL,
    user_agent character varying,
    user_id bigint NOT NULL,
    ysws_program integer DEFAULT 0 NOT NULL
);


--
-- Name: leaderboard_entries; Type: TABLE; Schema: public; Owner: -
--

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


--
-- Name: leaderboard_entries_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.leaderboard_entries_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: leaderboard_entries_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.leaderboard_entries_id_seq OWNED BY public.leaderboard_entries.id;


--
-- Name: leaderboards; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.leaderboards (
    id bigint NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    deleted_at timestamp(6) without time zone,
    finished_generating_at timestamp(6) without time zone,
    period_type integer DEFAULT 0 NOT NULL,
    start_date date NOT NULL,
    timezone_offset integer,
    timezone_utc_offset integer,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: leaderboards_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.leaderboards_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: leaderboards_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.leaderboards_id_seq OWNED BY public.leaderboards.id;


--
-- Name: mailkick_subscriptions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.mailkick_subscriptions (
    id bigint NOT NULL,
    subscriber_type character varying,
    subscriber_id bigint,
    list character varying,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: mailkick_subscriptions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.mailkick_subscriptions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: mailkick_subscriptions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.mailkick_subscriptions_id_seq OWNED BY public.mailkick_subscriptions.id;


--
-- Name: notable_jobs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.notable_jobs (
    id bigint NOT NULL,
    note_type character varying,
    note text,
    job text,
    job_id character varying,
    queue character varying,
    runtime double precision,
    queued_time double precision,
    created_at timestamp(6) without time zone
);


--
-- Name: notable_jobs_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.notable_jobs_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: notable_jobs_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.notable_jobs_id_seq OWNED BY public.notable_jobs.id;


--
-- Name: notable_requests; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.notable_requests (
    id bigint NOT NULL,
    note_type character varying,
    note text,
    user_type character varying,
    user_id bigint,
    action text,
    status integer,
    url text,
    request_id character varying,
    ip character varying,
    user_agent text,
    referrer text,
    params text,
    request_time double precision,
    created_at timestamp(6) without time zone
);


--
-- Name: notable_requests_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.notable_requests_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: notable_requests_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.notable_requests_id_seq OWNED BY public.notable_requests.id;


--
-- Name: oauth_access_grants; Type: TABLE; Schema: public; Owner: -
--

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


--
-- Name: oauth_access_grants_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.oauth_access_grants_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: oauth_access_grants_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.oauth_access_grants_id_seq OWNED BY public.oauth_access_grants.id;


--
-- Name: oauth_access_tokens; Type: TABLE; Schema: public; Owner: -
--

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


--
-- Name: oauth_access_tokens_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.oauth_access_tokens_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: oauth_access_tokens_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.oauth_access_tokens_id_seq OWNED BY public.oauth_access_tokens.id;


--
-- Name: oauth_applications; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.oauth_applications (
    id bigint NOT NULL,
    confidential boolean DEFAULT true NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    name character varying NOT NULL,
    owner_id bigint,
    owner_type character varying,
    redirect_uri text NOT NULL,
    scopes character varying DEFAULT ''::character varying NOT NULL,
    secret character varying NOT NULL,
    uid character varying NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    verified boolean DEFAULT false NOT NULL
);


--
-- Name: oauth_applications_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.oauth_applications_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: oauth_applications_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.oauth_applications_id_seq OWNED BY public.oauth_applications.id;


--
-- Name: pghero_query_stats; Type: TABLE; Schema: public; Owner: -
--

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


--
-- Name: pghero_query_stats_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.pghero_query_stats_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: pghero_query_stats_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.pghero_query_stats_id_seq OWNED BY public.pghero_query_stats.id;


--
-- Name: pghero_space_stats; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.pghero_space_stats (
    id bigint NOT NULL,
    captured_at timestamp without time zone,
    database text,
    relation text,
    schema text,
    size bigint
);


--
-- Name: pghero_space_stats_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.pghero_space_stats_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: pghero_space_stats_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.pghero_space_stats_id_seq OWNED BY public.pghero_space_stats.id;


--
-- Name: project_labels; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.project_labels (
    id bigint NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    label character varying,
    project_key character varying,
    updated_at timestamp(6) without time zone NOT NULL,
    user_id character varying
);


--
-- Name: project_labels_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.project_labels_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: project_labels_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.project_labels_id_seq OWNED BY public.project_labels.id;


--
-- Name: project_repo_mappings; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.project_repo_mappings (
    id bigint NOT NULL,
    archived_at timestamp(6) without time zone,
    created_at timestamp(6) without time zone NOT NULL,
    project_name character varying NOT NULL,
    repo_url character varying,
    repository_id bigint,
    updated_at timestamp(6) without time zone NOT NULL,
    user_id bigint NOT NULL,
    public_shared_at timestamp(6) without time zone
);


--
-- Name: project_repo_mappings_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.project_repo_mappings_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: project_repo_mappings_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.project_repo_mappings_id_seq OWNED BY public.project_repo_mappings.id;


--
-- Name: raw_heartbeat_uploads; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.raw_heartbeat_uploads (
    id bigint NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    request_body jsonb NOT NULL,
    request_headers jsonb NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: raw_heartbeat_uploads_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.raw_heartbeat_uploads_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: raw_heartbeat_uploads_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.raw_heartbeat_uploads_id_seq OWNED BY public.raw_heartbeat_uploads.id;


--
-- Name: repo_host_events; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.repo_host_events (
    id character varying NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    provider integer DEFAULT 0 NOT NULL,
    raw_event_payload jsonb NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    user_id bigint NOT NULL
);


--
-- Name: repositories; Type: TABLE; Schema: public; Owner: -
--

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


--
-- Name: repositories_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.repositories_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: repositories_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.repositories_id_seq OWNED BY public.repositories.id;


--
-- Name: sailors_log_leaderboards; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.sailors_log_leaderboards (
    id bigint NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    deleted_at timestamp(6) without time zone,
    message text,
    slack_channel_id character varying,
    slack_uid character varying,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: sailors_log_leaderboards_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.sailors_log_leaderboards_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: sailors_log_leaderboards_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.sailors_log_leaderboards_id_seq OWNED BY public.sailors_log_leaderboards.id;


--
-- Name: sailors_log_notification_preferences; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.sailors_log_notification_preferences (
    id bigint NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    enabled boolean DEFAULT true NOT NULL,
    slack_channel_id character varying NOT NULL,
    slack_uid character varying NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: sailors_log_notification_preferences_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.sailors_log_notification_preferences_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: sailors_log_notification_preferences_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.sailors_log_notification_preferences_id_seq OWNED BY public.sailors_log_notification_preferences.id;


--
-- Name: sailors_log_slack_notifications; Type: TABLE; Schema: public; Owner: -
--

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


--
-- Name: sailors_log_slack_notifications_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.sailors_log_slack_notifications_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: sailors_log_slack_notifications_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.sailors_log_slack_notifications_id_seq OWNED BY public.sailors_log_slack_notifications.id;


--
-- Name: sailors_logs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.sailors_logs (
    id bigint NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    projects_summary jsonb DEFAULT '{}'::jsonb NOT NULL,
    slack_uid character varying NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: sailors_logs_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.sailors_logs_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: sailors_logs_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.sailors_logs_id_seq OWNED BY public.sailors_logs.id;


--
-- Name: schema_migrations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.schema_migrations (
    version character varying NOT NULL
);


--
-- Name: sign_in_tokens; Type: TABLE; Schema: public; Owner: -
--

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


--
-- Name: sign_in_tokens_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.sign_in_tokens_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: sign_in_tokens_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.sign_in_tokens_id_seq OWNED BY public.sign_in_tokens.id;


--
-- Name: solid_cache_entries; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.solid_cache_entries (
    id bigint NOT NULL,
    byte_size integer NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    key bytea NOT NULL,
    key_hash bigint NOT NULL,
    value bytea NOT NULL
);


--
-- Name: solid_cache_entries_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.solid_cache_entries_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: solid_cache_entries_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.solid_cache_entries_id_seq OWNED BY public.solid_cache_entries.id;


--
-- Name: trust_level_audit_logs; Type: TABLE; Schema: public; Owner: -
--

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


--
-- Name: trust_level_audit_logs_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.trust_level_audit_logs_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: trust_level_audit_logs_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.trust_level_audit_logs_id_seq OWNED BY public.trust_level_audit_logs.id;


--
-- Name: users; Type: TABLE; Schema: public; Owner: -
--

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
    profile_bio text,
    profile_bluesky_url character varying,
    profile_discord_url character varying,
    profile_github_url character varying,
    profile_linkedin_url character varying,
    profile_twitter_url character varying,
    profile_website_url character varying,
    slack_access_token text,
    slack_avatar_url character varying,
    slack_scopes character varying[] DEFAULT '{}'::character varying[],
    slack_synced_at timestamp(6) without time zone,
    slack_uid character varying,
    slack_username character varying,
    theme integer DEFAULT 4 NOT NULL,
    timezone character varying DEFAULT 'UTC'::character varying,
    trust_level integer DEFAULT 0 NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    username character varying,
    uses_slack_status boolean DEFAULT false NOT NULL,
    weekly_summary_email_enabled boolean DEFAULT false NOT NULL
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
-- Name: versions; Type: TABLE; Schema: public; Owner: -
--

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


--
-- Name: versions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.versions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: versions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.versions_id_seq OWNED BY public.versions.id;


--
-- Name: heartbeats_2024_01; Type: TABLE ATTACH; Schema: public; Owner: -
--

ALTER TABLE ONLY public.heartbeats ATTACH PARTITION public.heartbeats_2024_01 FOR VALUES FROM ('1704067200') TO ('1706745600');


--
-- Name: heartbeats_2024_02; Type: TABLE ATTACH; Schema: public; Owner: -
--

ALTER TABLE ONLY public.heartbeats ATTACH PARTITION public.heartbeats_2024_02 FOR VALUES FROM ('1706745600') TO ('1709251200');


--
-- Name: heartbeats_2024_03; Type: TABLE ATTACH; Schema: public; Owner: -
--

ALTER TABLE ONLY public.heartbeats ATTACH PARTITION public.heartbeats_2024_03 FOR VALUES FROM ('1709251200') TO ('1711929600');


--
-- Name: heartbeats_2024_04; Type: TABLE ATTACH; Schema: public; Owner: -
--

ALTER TABLE ONLY public.heartbeats ATTACH PARTITION public.heartbeats_2024_04 FOR VALUES FROM ('1711929600') TO ('1714521600');


--
-- Name: heartbeats_2024_05; Type: TABLE ATTACH; Schema: public; Owner: -
--

ALTER TABLE ONLY public.heartbeats ATTACH PARTITION public.heartbeats_2024_05 FOR VALUES FROM ('1714521600') TO ('1717200000');


--
-- Name: heartbeats_2024_06; Type: TABLE ATTACH; Schema: public; Owner: -
--

ALTER TABLE ONLY public.heartbeats ATTACH PARTITION public.heartbeats_2024_06 FOR VALUES FROM ('1717200000') TO ('1719792000');


--
-- Name: heartbeats_2024_07; Type: TABLE ATTACH; Schema: public; Owner: -
--

ALTER TABLE ONLY public.heartbeats ATTACH PARTITION public.heartbeats_2024_07 FOR VALUES FROM ('1719792000') TO ('1722470400');


--
-- Name: heartbeats_2024_08; Type: TABLE ATTACH; Schema: public; Owner: -
--

ALTER TABLE ONLY public.heartbeats ATTACH PARTITION public.heartbeats_2024_08 FOR VALUES FROM ('1722470400') TO ('1725148800');


--
-- Name: heartbeats_2024_09; Type: TABLE ATTACH; Schema: public; Owner: -
--

ALTER TABLE ONLY public.heartbeats ATTACH PARTITION public.heartbeats_2024_09 FOR VALUES FROM ('1725148800') TO ('1727740800');


--
-- Name: heartbeats_2024_10; Type: TABLE ATTACH; Schema: public; Owner: -
--

ALTER TABLE ONLY public.heartbeats ATTACH PARTITION public.heartbeats_2024_10 FOR VALUES FROM ('1727740800') TO ('1730419200');


--
-- Name: heartbeats_2024_11; Type: TABLE ATTACH; Schema: public; Owner: -
--

ALTER TABLE ONLY public.heartbeats ATTACH PARTITION public.heartbeats_2024_11 FOR VALUES FROM ('1730419200') TO ('1733011200');


--
-- Name: heartbeats_2024_12; Type: TABLE ATTACH; Schema: public; Owner: -
--

ALTER TABLE ONLY public.heartbeats ATTACH PARTITION public.heartbeats_2024_12 FOR VALUES FROM ('1733011200') TO ('1735689600');


--
-- Name: heartbeats_2025_01; Type: TABLE ATTACH; Schema: public; Owner: -
--

ALTER TABLE ONLY public.heartbeats ATTACH PARTITION public.heartbeats_2025_01 FOR VALUES FROM ('1735689600') TO ('1738368000');


--
-- Name: heartbeats_2025_02; Type: TABLE ATTACH; Schema: public; Owner: -
--

ALTER TABLE ONLY public.heartbeats ATTACH PARTITION public.heartbeats_2025_02 FOR VALUES FROM ('1738368000') TO ('1740787200');


--
-- Name: heartbeats_2025_03; Type: TABLE ATTACH; Schema: public; Owner: -
--

ALTER TABLE ONLY public.heartbeats ATTACH PARTITION public.heartbeats_2025_03 FOR VALUES FROM ('1740787200') TO ('1743465600');


--
-- Name: heartbeats_2025_04; Type: TABLE ATTACH; Schema: public; Owner: -
--

ALTER TABLE ONLY public.heartbeats ATTACH PARTITION public.heartbeats_2025_04 FOR VALUES FROM ('1743465600') TO ('1746057600');


--
-- Name: heartbeats_2025_05; Type: TABLE ATTACH; Schema: public; Owner: -
--

ALTER TABLE ONLY public.heartbeats ATTACH PARTITION public.heartbeats_2025_05 FOR VALUES FROM ('1746057600') TO ('1748736000');


--
-- Name: heartbeats_2025_06; Type: TABLE ATTACH; Schema: public; Owner: -
--

ALTER TABLE ONLY public.heartbeats ATTACH PARTITION public.heartbeats_2025_06 FOR VALUES FROM ('1748736000') TO ('1751328000');


--
-- Name: heartbeats_2025_07; Type: TABLE ATTACH; Schema: public; Owner: -
--

ALTER TABLE ONLY public.heartbeats ATTACH PARTITION public.heartbeats_2025_07 FOR VALUES FROM ('1751328000') TO ('1754006400');


--
-- Name: heartbeats_2025_08; Type: TABLE ATTACH; Schema: public; Owner: -
--

ALTER TABLE ONLY public.heartbeats ATTACH PARTITION public.heartbeats_2025_08 FOR VALUES FROM ('1754006400') TO ('1756684800');


--
-- Name: heartbeats_2025_09; Type: TABLE ATTACH; Schema: public; Owner: -
--

ALTER TABLE ONLY public.heartbeats ATTACH PARTITION public.heartbeats_2025_09 FOR VALUES FROM ('1756684800') TO ('1759276800');


--
-- Name: heartbeats_2025_10; Type: TABLE ATTACH; Schema: public; Owner: -
--

ALTER TABLE ONLY public.heartbeats ATTACH PARTITION public.heartbeats_2025_10 FOR VALUES FROM ('1759276800') TO ('1761955200');


--
-- Name: heartbeats_2025_11; Type: TABLE ATTACH; Schema: public; Owner: -
--

ALTER TABLE ONLY public.heartbeats ATTACH PARTITION public.heartbeats_2025_11 FOR VALUES FROM ('1761955200') TO ('1764547200');


--
-- Name: heartbeats_2025_12; Type: TABLE ATTACH; Schema: public; Owner: -
--

ALTER TABLE ONLY public.heartbeats ATTACH PARTITION public.heartbeats_2025_12 FOR VALUES FROM ('1764547200') TO ('1767225600');


--
-- Name: heartbeats_2026_01; Type: TABLE ATTACH; Schema: public; Owner: -
--

ALTER TABLE ONLY public.heartbeats ATTACH PARTITION public.heartbeats_2026_01 FOR VALUES FROM ('1767225600') TO ('1769904000');


--
-- Name: heartbeats_2026_02; Type: TABLE ATTACH; Schema: public; Owner: -
--

ALTER TABLE ONLY public.heartbeats ATTACH PARTITION public.heartbeats_2026_02 FOR VALUES FROM ('1769904000') TO ('1772323200');


--
-- Name: heartbeats_2026_03; Type: TABLE ATTACH; Schema: public; Owner: -
--

ALTER TABLE ONLY public.heartbeats ATTACH PARTITION public.heartbeats_2026_03 FOR VALUES FROM ('1772323200') TO ('1775001600');


--
-- Name: heartbeats_2026_04; Type: TABLE ATTACH; Schema: public; Owner: -
--

ALTER TABLE ONLY public.heartbeats ATTACH PARTITION public.heartbeats_2026_04 FOR VALUES FROM ('1775001600') TO ('1777593600');


--
-- Name: heartbeats_2026_05; Type: TABLE ATTACH; Schema: public; Owner: -
--

ALTER TABLE ONLY public.heartbeats ATTACH PARTITION public.heartbeats_2026_05 FOR VALUES FROM ('1777593600') TO ('1780272000');


--
-- Name: heartbeats_2026_06; Type: TABLE ATTACH; Schema: public; Owner: -
--

ALTER TABLE ONLY public.heartbeats ATTACH PARTITION public.heartbeats_2026_06 FOR VALUES FROM ('1780272000') TO ('1782864000');


--
-- Name: heartbeats_2026_07; Type: TABLE ATTACH; Schema: public; Owner: -
--

ALTER TABLE ONLY public.heartbeats ATTACH PARTITION public.heartbeats_2026_07 FOR VALUES FROM ('1782864000') TO ('1785542400');


--
-- Name: heartbeats_before_2024; Type: TABLE ATTACH; Schema: public; Owner: -
--

ALTER TABLE ONLY public.heartbeats ATTACH PARTITION public.heartbeats_before_2024 FOR VALUES FROM (MINVALUE) TO ('1704067200');


--
-- Name: heartbeats_default; Type: TABLE ATTACH; Schema: public; Owner: -
--

ALTER TABLE ONLY public.heartbeats ATTACH PARTITION public.heartbeats_default FOR VALUES FROM ('1785542400') TO (MAXVALUE);


--
-- Name: active_storage_attachments id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.active_storage_attachments ALTER COLUMN id SET DEFAULT nextval('public.active_storage_attachments_id_seq'::regclass);


--
-- Name: active_storage_blobs id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.active_storage_blobs ALTER COLUMN id SET DEFAULT nextval('public.active_storage_blobs_id_seq'::regclass);


--
-- Name: active_storage_variant_records id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.active_storage_variant_records ALTER COLUMN id SET DEFAULT nextval('public.active_storage_variant_records_id_seq'::regclass);


--
-- Name: admin_api_keys id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.admin_api_keys ALTER COLUMN id SET DEFAULT nextval('public.admin_api_keys_id_seq'::regclass);


--
-- Name: api_keys id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.api_keys ALTER COLUMN id SET DEFAULT nextval('public.api_keys_id_seq'::regclass);


--
-- Name: deletion_requests id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.deletion_requests ALTER COLUMN id SET DEFAULT nextval('public.deletion_requests_id_seq'::regclass);


--
-- Name: email_addresses id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.email_addresses ALTER COLUMN id SET DEFAULT nextval('public.email_addresses_id_seq'::regclass);


--
-- Name: email_verification_requests id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.email_verification_requests ALTER COLUMN id SET DEFAULT nextval('public.email_verification_requests_id_seq'::regclass);


--
-- Name: flipper_features id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.flipper_features ALTER COLUMN id SET DEFAULT nextval('public.flipper_features_id_seq'::regclass);


--
-- Name: flipper_gates id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.flipper_gates ALTER COLUMN id SET DEFAULT nextval('public.flipper_gates_id_seq'::regclass);


--
-- Name: goals id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.goals ALTER COLUMN id SET DEFAULT nextval('public.goals_id_seq'::regclass);


--
-- Name: heartbeat_branches id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.heartbeat_branches ALTER COLUMN id SET DEFAULT nextval('public.heartbeat_branches_id_seq'::regclass);


--
-- Name: heartbeat_categories id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.heartbeat_categories ALTER COLUMN id SET DEFAULT nextval('public.heartbeat_categories_id_seq'::regclass);


--
-- Name: heartbeat_editors id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.heartbeat_editors ALTER COLUMN id SET DEFAULT nextval('public.heartbeat_editors_id_seq'::regclass);


--
-- Name: heartbeat_import_sources id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.heartbeat_import_sources ALTER COLUMN id SET DEFAULT nextval('public.heartbeat_import_sources_id_seq'::regclass);


--
-- Name: heartbeat_languages id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.heartbeat_languages ALTER COLUMN id SET DEFAULT nextval('public.heartbeat_languages_id_seq'::regclass);


--
-- Name: heartbeat_machines id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.heartbeat_machines ALTER COLUMN id SET DEFAULT nextval('public.heartbeat_machines_id_seq'::regclass);


--
-- Name: heartbeat_operating_systems id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.heartbeat_operating_systems ALTER COLUMN id SET DEFAULT nextval('public.heartbeat_operating_systems_id_seq'::regclass);


--
-- Name: heartbeat_projects id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.heartbeat_projects ALTER COLUMN id SET DEFAULT nextval('public.heartbeat_projects_id_seq'::regclass);


--
-- Name: heartbeat_user_agents id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.heartbeat_user_agents ALTER COLUMN id SET DEFAULT nextval('public.heartbeat_user_agents_id_seq'::regclass);


--
-- Name: heartbeats id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.heartbeats ALTER COLUMN id SET DEFAULT nextval('public.heartbeats_id_seq'::regclass);


--
-- Name: leaderboard_entries id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.leaderboard_entries ALTER COLUMN id SET DEFAULT nextval('public.leaderboard_entries_id_seq'::regclass);


--
-- Name: leaderboards id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.leaderboards ALTER COLUMN id SET DEFAULT nextval('public.leaderboards_id_seq'::regclass);


--
-- Name: mailkick_subscriptions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.mailkick_subscriptions ALTER COLUMN id SET DEFAULT nextval('public.mailkick_subscriptions_id_seq'::regclass);


--
-- Name: notable_jobs id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.notable_jobs ALTER COLUMN id SET DEFAULT nextval('public.notable_jobs_id_seq'::regclass);


--
-- Name: notable_requests id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.notable_requests ALTER COLUMN id SET DEFAULT nextval('public.notable_requests_id_seq'::regclass);


--
-- Name: oauth_access_grants id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.oauth_access_grants ALTER COLUMN id SET DEFAULT nextval('public.oauth_access_grants_id_seq'::regclass);


--
-- Name: oauth_access_tokens id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.oauth_access_tokens ALTER COLUMN id SET DEFAULT nextval('public.oauth_access_tokens_id_seq'::regclass);


--
-- Name: oauth_applications id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.oauth_applications ALTER COLUMN id SET DEFAULT nextval('public.oauth_applications_id_seq'::regclass);


--
-- Name: pghero_query_stats id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pghero_query_stats ALTER COLUMN id SET DEFAULT nextval('public.pghero_query_stats_id_seq'::regclass);


--
-- Name: pghero_space_stats id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pghero_space_stats ALTER COLUMN id SET DEFAULT nextval('public.pghero_space_stats_id_seq'::regclass);


--
-- Name: project_labels id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.project_labels ALTER COLUMN id SET DEFAULT nextval('public.project_labels_id_seq'::regclass);


--
-- Name: project_repo_mappings id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.project_repo_mappings ALTER COLUMN id SET DEFAULT nextval('public.project_repo_mappings_id_seq'::regclass);


--
-- Name: raw_heartbeat_uploads id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.raw_heartbeat_uploads ALTER COLUMN id SET DEFAULT nextval('public.raw_heartbeat_uploads_id_seq'::regclass);


--
-- Name: repositories id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.repositories ALTER COLUMN id SET DEFAULT nextval('public.repositories_id_seq'::regclass);


--
-- Name: sailors_log_leaderboards id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sailors_log_leaderboards ALTER COLUMN id SET DEFAULT nextval('public.sailors_log_leaderboards_id_seq'::regclass);


--
-- Name: sailors_log_notification_preferences id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sailors_log_notification_preferences ALTER COLUMN id SET DEFAULT nextval('public.sailors_log_notification_preferences_id_seq'::regclass);


--
-- Name: sailors_log_slack_notifications id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sailors_log_slack_notifications ALTER COLUMN id SET DEFAULT nextval('public.sailors_log_slack_notifications_id_seq'::regclass);


--
-- Name: sailors_logs id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sailors_logs ALTER COLUMN id SET DEFAULT nextval('public.sailors_logs_id_seq'::regclass);


--
-- Name: sign_in_tokens id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sign_in_tokens ALTER COLUMN id SET DEFAULT nextval('public.sign_in_tokens_id_seq'::regclass);


--
-- Name: solid_cache_entries id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.solid_cache_entries ALTER COLUMN id SET DEFAULT nextval('public.solid_cache_entries_id_seq'::regclass);


--
-- Name: trust_level_audit_logs id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.trust_level_audit_logs ALTER COLUMN id SET DEFAULT nextval('public.trust_level_audit_logs_id_seq'::regclass);


--
-- Name: users id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users ALTER COLUMN id SET DEFAULT nextval('public.users_id_seq'::regclass);


--
-- Name: versions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.versions ALTER COLUMN id SET DEFAULT nextval('public.versions_id_seq'::regclass);


--
-- Name: active_storage_attachments active_storage_attachments_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.active_storage_attachments
    ADD CONSTRAINT active_storage_attachments_pkey PRIMARY KEY (id);


--
-- Name: active_storage_blobs active_storage_blobs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.active_storage_blobs
    ADD CONSTRAINT active_storage_blobs_pkey PRIMARY KEY (id);


--
-- Name: active_storage_variant_records active_storage_variant_records_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.active_storage_variant_records
    ADD CONSTRAINT active_storage_variant_records_pkey PRIMARY KEY (id);


--
-- Name: admin_api_keys admin_api_keys_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.admin_api_keys
    ADD CONSTRAINT admin_api_keys_pkey PRIMARY KEY (id);


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
-- Name: commits commits_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.commits
    ADD CONSTRAINT commits_pkey PRIMARY KEY (sha);


--
-- Name: deletion_requests deletion_requests_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.deletion_requests
    ADD CONSTRAINT deletion_requests_pkey PRIMARY KEY (id);


--
-- Name: email_addresses email_addresses_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.email_addresses
    ADD CONSTRAINT email_addresses_pkey PRIMARY KEY (id);


--
-- Name: email_verification_requests email_verification_requests_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.email_verification_requests
    ADD CONSTRAINT email_verification_requests_pkey PRIMARY KEY (id);


--
-- Name: flipper_features flipper_features_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.flipper_features
    ADD CONSTRAINT flipper_features_pkey PRIMARY KEY (id);


--
-- Name: flipper_gates flipper_gates_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.flipper_gates
    ADD CONSTRAINT flipper_gates_pkey PRIMARY KEY (id);


--
-- Name: goals goals_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.goals
    ADD CONSTRAINT goals_pkey PRIMARY KEY (id);


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
-- Name: heartbeat_branches heartbeat_branches_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.heartbeat_branches
    ADD CONSTRAINT heartbeat_branches_pkey PRIMARY KEY (id);


--
-- Name: heartbeat_categories heartbeat_categories_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.heartbeat_categories
    ADD CONSTRAINT heartbeat_categories_pkey PRIMARY KEY (id);


--
-- Name: heartbeat_editors heartbeat_editors_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.heartbeat_editors
    ADD CONSTRAINT heartbeat_editors_pkey PRIMARY KEY (id);


--
-- Name: heartbeat_import_sources heartbeat_import_sources_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.heartbeat_import_sources
    ADD CONSTRAINT heartbeat_import_sources_pkey PRIMARY KEY (id);


--
-- Name: heartbeat_languages heartbeat_languages_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.heartbeat_languages
    ADD CONSTRAINT heartbeat_languages_pkey PRIMARY KEY (id);


--
-- Name: heartbeat_machines heartbeat_machines_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.heartbeat_machines
    ADD CONSTRAINT heartbeat_machines_pkey PRIMARY KEY (id);


--
-- Name: heartbeat_operating_systems heartbeat_operating_systems_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.heartbeat_operating_systems
    ADD CONSTRAINT heartbeat_operating_systems_pkey PRIMARY KEY (id);


--
-- Name: heartbeat_projects heartbeat_projects_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.heartbeat_projects
    ADD CONSTRAINT heartbeat_projects_pkey PRIMARY KEY (id);


--
-- Name: heartbeat_user_agents heartbeat_user_agents_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.heartbeat_user_agents
    ADD CONSTRAINT heartbeat_user_agents_pkey PRIMARY KEY (id);


--
-- Name: leaderboard_entries leaderboard_entries_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.leaderboard_entries
    ADD CONSTRAINT leaderboard_entries_pkey PRIMARY KEY (id);


--
-- Name: leaderboards leaderboards_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.leaderboards
    ADD CONSTRAINT leaderboards_pkey PRIMARY KEY (id);


--
-- Name: mailkick_subscriptions mailkick_subscriptions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.mailkick_subscriptions
    ADD CONSTRAINT mailkick_subscriptions_pkey PRIMARY KEY (id);


--
-- Name: notable_jobs notable_jobs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.notable_jobs
    ADD CONSTRAINT notable_jobs_pkey PRIMARY KEY (id);


--
-- Name: notable_requests notable_requests_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.notable_requests
    ADD CONSTRAINT notable_requests_pkey PRIMARY KEY (id);


--
-- Name: oauth_access_grants oauth_access_grants_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.oauth_access_grants
    ADD CONSTRAINT oauth_access_grants_pkey PRIMARY KEY (id);


--
-- Name: oauth_access_tokens oauth_access_tokens_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.oauth_access_tokens
    ADD CONSTRAINT oauth_access_tokens_pkey PRIMARY KEY (id);


--
-- Name: oauth_applications oauth_applications_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.oauth_applications
    ADD CONSTRAINT oauth_applications_pkey PRIMARY KEY (id);


--
-- Name: pghero_query_stats pghero_query_stats_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pghero_query_stats
    ADD CONSTRAINT pghero_query_stats_pkey PRIMARY KEY (id);


--
-- Name: pghero_space_stats pghero_space_stats_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pghero_space_stats
    ADD CONSTRAINT pghero_space_stats_pkey PRIMARY KEY (id);


--
-- Name: project_labels project_labels_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.project_labels
    ADD CONSTRAINT project_labels_pkey PRIMARY KEY (id);


--
-- Name: project_repo_mappings project_repo_mappings_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.project_repo_mappings
    ADD CONSTRAINT project_repo_mappings_pkey PRIMARY KEY (id);


--
-- Name: raw_heartbeat_uploads raw_heartbeat_uploads_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.raw_heartbeat_uploads
    ADD CONSTRAINT raw_heartbeat_uploads_pkey PRIMARY KEY (id);


--
-- Name: repo_host_events repo_host_events_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.repo_host_events
    ADD CONSTRAINT repo_host_events_pkey PRIMARY KEY (id);


--
-- Name: repositories repositories_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.repositories
    ADD CONSTRAINT repositories_pkey PRIMARY KEY (id);


--
-- Name: sailors_log_leaderboards sailors_log_leaderboards_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sailors_log_leaderboards
    ADD CONSTRAINT sailors_log_leaderboards_pkey PRIMARY KEY (id);


--
-- Name: sailors_log_notification_preferences sailors_log_notification_preferences_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sailors_log_notification_preferences
    ADD CONSTRAINT sailors_log_notification_preferences_pkey PRIMARY KEY (id);


--
-- Name: sailors_log_slack_notifications sailors_log_slack_notifications_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sailors_log_slack_notifications
    ADD CONSTRAINT sailors_log_slack_notifications_pkey PRIMARY KEY (id);


--
-- Name: sailors_logs sailors_logs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sailors_logs
    ADD CONSTRAINT sailors_logs_pkey PRIMARY KEY (id);


--
-- Name: schema_migrations schema_migrations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.schema_migrations
    ADD CONSTRAINT schema_migrations_pkey PRIMARY KEY (version);


--
-- Name: sign_in_tokens sign_in_tokens_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sign_in_tokens
    ADD CONSTRAINT sign_in_tokens_pkey PRIMARY KEY (id);


--
-- Name: solid_cache_entries solid_cache_entries_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.solid_cache_entries
    ADD CONSTRAINT solid_cache_entries_pkey PRIMARY KEY (id);


--
-- Name: trust_level_audit_logs trust_level_audit_logs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.trust_level_audit_logs
    ADD CONSTRAINT trust_level_audit_logs_pkey PRIMARY KEY (id);


--
-- Name: users users_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);


--
-- Name: versions versions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.versions
    ADD CONSTRAINT versions_pkey PRIMARY KEY (id);


--
-- Name: idx_heartbeats_part_fields_hash_uniq; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_heartbeats_part_fields_hash_uniq ON ONLY public.heartbeats USING btree (fields_hash, "time") WHERE (deleted_at IS NULL);


--
-- Name: heartbeats_2024_01_fields_hash_time_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX heartbeats_2024_01_fields_hash_time_idx ON public.heartbeats_2024_01 USING btree (fields_hash, "time") WHERE (deleted_at IS NULL);


--
-- Name: idx_heartbeats_part_ip; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_heartbeats_part_ip ON ONLY public.heartbeats USING btree (ip_address) WHERE ((deleted_at IS NULL) AND (ip_address IS NOT NULL));


--
-- Name: heartbeats_2024_01_ip_address_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_2024_01_ip_address_idx ON public.heartbeats_2024_01 USING btree (ip_address) WHERE ((deleted_at IS NULL) AND (ip_address IS NOT NULL));


--
-- Name: idx_heartbeats_part_machine; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_heartbeats_part_machine ON ONLY public.heartbeats USING btree (machine) WHERE ((deleted_at IS NULL) AND (machine IS NOT NULL));


--
-- Name: heartbeats_2024_01_machine_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_2024_01_machine_idx ON public.heartbeats_2024_01 USING btree (machine) WHERE ((deleted_at IS NULL) AND (machine IS NOT NULL));


--
-- Name: idx_heartbeats_part_current_hacking; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_heartbeats_part_current_hacking ON ONLY public.heartbeats USING btree ("time" DESC) WHERE ((deleted_at IS NULL) AND (source_type = 0) AND ((category)::text = 'coding'::text));


--
-- Name: heartbeats_2024_01_time_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_2024_01_time_idx ON public.heartbeats_2024_01 USING btree ("time" DESC) WHERE ((deleted_at IS NULL) AND (source_type = 0) AND ((category)::text = 'coding'::text));


--
-- Name: idx_heartbeats_part_user_category_time; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_heartbeats_part_user_category_time ON ONLY public.heartbeats USING btree (user_id, category, "time") WHERE ((deleted_at IS NULL) AND (category IS NOT NULL));


--
-- Name: heartbeats_2024_01_user_id_category_time_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_2024_01_user_id_category_time_idx ON public.heartbeats_2024_01 USING btree (user_id, category, "time") WHERE ((deleted_at IS NULL) AND (category IS NOT NULL));


--
-- Name: idx_heartbeats_part_user_editor_time; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_heartbeats_part_user_editor_time ON ONLY public.heartbeats USING btree (user_id, editor, "time") WHERE ((deleted_at IS NULL) AND (editor IS NOT NULL));


--
-- Name: heartbeats_2024_01_user_id_editor_time_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_2024_01_user_id_editor_time_idx ON public.heartbeats_2024_01 USING btree (user_id, editor, "time") WHERE ((deleted_at IS NULL) AND (editor IS NOT NULL));


--
-- Name: idx_heartbeats_part_user_id_direct; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_heartbeats_part_user_id_direct ON ONLY public.heartbeats USING btree (user_id, id) WHERE ((deleted_at IS NULL) AND (source_type = 0));


--
-- Name: heartbeats_2024_01_user_id_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_2024_01_user_id_id_idx ON public.heartbeats_2024_01 USING btree (user_id, id) WHERE ((deleted_at IS NULL) AND (source_type = 0));


--
-- Name: idx_heartbeats_part_user_ip_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_heartbeats_part_user_ip_id ON ONLY public.heartbeats USING btree (user_id, id DESC) WHERE ((deleted_at IS NULL) AND (ip_address IS NOT NULL));


--
-- Name: heartbeats_2024_01_user_id_id_idx1; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_2024_01_user_id_id_idx1 ON public.heartbeats_2024_01 USING btree (user_id, id DESC) WHERE ((deleted_at IS NULL) AND (ip_address IS NOT NULL));


--
-- Name: idx_heartbeats_part_user_language_time; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_heartbeats_part_user_language_time ON ONLY public.heartbeats USING btree (user_id, language, "time") WHERE ((deleted_at IS NULL) AND (language IS NOT NULL));


--
-- Name: heartbeats_2024_01_user_id_language_time_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_2024_01_user_id_language_time_idx ON public.heartbeats_2024_01 USING btree (user_id, language, "time") WHERE ((deleted_at IS NULL) AND (language IS NOT NULL));


--
-- Name: idx_heartbeats_part_user_os_time; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_heartbeats_part_user_os_time ON ONLY public.heartbeats USING btree (user_id, operating_system, "time") WHERE ((deleted_at IS NULL) AND (operating_system IS NOT NULL));


--
-- Name: heartbeats_2024_01_user_id_operating_system_time_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_2024_01_user_id_operating_system_time_idx ON public.heartbeats_2024_01 USING btree (user_id, operating_system, "time") WHERE ((deleted_at IS NULL) AND (operating_system IS NOT NULL));


--
-- Name: idx_heartbeats_part_user_project_time; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_heartbeats_part_user_project_time ON ONLY public.heartbeats USING btree (user_id, project, "time") WHERE ((deleted_at IS NULL) AND (project IS NOT NULL));


--
-- Name: heartbeats_2024_01_user_id_project_time_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_2024_01_user_id_project_time_idx ON public.heartbeats_2024_01 USING btree (user_id, project, "time") WHERE ((deleted_at IS NULL) AND (project IS NOT NULL));


--
-- Name: idx_heartbeats_part_user_time; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_heartbeats_part_user_time ON ONLY public.heartbeats USING btree (user_id, "time") WHERE (deleted_at IS NULL);


--
-- Name: heartbeats_2024_01_user_id_time_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_2024_01_user_id_time_idx ON public.heartbeats_2024_01 USING btree (user_id, "time") WHERE (deleted_at IS NULL);


--
-- Name: heartbeats_2024_02_fields_hash_time_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX heartbeats_2024_02_fields_hash_time_idx ON public.heartbeats_2024_02 USING btree (fields_hash, "time") WHERE (deleted_at IS NULL);


--
-- Name: heartbeats_2024_02_ip_address_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_2024_02_ip_address_idx ON public.heartbeats_2024_02 USING btree (ip_address) WHERE ((deleted_at IS NULL) AND (ip_address IS NOT NULL));


--
-- Name: heartbeats_2024_02_machine_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_2024_02_machine_idx ON public.heartbeats_2024_02 USING btree (machine) WHERE ((deleted_at IS NULL) AND (machine IS NOT NULL));


--
-- Name: heartbeats_2024_02_time_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_2024_02_time_idx ON public.heartbeats_2024_02 USING btree ("time" DESC) WHERE ((deleted_at IS NULL) AND (source_type = 0) AND ((category)::text = 'coding'::text));


--
-- Name: heartbeats_2024_02_user_id_category_time_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_2024_02_user_id_category_time_idx ON public.heartbeats_2024_02 USING btree (user_id, category, "time") WHERE ((deleted_at IS NULL) AND (category IS NOT NULL));


--
-- Name: heartbeats_2024_02_user_id_editor_time_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_2024_02_user_id_editor_time_idx ON public.heartbeats_2024_02 USING btree (user_id, editor, "time") WHERE ((deleted_at IS NULL) AND (editor IS NOT NULL));


--
-- Name: heartbeats_2024_02_user_id_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_2024_02_user_id_id_idx ON public.heartbeats_2024_02 USING btree (user_id, id) WHERE ((deleted_at IS NULL) AND (source_type = 0));


--
-- Name: heartbeats_2024_02_user_id_id_idx1; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_2024_02_user_id_id_idx1 ON public.heartbeats_2024_02 USING btree (user_id, id DESC) WHERE ((deleted_at IS NULL) AND (ip_address IS NOT NULL));


--
-- Name: heartbeats_2024_02_user_id_language_time_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_2024_02_user_id_language_time_idx ON public.heartbeats_2024_02 USING btree (user_id, language, "time") WHERE ((deleted_at IS NULL) AND (language IS NOT NULL));


--
-- Name: heartbeats_2024_02_user_id_operating_system_time_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_2024_02_user_id_operating_system_time_idx ON public.heartbeats_2024_02 USING btree (user_id, operating_system, "time") WHERE ((deleted_at IS NULL) AND (operating_system IS NOT NULL));


--
-- Name: heartbeats_2024_02_user_id_project_time_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_2024_02_user_id_project_time_idx ON public.heartbeats_2024_02 USING btree (user_id, project, "time") WHERE ((deleted_at IS NULL) AND (project IS NOT NULL));


--
-- Name: heartbeats_2024_02_user_id_time_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_2024_02_user_id_time_idx ON public.heartbeats_2024_02 USING btree (user_id, "time") WHERE (deleted_at IS NULL);


--
-- Name: heartbeats_2024_03_fields_hash_time_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX heartbeats_2024_03_fields_hash_time_idx ON public.heartbeats_2024_03 USING btree (fields_hash, "time") WHERE (deleted_at IS NULL);


--
-- Name: heartbeats_2024_03_ip_address_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_2024_03_ip_address_idx ON public.heartbeats_2024_03 USING btree (ip_address) WHERE ((deleted_at IS NULL) AND (ip_address IS NOT NULL));


--
-- Name: heartbeats_2024_03_machine_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_2024_03_machine_idx ON public.heartbeats_2024_03 USING btree (machine) WHERE ((deleted_at IS NULL) AND (machine IS NOT NULL));


--
-- Name: heartbeats_2024_03_time_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_2024_03_time_idx ON public.heartbeats_2024_03 USING btree ("time" DESC) WHERE ((deleted_at IS NULL) AND (source_type = 0) AND ((category)::text = 'coding'::text));


--
-- Name: heartbeats_2024_03_user_id_category_time_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_2024_03_user_id_category_time_idx ON public.heartbeats_2024_03 USING btree (user_id, category, "time") WHERE ((deleted_at IS NULL) AND (category IS NOT NULL));


--
-- Name: heartbeats_2024_03_user_id_editor_time_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_2024_03_user_id_editor_time_idx ON public.heartbeats_2024_03 USING btree (user_id, editor, "time") WHERE ((deleted_at IS NULL) AND (editor IS NOT NULL));


--
-- Name: heartbeats_2024_03_user_id_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_2024_03_user_id_id_idx ON public.heartbeats_2024_03 USING btree (user_id, id) WHERE ((deleted_at IS NULL) AND (source_type = 0));


--
-- Name: heartbeats_2024_03_user_id_id_idx1; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_2024_03_user_id_id_idx1 ON public.heartbeats_2024_03 USING btree (user_id, id DESC) WHERE ((deleted_at IS NULL) AND (ip_address IS NOT NULL));


--
-- Name: heartbeats_2024_03_user_id_language_time_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_2024_03_user_id_language_time_idx ON public.heartbeats_2024_03 USING btree (user_id, language, "time") WHERE ((deleted_at IS NULL) AND (language IS NOT NULL));


--
-- Name: heartbeats_2024_03_user_id_operating_system_time_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_2024_03_user_id_operating_system_time_idx ON public.heartbeats_2024_03 USING btree (user_id, operating_system, "time") WHERE ((deleted_at IS NULL) AND (operating_system IS NOT NULL));


--
-- Name: heartbeats_2024_03_user_id_project_time_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_2024_03_user_id_project_time_idx ON public.heartbeats_2024_03 USING btree (user_id, project, "time") WHERE ((deleted_at IS NULL) AND (project IS NOT NULL));


--
-- Name: heartbeats_2024_03_user_id_time_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_2024_03_user_id_time_idx ON public.heartbeats_2024_03 USING btree (user_id, "time") WHERE (deleted_at IS NULL);


--
-- Name: heartbeats_2024_04_fields_hash_time_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX heartbeats_2024_04_fields_hash_time_idx ON public.heartbeats_2024_04 USING btree (fields_hash, "time") WHERE (deleted_at IS NULL);


--
-- Name: heartbeats_2024_04_ip_address_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_2024_04_ip_address_idx ON public.heartbeats_2024_04 USING btree (ip_address) WHERE ((deleted_at IS NULL) AND (ip_address IS NOT NULL));


--
-- Name: heartbeats_2024_04_machine_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_2024_04_machine_idx ON public.heartbeats_2024_04 USING btree (machine) WHERE ((deleted_at IS NULL) AND (machine IS NOT NULL));


--
-- Name: heartbeats_2024_04_time_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_2024_04_time_idx ON public.heartbeats_2024_04 USING btree ("time" DESC) WHERE ((deleted_at IS NULL) AND (source_type = 0) AND ((category)::text = 'coding'::text));


--
-- Name: heartbeats_2024_04_user_id_category_time_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_2024_04_user_id_category_time_idx ON public.heartbeats_2024_04 USING btree (user_id, category, "time") WHERE ((deleted_at IS NULL) AND (category IS NOT NULL));


--
-- Name: heartbeats_2024_04_user_id_editor_time_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_2024_04_user_id_editor_time_idx ON public.heartbeats_2024_04 USING btree (user_id, editor, "time") WHERE ((deleted_at IS NULL) AND (editor IS NOT NULL));


--
-- Name: heartbeats_2024_04_user_id_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_2024_04_user_id_id_idx ON public.heartbeats_2024_04 USING btree (user_id, id) WHERE ((deleted_at IS NULL) AND (source_type = 0));


--
-- Name: heartbeats_2024_04_user_id_id_idx1; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_2024_04_user_id_id_idx1 ON public.heartbeats_2024_04 USING btree (user_id, id DESC) WHERE ((deleted_at IS NULL) AND (ip_address IS NOT NULL));


--
-- Name: heartbeats_2024_04_user_id_language_time_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_2024_04_user_id_language_time_idx ON public.heartbeats_2024_04 USING btree (user_id, language, "time") WHERE ((deleted_at IS NULL) AND (language IS NOT NULL));


--
-- Name: heartbeats_2024_04_user_id_operating_system_time_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_2024_04_user_id_operating_system_time_idx ON public.heartbeats_2024_04 USING btree (user_id, operating_system, "time") WHERE ((deleted_at IS NULL) AND (operating_system IS NOT NULL));


--
-- Name: heartbeats_2024_04_user_id_project_time_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_2024_04_user_id_project_time_idx ON public.heartbeats_2024_04 USING btree (user_id, project, "time") WHERE ((deleted_at IS NULL) AND (project IS NOT NULL));


--
-- Name: heartbeats_2024_04_user_id_time_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_2024_04_user_id_time_idx ON public.heartbeats_2024_04 USING btree (user_id, "time") WHERE (deleted_at IS NULL);


--
-- Name: heartbeats_2024_05_fields_hash_time_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX heartbeats_2024_05_fields_hash_time_idx ON public.heartbeats_2024_05 USING btree (fields_hash, "time") WHERE (deleted_at IS NULL);


--
-- Name: heartbeats_2024_05_ip_address_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_2024_05_ip_address_idx ON public.heartbeats_2024_05 USING btree (ip_address) WHERE ((deleted_at IS NULL) AND (ip_address IS NOT NULL));


--
-- Name: heartbeats_2024_05_machine_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_2024_05_machine_idx ON public.heartbeats_2024_05 USING btree (machine) WHERE ((deleted_at IS NULL) AND (machine IS NOT NULL));


--
-- Name: heartbeats_2024_05_time_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_2024_05_time_idx ON public.heartbeats_2024_05 USING btree ("time" DESC) WHERE ((deleted_at IS NULL) AND (source_type = 0) AND ((category)::text = 'coding'::text));


--
-- Name: heartbeats_2024_05_user_id_category_time_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_2024_05_user_id_category_time_idx ON public.heartbeats_2024_05 USING btree (user_id, category, "time") WHERE ((deleted_at IS NULL) AND (category IS NOT NULL));


--
-- Name: heartbeats_2024_05_user_id_editor_time_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_2024_05_user_id_editor_time_idx ON public.heartbeats_2024_05 USING btree (user_id, editor, "time") WHERE ((deleted_at IS NULL) AND (editor IS NOT NULL));


--
-- Name: heartbeats_2024_05_user_id_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_2024_05_user_id_id_idx ON public.heartbeats_2024_05 USING btree (user_id, id) WHERE ((deleted_at IS NULL) AND (source_type = 0));


--
-- Name: heartbeats_2024_05_user_id_id_idx1; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_2024_05_user_id_id_idx1 ON public.heartbeats_2024_05 USING btree (user_id, id DESC) WHERE ((deleted_at IS NULL) AND (ip_address IS NOT NULL));


--
-- Name: heartbeats_2024_05_user_id_language_time_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_2024_05_user_id_language_time_idx ON public.heartbeats_2024_05 USING btree (user_id, language, "time") WHERE ((deleted_at IS NULL) AND (language IS NOT NULL));


--
-- Name: heartbeats_2024_05_user_id_operating_system_time_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_2024_05_user_id_operating_system_time_idx ON public.heartbeats_2024_05 USING btree (user_id, operating_system, "time") WHERE ((deleted_at IS NULL) AND (operating_system IS NOT NULL));


--
-- Name: heartbeats_2024_05_user_id_project_time_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_2024_05_user_id_project_time_idx ON public.heartbeats_2024_05 USING btree (user_id, project, "time") WHERE ((deleted_at IS NULL) AND (project IS NOT NULL));


--
-- Name: heartbeats_2024_05_user_id_time_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_2024_05_user_id_time_idx ON public.heartbeats_2024_05 USING btree (user_id, "time") WHERE (deleted_at IS NULL);


--
-- Name: heartbeats_2024_06_fields_hash_time_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX heartbeats_2024_06_fields_hash_time_idx ON public.heartbeats_2024_06 USING btree (fields_hash, "time") WHERE (deleted_at IS NULL);


--
-- Name: heartbeats_2024_06_ip_address_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_2024_06_ip_address_idx ON public.heartbeats_2024_06 USING btree (ip_address) WHERE ((deleted_at IS NULL) AND (ip_address IS NOT NULL));


--
-- Name: heartbeats_2024_06_machine_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_2024_06_machine_idx ON public.heartbeats_2024_06 USING btree (machine) WHERE ((deleted_at IS NULL) AND (machine IS NOT NULL));


--
-- Name: heartbeats_2024_06_time_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_2024_06_time_idx ON public.heartbeats_2024_06 USING btree ("time" DESC) WHERE ((deleted_at IS NULL) AND (source_type = 0) AND ((category)::text = 'coding'::text));


--
-- Name: heartbeats_2024_06_user_id_category_time_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_2024_06_user_id_category_time_idx ON public.heartbeats_2024_06 USING btree (user_id, category, "time") WHERE ((deleted_at IS NULL) AND (category IS NOT NULL));


--
-- Name: heartbeats_2024_06_user_id_editor_time_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_2024_06_user_id_editor_time_idx ON public.heartbeats_2024_06 USING btree (user_id, editor, "time") WHERE ((deleted_at IS NULL) AND (editor IS NOT NULL));


--
-- Name: heartbeats_2024_06_user_id_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_2024_06_user_id_id_idx ON public.heartbeats_2024_06 USING btree (user_id, id) WHERE ((deleted_at IS NULL) AND (source_type = 0));


--
-- Name: heartbeats_2024_06_user_id_id_idx1; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_2024_06_user_id_id_idx1 ON public.heartbeats_2024_06 USING btree (user_id, id DESC) WHERE ((deleted_at IS NULL) AND (ip_address IS NOT NULL));


--
-- Name: heartbeats_2024_06_user_id_language_time_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_2024_06_user_id_language_time_idx ON public.heartbeats_2024_06 USING btree (user_id, language, "time") WHERE ((deleted_at IS NULL) AND (language IS NOT NULL));


--
-- Name: heartbeats_2024_06_user_id_operating_system_time_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_2024_06_user_id_operating_system_time_idx ON public.heartbeats_2024_06 USING btree (user_id, operating_system, "time") WHERE ((deleted_at IS NULL) AND (operating_system IS NOT NULL));


--
-- Name: heartbeats_2024_06_user_id_project_time_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_2024_06_user_id_project_time_idx ON public.heartbeats_2024_06 USING btree (user_id, project, "time") WHERE ((deleted_at IS NULL) AND (project IS NOT NULL));


--
-- Name: heartbeats_2024_06_user_id_time_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_2024_06_user_id_time_idx ON public.heartbeats_2024_06 USING btree (user_id, "time") WHERE (deleted_at IS NULL);


--
-- Name: heartbeats_2024_07_fields_hash_time_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX heartbeats_2024_07_fields_hash_time_idx ON public.heartbeats_2024_07 USING btree (fields_hash, "time") WHERE (deleted_at IS NULL);


--
-- Name: heartbeats_2024_07_ip_address_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_2024_07_ip_address_idx ON public.heartbeats_2024_07 USING btree (ip_address) WHERE ((deleted_at IS NULL) AND (ip_address IS NOT NULL));


--
-- Name: heartbeats_2024_07_machine_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_2024_07_machine_idx ON public.heartbeats_2024_07 USING btree (machine) WHERE ((deleted_at IS NULL) AND (machine IS NOT NULL));


--
-- Name: heartbeats_2024_07_time_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_2024_07_time_idx ON public.heartbeats_2024_07 USING btree ("time" DESC) WHERE ((deleted_at IS NULL) AND (source_type = 0) AND ((category)::text = 'coding'::text));


--
-- Name: heartbeats_2024_07_user_id_category_time_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_2024_07_user_id_category_time_idx ON public.heartbeats_2024_07 USING btree (user_id, category, "time") WHERE ((deleted_at IS NULL) AND (category IS NOT NULL));


--
-- Name: heartbeats_2024_07_user_id_editor_time_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_2024_07_user_id_editor_time_idx ON public.heartbeats_2024_07 USING btree (user_id, editor, "time") WHERE ((deleted_at IS NULL) AND (editor IS NOT NULL));


--
-- Name: heartbeats_2024_07_user_id_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_2024_07_user_id_id_idx ON public.heartbeats_2024_07 USING btree (user_id, id) WHERE ((deleted_at IS NULL) AND (source_type = 0));


--
-- Name: heartbeats_2024_07_user_id_id_idx1; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_2024_07_user_id_id_idx1 ON public.heartbeats_2024_07 USING btree (user_id, id DESC) WHERE ((deleted_at IS NULL) AND (ip_address IS NOT NULL));


--
-- Name: heartbeats_2024_07_user_id_language_time_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_2024_07_user_id_language_time_idx ON public.heartbeats_2024_07 USING btree (user_id, language, "time") WHERE ((deleted_at IS NULL) AND (language IS NOT NULL));


--
-- Name: heartbeats_2024_07_user_id_operating_system_time_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_2024_07_user_id_operating_system_time_idx ON public.heartbeats_2024_07 USING btree (user_id, operating_system, "time") WHERE ((deleted_at IS NULL) AND (operating_system IS NOT NULL));


--
-- Name: heartbeats_2024_07_user_id_project_time_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_2024_07_user_id_project_time_idx ON public.heartbeats_2024_07 USING btree (user_id, project, "time") WHERE ((deleted_at IS NULL) AND (project IS NOT NULL));


--
-- Name: heartbeats_2024_07_user_id_time_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_2024_07_user_id_time_idx ON public.heartbeats_2024_07 USING btree (user_id, "time") WHERE (deleted_at IS NULL);


--
-- Name: heartbeats_2024_08_fields_hash_time_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX heartbeats_2024_08_fields_hash_time_idx ON public.heartbeats_2024_08 USING btree (fields_hash, "time") WHERE (deleted_at IS NULL);


--
-- Name: heartbeats_2024_08_ip_address_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_2024_08_ip_address_idx ON public.heartbeats_2024_08 USING btree (ip_address) WHERE ((deleted_at IS NULL) AND (ip_address IS NOT NULL));


--
-- Name: heartbeats_2024_08_machine_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_2024_08_machine_idx ON public.heartbeats_2024_08 USING btree (machine) WHERE ((deleted_at IS NULL) AND (machine IS NOT NULL));


--
-- Name: heartbeats_2024_08_time_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_2024_08_time_idx ON public.heartbeats_2024_08 USING btree ("time" DESC) WHERE ((deleted_at IS NULL) AND (source_type = 0) AND ((category)::text = 'coding'::text));


--
-- Name: heartbeats_2024_08_user_id_category_time_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_2024_08_user_id_category_time_idx ON public.heartbeats_2024_08 USING btree (user_id, category, "time") WHERE ((deleted_at IS NULL) AND (category IS NOT NULL));


--
-- Name: heartbeats_2024_08_user_id_editor_time_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_2024_08_user_id_editor_time_idx ON public.heartbeats_2024_08 USING btree (user_id, editor, "time") WHERE ((deleted_at IS NULL) AND (editor IS NOT NULL));


--
-- Name: heartbeats_2024_08_user_id_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_2024_08_user_id_id_idx ON public.heartbeats_2024_08 USING btree (user_id, id) WHERE ((deleted_at IS NULL) AND (source_type = 0));


--
-- Name: heartbeats_2024_08_user_id_id_idx1; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_2024_08_user_id_id_idx1 ON public.heartbeats_2024_08 USING btree (user_id, id DESC) WHERE ((deleted_at IS NULL) AND (ip_address IS NOT NULL));


--
-- Name: heartbeats_2024_08_user_id_language_time_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_2024_08_user_id_language_time_idx ON public.heartbeats_2024_08 USING btree (user_id, language, "time") WHERE ((deleted_at IS NULL) AND (language IS NOT NULL));


--
-- Name: heartbeats_2024_08_user_id_operating_system_time_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_2024_08_user_id_operating_system_time_idx ON public.heartbeats_2024_08 USING btree (user_id, operating_system, "time") WHERE ((deleted_at IS NULL) AND (operating_system IS NOT NULL));


--
-- Name: heartbeats_2024_08_user_id_project_time_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_2024_08_user_id_project_time_idx ON public.heartbeats_2024_08 USING btree (user_id, project, "time") WHERE ((deleted_at IS NULL) AND (project IS NOT NULL));


--
-- Name: heartbeats_2024_08_user_id_time_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_2024_08_user_id_time_idx ON public.heartbeats_2024_08 USING btree (user_id, "time") WHERE (deleted_at IS NULL);


--
-- Name: heartbeats_2024_09_fields_hash_time_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX heartbeats_2024_09_fields_hash_time_idx ON public.heartbeats_2024_09 USING btree (fields_hash, "time") WHERE (deleted_at IS NULL);


--
-- Name: heartbeats_2024_09_ip_address_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_2024_09_ip_address_idx ON public.heartbeats_2024_09 USING btree (ip_address) WHERE ((deleted_at IS NULL) AND (ip_address IS NOT NULL));


--
-- Name: heartbeats_2024_09_machine_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_2024_09_machine_idx ON public.heartbeats_2024_09 USING btree (machine) WHERE ((deleted_at IS NULL) AND (machine IS NOT NULL));


--
-- Name: heartbeats_2024_09_time_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_2024_09_time_idx ON public.heartbeats_2024_09 USING btree ("time" DESC) WHERE ((deleted_at IS NULL) AND (source_type = 0) AND ((category)::text = 'coding'::text));


--
-- Name: heartbeats_2024_09_user_id_category_time_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_2024_09_user_id_category_time_idx ON public.heartbeats_2024_09 USING btree (user_id, category, "time") WHERE ((deleted_at IS NULL) AND (category IS NOT NULL));


--
-- Name: heartbeats_2024_09_user_id_editor_time_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_2024_09_user_id_editor_time_idx ON public.heartbeats_2024_09 USING btree (user_id, editor, "time") WHERE ((deleted_at IS NULL) AND (editor IS NOT NULL));


--
-- Name: heartbeats_2024_09_user_id_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_2024_09_user_id_id_idx ON public.heartbeats_2024_09 USING btree (user_id, id) WHERE ((deleted_at IS NULL) AND (source_type = 0));


--
-- Name: heartbeats_2024_09_user_id_id_idx1; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_2024_09_user_id_id_idx1 ON public.heartbeats_2024_09 USING btree (user_id, id DESC) WHERE ((deleted_at IS NULL) AND (ip_address IS NOT NULL));


--
-- Name: heartbeats_2024_09_user_id_language_time_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_2024_09_user_id_language_time_idx ON public.heartbeats_2024_09 USING btree (user_id, language, "time") WHERE ((deleted_at IS NULL) AND (language IS NOT NULL));


--
-- Name: heartbeats_2024_09_user_id_operating_system_time_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_2024_09_user_id_operating_system_time_idx ON public.heartbeats_2024_09 USING btree (user_id, operating_system, "time") WHERE ((deleted_at IS NULL) AND (operating_system IS NOT NULL));


--
-- Name: heartbeats_2024_09_user_id_project_time_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_2024_09_user_id_project_time_idx ON public.heartbeats_2024_09 USING btree (user_id, project, "time") WHERE ((deleted_at IS NULL) AND (project IS NOT NULL));


--
-- Name: heartbeats_2024_09_user_id_time_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_2024_09_user_id_time_idx ON public.heartbeats_2024_09 USING btree (user_id, "time") WHERE (deleted_at IS NULL);


--
-- Name: heartbeats_2024_10_fields_hash_time_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX heartbeats_2024_10_fields_hash_time_idx ON public.heartbeats_2024_10 USING btree (fields_hash, "time") WHERE (deleted_at IS NULL);


--
-- Name: heartbeats_2024_10_ip_address_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_2024_10_ip_address_idx ON public.heartbeats_2024_10 USING btree (ip_address) WHERE ((deleted_at IS NULL) AND (ip_address IS NOT NULL));


--
-- Name: heartbeats_2024_10_machine_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_2024_10_machine_idx ON public.heartbeats_2024_10 USING btree (machine) WHERE ((deleted_at IS NULL) AND (machine IS NOT NULL));


--
-- Name: heartbeats_2024_10_time_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_2024_10_time_idx ON public.heartbeats_2024_10 USING btree ("time" DESC) WHERE ((deleted_at IS NULL) AND (source_type = 0) AND ((category)::text = 'coding'::text));


--
-- Name: heartbeats_2024_10_user_id_category_time_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_2024_10_user_id_category_time_idx ON public.heartbeats_2024_10 USING btree (user_id, category, "time") WHERE ((deleted_at IS NULL) AND (category IS NOT NULL));


--
-- Name: heartbeats_2024_10_user_id_editor_time_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_2024_10_user_id_editor_time_idx ON public.heartbeats_2024_10 USING btree (user_id, editor, "time") WHERE ((deleted_at IS NULL) AND (editor IS NOT NULL));


--
-- Name: heartbeats_2024_10_user_id_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_2024_10_user_id_id_idx ON public.heartbeats_2024_10 USING btree (user_id, id) WHERE ((deleted_at IS NULL) AND (source_type = 0));


--
-- Name: heartbeats_2024_10_user_id_id_idx1; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_2024_10_user_id_id_idx1 ON public.heartbeats_2024_10 USING btree (user_id, id DESC) WHERE ((deleted_at IS NULL) AND (ip_address IS NOT NULL));


--
-- Name: heartbeats_2024_10_user_id_language_time_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_2024_10_user_id_language_time_idx ON public.heartbeats_2024_10 USING btree (user_id, language, "time") WHERE ((deleted_at IS NULL) AND (language IS NOT NULL));


--
-- Name: heartbeats_2024_10_user_id_operating_system_time_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_2024_10_user_id_operating_system_time_idx ON public.heartbeats_2024_10 USING btree (user_id, operating_system, "time") WHERE ((deleted_at IS NULL) AND (operating_system IS NOT NULL));


--
-- Name: heartbeats_2024_10_user_id_project_time_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_2024_10_user_id_project_time_idx ON public.heartbeats_2024_10 USING btree (user_id, project, "time") WHERE ((deleted_at IS NULL) AND (project IS NOT NULL));


--
-- Name: heartbeats_2024_10_user_id_time_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_2024_10_user_id_time_idx ON public.heartbeats_2024_10 USING btree (user_id, "time") WHERE (deleted_at IS NULL);


--
-- Name: heartbeats_2024_11_fields_hash_time_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX heartbeats_2024_11_fields_hash_time_idx ON public.heartbeats_2024_11 USING btree (fields_hash, "time") WHERE (deleted_at IS NULL);


--
-- Name: heartbeats_2024_11_ip_address_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_2024_11_ip_address_idx ON public.heartbeats_2024_11 USING btree (ip_address) WHERE ((deleted_at IS NULL) AND (ip_address IS NOT NULL));


--
-- Name: heartbeats_2024_11_machine_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_2024_11_machine_idx ON public.heartbeats_2024_11 USING btree (machine) WHERE ((deleted_at IS NULL) AND (machine IS NOT NULL));


--
-- Name: heartbeats_2024_11_time_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_2024_11_time_idx ON public.heartbeats_2024_11 USING btree ("time" DESC) WHERE ((deleted_at IS NULL) AND (source_type = 0) AND ((category)::text = 'coding'::text));


--
-- Name: heartbeats_2024_11_user_id_category_time_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_2024_11_user_id_category_time_idx ON public.heartbeats_2024_11 USING btree (user_id, category, "time") WHERE ((deleted_at IS NULL) AND (category IS NOT NULL));


--
-- Name: heartbeats_2024_11_user_id_editor_time_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_2024_11_user_id_editor_time_idx ON public.heartbeats_2024_11 USING btree (user_id, editor, "time") WHERE ((deleted_at IS NULL) AND (editor IS NOT NULL));


--
-- Name: heartbeats_2024_11_user_id_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_2024_11_user_id_id_idx ON public.heartbeats_2024_11 USING btree (user_id, id) WHERE ((deleted_at IS NULL) AND (source_type = 0));


--
-- Name: heartbeats_2024_11_user_id_id_idx1; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_2024_11_user_id_id_idx1 ON public.heartbeats_2024_11 USING btree (user_id, id DESC) WHERE ((deleted_at IS NULL) AND (ip_address IS NOT NULL));


--
-- Name: heartbeats_2024_11_user_id_language_time_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_2024_11_user_id_language_time_idx ON public.heartbeats_2024_11 USING btree (user_id, language, "time") WHERE ((deleted_at IS NULL) AND (language IS NOT NULL));


--
-- Name: heartbeats_2024_11_user_id_operating_system_time_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_2024_11_user_id_operating_system_time_idx ON public.heartbeats_2024_11 USING btree (user_id, operating_system, "time") WHERE ((deleted_at IS NULL) AND (operating_system IS NOT NULL));


--
-- Name: heartbeats_2024_11_user_id_project_time_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_2024_11_user_id_project_time_idx ON public.heartbeats_2024_11 USING btree (user_id, project, "time") WHERE ((deleted_at IS NULL) AND (project IS NOT NULL));


--
-- Name: heartbeats_2024_11_user_id_time_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_2024_11_user_id_time_idx ON public.heartbeats_2024_11 USING btree (user_id, "time") WHERE (deleted_at IS NULL);


--
-- Name: heartbeats_2024_12_fields_hash_time_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX heartbeats_2024_12_fields_hash_time_idx ON public.heartbeats_2024_12 USING btree (fields_hash, "time") WHERE (deleted_at IS NULL);


--
-- Name: heartbeats_2024_12_ip_address_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_2024_12_ip_address_idx ON public.heartbeats_2024_12 USING btree (ip_address) WHERE ((deleted_at IS NULL) AND (ip_address IS NOT NULL));


--
-- Name: heartbeats_2024_12_machine_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_2024_12_machine_idx ON public.heartbeats_2024_12 USING btree (machine) WHERE ((deleted_at IS NULL) AND (machine IS NOT NULL));


--
-- Name: heartbeats_2024_12_time_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_2024_12_time_idx ON public.heartbeats_2024_12 USING btree ("time" DESC) WHERE ((deleted_at IS NULL) AND (source_type = 0) AND ((category)::text = 'coding'::text));


--
-- Name: heartbeats_2024_12_user_id_category_time_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_2024_12_user_id_category_time_idx ON public.heartbeats_2024_12 USING btree (user_id, category, "time") WHERE ((deleted_at IS NULL) AND (category IS NOT NULL));


--
-- Name: heartbeats_2024_12_user_id_editor_time_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_2024_12_user_id_editor_time_idx ON public.heartbeats_2024_12 USING btree (user_id, editor, "time") WHERE ((deleted_at IS NULL) AND (editor IS NOT NULL));


--
-- Name: heartbeats_2024_12_user_id_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_2024_12_user_id_id_idx ON public.heartbeats_2024_12 USING btree (user_id, id) WHERE ((deleted_at IS NULL) AND (source_type = 0));


--
-- Name: heartbeats_2024_12_user_id_id_idx1; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_2024_12_user_id_id_idx1 ON public.heartbeats_2024_12 USING btree (user_id, id DESC) WHERE ((deleted_at IS NULL) AND (ip_address IS NOT NULL));


--
-- Name: heartbeats_2024_12_user_id_language_time_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_2024_12_user_id_language_time_idx ON public.heartbeats_2024_12 USING btree (user_id, language, "time") WHERE ((deleted_at IS NULL) AND (language IS NOT NULL));


--
-- Name: heartbeats_2024_12_user_id_operating_system_time_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_2024_12_user_id_operating_system_time_idx ON public.heartbeats_2024_12 USING btree (user_id, operating_system, "time") WHERE ((deleted_at IS NULL) AND (operating_system IS NOT NULL));


--
-- Name: heartbeats_2024_12_user_id_project_time_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_2024_12_user_id_project_time_idx ON public.heartbeats_2024_12 USING btree (user_id, project, "time") WHERE ((deleted_at IS NULL) AND (project IS NOT NULL));


--
-- Name: heartbeats_2024_12_user_id_time_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_2024_12_user_id_time_idx ON public.heartbeats_2024_12 USING btree (user_id, "time") WHERE (deleted_at IS NULL);


--
-- Name: heartbeats_2025_01_fields_hash_time_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX heartbeats_2025_01_fields_hash_time_idx ON public.heartbeats_2025_01 USING btree (fields_hash, "time") WHERE (deleted_at IS NULL);


--
-- Name: heartbeats_2025_01_ip_address_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_2025_01_ip_address_idx ON public.heartbeats_2025_01 USING btree (ip_address) WHERE ((deleted_at IS NULL) AND (ip_address IS NOT NULL));


--
-- Name: heartbeats_2025_01_machine_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_2025_01_machine_idx ON public.heartbeats_2025_01 USING btree (machine) WHERE ((deleted_at IS NULL) AND (machine IS NOT NULL));


--
-- Name: heartbeats_2025_01_time_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_2025_01_time_idx ON public.heartbeats_2025_01 USING btree ("time" DESC) WHERE ((deleted_at IS NULL) AND (source_type = 0) AND ((category)::text = 'coding'::text));


--
-- Name: heartbeats_2025_01_user_id_category_time_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_2025_01_user_id_category_time_idx ON public.heartbeats_2025_01 USING btree (user_id, category, "time") WHERE ((deleted_at IS NULL) AND (category IS NOT NULL));


--
-- Name: heartbeats_2025_01_user_id_editor_time_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_2025_01_user_id_editor_time_idx ON public.heartbeats_2025_01 USING btree (user_id, editor, "time") WHERE ((deleted_at IS NULL) AND (editor IS NOT NULL));


--
-- Name: heartbeats_2025_01_user_id_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_2025_01_user_id_id_idx ON public.heartbeats_2025_01 USING btree (user_id, id) WHERE ((deleted_at IS NULL) AND (source_type = 0));


--
-- Name: heartbeats_2025_01_user_id_id_idx1; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_2025_01_user_id_id_idx1 ON public.heartbeats_2025_01 USING btree (user_id, id DESC) WHERE ((deleted_at IS NULL) AND (ip_address IS NOT NULL));


--
-- Name: heartbeats_2025_01_user_id_language_time_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_2025_01_user_id_language_time_idx ON public.heartbeats_2025_01 USING btree (user_id, language, "time") WHERE ((deleted_at IS NULL) AND (language IS NOT NULL));


--
-- Name: heartbeats_2025_01_user_id_operating_system_time_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_2025_01_user_id_operating_system_time_idx ON public.heartbeats_2025_01 USING btree (user_id, operating_system, "time") WHERE ((deleted_at IS NULL) AND (operating_system IS NOT NULL));


--
-- Name: heartbeats_2025_01_user_id_project_time_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_2025_01_user_id_project_time_idx ON public.heartbeats_2025_01 USING btree (user_id, project, "time") WHERE ((deleted_at IS NULL) AND (project IS NOT NULL));


--
-- Name: heartbeats_2025_01_user_id_time_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_2025_01_user_id_time_idx ON public.heartbeats_2025_01 USING btree (user_id, "time") WHERE (deleted_at IS NULL);


--
-- Name: heartbeats_2025_02_fields_hash_time_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX heartbeats_2025_02_fields_hash_time_idx ON public.heartbeats_2025_02 USING btree (fields_hash, "time") WHERE (deleted_at IS NULL);


--
-- Name: heartbeats_2025_02_ip_address_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_2025_02_ip_address_idx ON public.heartbeats_2025_02 USING btree (ip_address) WHERE ((deleted_at IS NULL) AND (ip_address IS NOT NULL));


--
-- Name: heartbeats_2025_02_machine_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_2025_02_machine_idx ON public.heartbeats_2025_02 USING btree (machine) WHERE ((deleted_at IS NULL) AND (machine IS NOT NULL));


--
-- Name: heartbeats_2025_02_time_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_2025_02_time_idx ON public.heartbeats_2025_02 USING btree ("time" DESC) WHERE ((deleted_at IS NULL) AND (source_type = 0) AND ((category)::text = 'coding'::text));


--
-- Name: heartbeats_2025_02_user_id_category_time_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_2025_02_user_id_category_time_idx ON public.heartbeats_2025_02 USING btree (user_id, category, "time") WHERE ((deleted_at IS NULL) AND (category IS NOT NULL));


--
-- Name: heartbeats_2025_02_user_id_editor_time_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_2025_02_user_id_editor_time_idx ON public.heartbeats_2025_02 USING btree (user_id, editor, "time") WHERE ((deleted_at IS NULL) AND (editor IS NOT NULL));


--
-- Name: heartbeats_2025_02_user_id_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_2025_02_user_id_id_idx ON public.heartbeats_2025_02 USING btree (user_id, id) WHERE ((deleted_at IS NULL) AND (source_type = 0));


--
-- Name: heartbeats_2025_02_user_id_id_idx1; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_2025_02_user_id_id_idx1 ON public.heartbeats_2025_02 USING btree (user_id, id DESC) WHERE ((deleted_at IS NULL) AND (ip_address IS NOT NULL));


--
-- Name: heartbeats_2025_02_user_id_language_time_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_2025_02_user_id_language_time_idx ON public.heartbeats_2025_02 USING btree (user_id, language, "time") WHERE ((deleted_at IS NULL) AND (language IS NOT NULL));


--
-- Name: heartbeats_2025_02_user_id_operating_system_time_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_2025_02_user_id_operating_system_time_idx ON public.heartbeats_2025_02 USING btree (user_id, operating_system, "time") WHERE ((deleted_at IS NULL) AND (operating_system IS NOT NULL));


--
-- Name: heartbeats_2025_02_user_id_project_time_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_2025_02_user_id_project_time_idx ON public.heartbeats_2025_02 USING btree (user_id, project, "time") WHERE ((deleted_at IS NULL) AND (project IS NOT NULL));


--
-- Name: heartbeats_2025_02_user_id_time_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_2025_02_user_id_time_idx ON public.heartbeats_2025_02 USING btree (user_id, "time") WHERE (deleted_at IS NULL);


--
-- Name: heartbeats_2025_03_fields_hash_time_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX heartbeats_2025_03_fields_hash_time_idx ON public.heartbeats_2025_03 USING btree (fields_hash, "time") WHERE (deleted_at IS NULL);


--
-- Name: heartbeats_2025_03_ip_address_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_2025_03_ip_address_idx ON public.heartbeats_2025_03 USING btree (ip_address) WHERE ((deleted_at IS NULL) AND (ip_address IS NOT NULL));


--
-- Name: heartbeats_2025_03_machine_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_2025_03_machine_idx ON public.heartbeats_2025_03 USING btree (machine) WHERE ((deleted_at IS NULL) AND (machine IS NOT NULL));


--
-- Name: heartbeats_2025_03_time_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_2025_03_time_idx ON public.heartbeats_2025_03 USING btree ("time" DESC) WHERE ((deleted_at IS NULL) AND (source_type = 0) AND ((category)::text = 'coding'::text));


--
-- Name: heartbeats_2025_03_user_id_category_time_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_2025_03_user_id_category_time_idx ON public.heartbeats_2025_03 USING btree (user_id, category, "time") WHERE ((deleted_at IS NULL) AND (category IS NOT NULL));


--
-- Name: heartbeats_2025_03_user_id_editor_time_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_2025_03_user_id_editor_time_idx ON public.heartbeats_2025_03 USING btree (user_id, editor, "time") WHERE ((deleted_at IS NULL) AND (editor IS NOT NULL));


--
-- Name: heartbeats_2025_03_user_id_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_2025_03_user_id_id_idx ON public.heartbeats_2025_03 USING btree (user_id, id) WHERE ((deleted_at IS NULL) AND (source_type = 0));


--
-- Name: heartbeats_2025_03_user_id_id_idx1; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_2025_03_user_id_id_idx1 ON public.heartbeats_2025_03 USING btree (user_id, id DESC) WHERE ((deleted_at IS NULL) AND (ip_address IS NOT NULL));


--
-- Name: heartbeats_2025_03_user_id_language_time_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_2025_03_user_id_language_time_idx ON public.heartbeats_2025_03 USING btree (user_id, language, "time") WHERE ((deleted_at IS NULL) AND (language IS NOT NULL));


--
-- Name: heartbeats_2025_03_user_id_operating_system_time_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_2025_03_user_id_operating_system_time_idx ON public.heartbeats_2025_03 USING btree (user_id, operating_system, "time") WHERE ((deleted_at IS NULL) AND (operating_system IS NOT NULL));


--
-- Name: heartbeats_2025_03_user_id_project_time_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_2025_03_user_id_project_time_idx ON public.heartbeats_2025_03 USING btree (user_id, project, "time") WHERE ((deleted_at IS NULL) AND (project IS NOT NULL));


--
-- Name: heartbeats_2025_03_user_id_time_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_2025_03_user_id_time_idx ON public.heartbeats_2025_03 USING btree (user_id, "time") WHERE (deleted_at IS NULL);


--
-- Name: heartbeats_2025_04_fields_hash_time_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX heartbeats_2025_04_fields_hash_time_idx ON public.heartbeats_2025_04 USING btree (fields_hash, "time") WHERE (deleted_at IS NULL);


--
-- Name: heartbeats_2025_04_ip_address_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_2025_04_ip_address_idx ON public.heartbeats_2025_04 USING btree (ip_address) WHERE ((deleted_at IS NULL) AND (ip_address IS NOT NULL));


--
-- Name: heartbeats_2025_04_machine_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_2025_04_machine_idx ON public.heartbeats_2025_04 USING btree (machine) WHERE ((deleted_at IS NULL) AND (machine IS NOT NULL));


--
-- Name: heartbeats_2025_04_time_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_2025_04_time_idx ON public.heartbeats_2025_04 USING btree ("time" DESC) WHERE ((deleted_at IS NULL) AND (source_type = 0) AND ((category)::text = 'coding'::text));


--
-- Name: heartbeats_2025_04_user_id_category_time_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_2025_04_user_id_category_time_idx ON public.heartbeats_2025_04 USING btree (user_id, category, "time") WHERE ((deleted_at IS NULL) AND (category IS NOT NULL));


--
-- Name: heartbeats_2025_04_user_id_editor_time_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_2025_04_user_id_editor_time_idx ON public.heartbeats_2025_04 USING btree (user_id, editor, "time") WHERE ((deleted_at IS NULL) AND (editor IS NOT NULL));


--
-- Name: heartbeats_2025_04_user_id_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_2025_04_user_id_id_idx ON public.heartbeats_2025_04 USING btree (user_id, id) WHERE ((deleted_at IS NULL) AND (source_type = 0));


--
-- Name: heartbeats_2025_04_user_id_id_idx1; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_2025_04_user_id_id_idx1 ON public.heartbeats_2025_04 USING btree (user_id, id DESC) WHERE ((deleted_at IS NULL) AND (ip_address IS NOT NULL));


--
-- Name: heartbeats_2025_04_user_id_language_time_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_2025_04_user_id_language_time_idx ON public.heartbeats_2025_04 USING btree (user_id, language, "time") WHERE ((deleted_at IS NULL) AND (language IS NOT NULL));


--
-- Name: heartbeats_2025_04_user_id_operating_system_time_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_2025_04_user_id_operating_system_time_idx ON public.heartbeats_2025_04 USING btree (user_id, operating_system, "time") WHERE ((deleted_at IS NULL) AND (operating_system IS NOT NULL));


--
-- Name: heartbeats_2025_04_user_id_project_time_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_2025_04_user_id_project_time_idx ON public.heartbeats_2025_04 USING btree (user_id, project, "time") WHERE ((deleted_at IS NULL) AND (project IS NOT NULL));


--
-- Name: heartbeats_2025_04_user_id_time_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_2025_04_user_id_time_idx ON public.heartbeats_2025_04 USING btree (user_id, "time") WHERE (deleted_at IS NULL);


--
-- Name: heartbeats_2025_05_fields_hash_time_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX heartbeats_2025_05_fields_hash_time_idx ON public.heartbeats_2025_05 USING btree (fields_hash, "time") WHERE (deleted_at IS NULL);


--
-- Name: heartbeats_2025_05_ip_address_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_2025_05_ip_address_idx ON public.heartbeats_2025_05 USING btree (ip_address) WHERE ((deleted_at IS NULL) AND (ip_address IS NOT NULL));


--
-- Name: heartbeats_2025_05_machine_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_2025_05_machine_idx ON public.heartbeats_2025_05 USING btree (machine) WHERE ((deleted_at IS NULL) AND (machine IS NOT NULL));


--
-- Name: heartbeats_2025_05_time_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_2025_05_time_idx ON public.heartbeats_2025_05 USING btree ("time" DESC) WHERE ((deleted_at IS NULL) AND (source_type = 0) AND ((category)::text = 'coding'::text));


--
-- Name: heartbeats_2025_05_user_id_category_time_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_2025_05_user_id_category_time_idx ON public.heartbeats_2025_05 USING btree (user_id, category, "time") WHERE ((deleted_at IS NULL) AND (category IS NOT NULL));


--
-- Name: heartbeats_2025_05_user_id_editor_time_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_2025_05_user_id_editor_time_idx ON public.heartbeats_2025_05 USING btree (user_id, editor, "time") WHERE ((deleted_at IS NULL) AND (editor IS NOT NULL));


--
-- Name: heartbeats_2025_05_user_id_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_2025_05_user_id_id_idx ON public.heartbeats_2025_05 USING btree (user_id, id) WHERE ((deleted_at IS NULL) AND (source_type = 0));


--
-- Name: heartbeats_2025_05_user_id_id_idx1; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_2025_05_user_id_id_idx1 ON public.heartbeats_2025_05 USING btree (user_id, id DESC) WHERE ((deleted_at IS NULL) AND (ip_address IS NOT NULL));


--
-- Name: heartbeats_2025_05_user_id_language_time_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_2025_05_user_id_language_time_idx ON public.heartbeats_2025_05 USING btree (user_id, language, "time") WHERE ((deleted_at IS NULL) AND (language IS NOT NULL));


--
-- Name: heartbeats_2025_05_user_id_operating_system_time_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_2025_05_user_id_operating_system_time_idx ON public.heartbeats_2025_05 USING btree (user_id, operating_system, "time") WHERE ((deleted_at IS NULL) AND (operating_system IS NOT NULL));


--
-- Name: heartbeats_2025_05_user_id_project_time_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_2025_05_user_id_project_time_idx ON public.heartbeats_2025_05 USING btree (user_id, project, "time") WHERE ((deleted_at IS NULL) AND (project IS NOT NULL));


--
-- Name: heartbeats_2025_05_user_id_time_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_2025_05_user_id_time_idx ON public.heartbeats_2025_05 USING btree (user_id, "time") WHERE (deleted_at IS NULL);


--
-- Name: heartbeats_2025_06_fields_hash_time_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX heartbeats_2025_06_fields_hash_time_idx ON public.heartbeats_2025_06 USING btree (fields_hash, "time") WHERE (deleted_at IS NULL);


--
-- Name: heartbeats_2025_06_ip_address_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_2025_06_ip_address_idx ON public.heartbeats_2025_06 USING btree (ip_address) WHERE ((deleted_at IS NULL) AND (ip_address IS NOT NULL));


--
-- Name: heartbeats_2025_06_machine_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_2025_06_machine_idx ON public.heartbeats_2025_06 USING btree (machine) WHERE ((deleted_at IS NULL) AND (machine IS NOT NULL));


--
-- Name: heartbeats_2025_06_time_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_2025_06_time_idx ON public.heartbeats_2025_06 USING btree ("time" DESC) WHERE ((deleted_at IS NULL) AND (source_type = 0) AND ((category)::text = 'coding'::text));


--
-- Name: heartbeats_2025_06_user_id_category_time_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_2025_06_user_id_category_time_idx ON public.heartbeats_2025_06 USING btree (user_id, category, "time") WHERE ((deleted_at IS NULL) AND (category IS NOT NULL));


--
-- Name: heartbeats_2025_06_user_id_editor_time_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_2025_06_user_id_editor_time_idx ON public.heartbeats_2025_06 USING btree (user_id, editor, "time") WHERE ((deleted_at IS NULL) AND (editor IS NOT NULL));


--
-- Name: heartbeats_2025_06_user_id_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_2025_06_user_id_id_idx ON public.heartbeats_2025_06 USING btree (user_id, id) WHERE ((deleted_at IS NULL) AND (source_type = 0));


--
-- Name: heartbeats_2025_06_user_id_id_idx1; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_2025_06_user_id_id_idx1 ON public.heartbeats_2025_06 USING btree (user_id, id DESC) WHERE ((deleted_at IS NULL) AND (ip_address IS NOT NULL));


--
-- Name: heartbeats_2025_06_user_id_language_time_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_2025_06_user_id_language_time_idx ON public.heartbeats_2025_06 USING btree (user_id, language, "time") WHERE ((deleted_at IS NULL) AND (language IS NOT NULL));


--
-- Name: heartbeats_2025_06_user_id_operating_system_time_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_2025_06_user_id_operating_system_time_idx ON public.heartbeats_2025_06 USING btree (user_id, operating_system, "time") WHERE ((deleted_at IS NULL) AND (operating_system IS NOT NULL));


--
-- Name: heartbeats_2025_06_user_id_project_time_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_2025_06_user_id_project_time_idx ON public.heartbeats_2025_06 USING btree (user_id, project, "time") WHERE ((deleted_at IS NULL) AND (project IS NOT NULL));


--
-- Name: heartbeats_2025_06_user_id_time_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_2025_06_user_id_time_idx ON public.heartbeats_2025_06 USING btree (user_id, "time") WHERE (deleted_at IS NULL);


--
-- Name: heartbeats_2025_07_fields_hash_time_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX heartbeats_2025_07_fields_hash_time_idx ON public.heartbeats_2025_07 USING btree (fields_hash, "time") WHERE (deleted_at IS NULL);


--
-- Name: heartbeats_2025_07_ip_address_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_2025_07_ip_address_idx ON public.heartbeats_2025_07 USING btree (ip_address) WHERE ((deleted_at IS NULL) AND (ip_address IS NOT NULL));


--
-- Name: heartbeats_2025_07_machine_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_2025_07_machine_idx ON public.heartbeats_2025_07 USING btree (machine) WHERE ((deleted_at IS NULL) AND (machine IS NOT NULL));


--
-- Name: heartbeats_2025_07_time_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_2025_07_time_idx ON public.heartbeats_2025_07 USING btree ("time" DESC) WHERE ((deleted_at IS NULL) AND (source_type = 0) AND ((category)::text = 'coding'::text));


--
-- Name: heartbeats_2025_07_user_id_category_time_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_2025_07_user_id_category_time_idx ON public.heartbeats_2025_07 USING btree (user_id, category, "time") WHERE ((deleted_at IS NULL) AND (category IS NOT NULL));


--
-- Name: heartbeats_2025_07_user_id_editor_time_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_2025_07_user_id_editor_time_idx ON public.heartbeats_2025_07 USING btree (user_id, editor, "time") WHERE ((deleted_at IS NULL) AND (editor IS NOT NULL));


--
-- Name: heartbeats_2025_07_user_id_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_2025_07_user_id_id_idx ON public.heartbeats_2025_07 USING btree (user_id, id) WHERE ((deleted_at IS NULL) AND (source_type = 0));


--
-- Name: heartbeats_2025_07_user_id_id_idx1; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_2025_07_user_id_id_idx1 ON public.heartbeats_2025_07 USING btree (user_id, id DESC) WHERE ((deleted_at IS NULL) AND (ip_address IS NOT NULL));


--
-- Name: heartbeats_2025_07_user_id_language_time_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_2025_07_user_id_language_time_idx ON public.heartbeats_2025_07 USING btree (user_id, language, "time") WHERE ((deleted_at IS NULL) AND (language IS NOT NULL));


--
-- Name: heartbeats_2025_07_user_id_operating_system_time_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_2025_07_user_id_operating_system_time_idx ON public.heartbeats_2025_07 USING btree (user_id, operating_system, "time") WHERE ((deleted_at IS NULL) AND (operating_system IS NOT NULL));


--
-- Name: heartbeats_2025_07_user_id_project_time_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_2025_07_user_id_project_time_idx ON public.heartbeats_2025_07 USING btree (user_id, project, "time") WHERE ((deleted_at IS NULL) AND (project IS NOT NULL));


--
-- Name: heartbeats_2025_07_user_id_time_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_2025_07_user_id_time_idx ON public.heartbeats_2025_07 USING btree (user_id, "time") WHERE (deleted_at IS NULL);


--
-- Name: heartbeats_2025_08_fields_hash_time_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX heartbeats_2025_08_fields_hash_time_idx ON public.heartbeats_2025_08 USING btree (fields_hash, "time") WHERE (deleted_at IS NULL);


--
-- Name: heartbeats_2025_08_ip_address_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_2025_08_ip_address_idx ON public.heartbeats_2025_08 USING btree (ip_address) WHERE ((deleted_at IS NULL) AND (ip_address IS NOT NULL));


--
-- Name: heartbeats_2025_08_machine_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_2025_08_machine_idx ON public.heartbeats_2025_08 USING btree (machine) WHERE ((deleted_at IS NULL) AND (machine IS NOT NULL));


--
-- Name: heartbeats_2025_08_time_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_2025_08_time_idx ON public.heartbeats_2025_08 USING btree ("time" DESC) WHERE ((deleted_at IS NULL) AND (source_type = 0) AND ((category)::text = 'coding'::text));


--
-- Name: heartbeats_2025_08_user_id_category_time_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_2025_08_user_id_category_time_idx ON public.heartbeats_2025_08 USING btree (user_id, category, "time") WHERE ((deleted_at IS NULL) AND (category IS NOT NULL));


--
-- Name: heartbeats_2025_08_user_id_editor_time_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_2025_08_user_id_editor_time_idx ON public.heartbeats_2025_08 USING btree (user_id, editor, "time") WHERE ((deleted_at IS NULL) AND (editor IS NOT NULL));


--
-- Name: heartbeats_2025_08_user_id_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_2025_08_user_id_id_idx ON public.heartbeats_2025_08 USING btree (user_id, id) WHERE ((deleted_at IS NULL) AND (source_type = 0));


--
-- Name: heartbeats_2025_08_user_id_id_idx1; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_2025_08_user_id_id_idx1 ON public.heartbeats_2025_08 USING btree (user_id, id DESC) WHERE ((deleted_at IS NULL) AND (ip_address IS NOT NULL));


--
-- Name: heartbeats_2025_08_user_id_language_time_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_2025_08_user_id_language_time_idx ON public.heartbeats_2025_08 USING btree (user_id, language, "time") WHERE ((deleted_at IS NULL) AND (language IS NOT NULL));


--
-- Name: heartbeats_2025_08_user_id_operating_system_time_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_2025_08_user_id_operating_system_time_idx ON public.heartbeats_2025_08 USING btree (user_id, operating_system, "time") WHERE ((deleted_at IS NULL) AND (operating_system IS NOT NULL));


--
-- Name: heartbeats_2025_08_user_id_project_time_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_2025_08_user_id_project_time_idx ON public.heartbeats_2025_08 USING btree (user_id, project, "time") WHERE ((deleted_at IS NULL) AND (project IS NOT NULL));


--
-- Name: heartbeats_2025_08_user_id_time_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_2025_08_user_id_time_idx ON public.heartbeats_2025_08 USING btree (user_id, "time") WHERE (deleted_at IS NULL);


--
-- Name: heartbeats_2025_09_fields_hash_time_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX heartbeats_2025_09_fields_hash_time_idx ON public.heartbeats_2025_09 USING btree (fields_hash, "time") WHERE (deleted_at IS NULL);


--
-- Name: heartbeats_2025_09_ip_address_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_2025_09_ip_address_idx ON public.heartbeats_2025_09 USING btree (ip_address) WHERE ((deleted_at IS NULL) AND (ip_address IS NOT NULL));


--
-- Name: heartbeats_2025_09_machine_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_2025_09_machine_idx ON public.heartbeats_2025_09 USING btree (machine) WHERE ((deleted_at IS NULL) AND (machine IS NOT NULL));


--
-- Name: heartbeats_2025_09_time_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_2025_09_time_idx ON public.heartbeats_2025_09 USING btree ("time" DESC) WHERE ((deleted_at IS NULL) AND (source_type = 0) AND ((category)::text = 'coding'::text));


--
-- Name: heartbeats_2025_09_user_id_category_time_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_2025_09_user_id_category_time_idx ON public.heartbeats_2025_09 USING btree (user_id, category, "time") WHERE ((deleted_at IS NULL) AND (category IS NOT NULL));


--
-- Name: heartbeats_2025_09_user_id_editor_time_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_2025_09_user_id_editor_time_idx ON public.heartbeats_2025_09 USING btree (user_id, editor, "time") WHERE ((deleted_at IS NULL) AND (editor IS NOT NULL));


--
-- Name: heartbeats_2025_09_user_id_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_2025_09_user_id_id_idx ON public.heartbeats_2025_09 USING btree (user_id, id) WHERE ((deleted_at IS NULL) AND (source_type = 0));


--
-- Name: heartbeats_2025_09_user_id_id_idx1; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_2025_09_user_id_id_idx1 ON public.heartbeats_2025_09 USING btree (user_id, id DESC) WHERE ((deleted_at IS NULL) AND (ip_address IS NOT NULL));


--
-- Name: heartbeats_2025_09_user_id_language_time_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_2025_09_user_id_language_time_idx ON public.heartbeats_2025_09 USING btree (user_id, language, "time") WHERE ((deleted_at IS NULL) AND (language IS NOT NULL));


--
-- Name: heartbeats_2025_09_user_id_operating_system_time_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_2025_09_user_id_operating_system_time_idx ON public.heartbeats_2025_09 USING btree (user_id, operating_system, "time") WHERE ((deleted_at IS NULL) AND (operating_system IS NOT NULL));


--
-- Name: heartbeats_2025_09_user_id_project_time_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_2025_09_user_id_project_time_idx ON public.heartbeats_2025_09 USING btree (user_id, project, "time") WHERE ((deleted_at IS NULL) AND (project IS NOT NULL));


--
-- Name: heartbeats_2025_09_user_id_time_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_2025_09_user_id_time_idx ON public.heartbeats_2025_09 USING btree (user_id, "time") WHERE (deleted_at IS NULL);


--
-- Name: heartbeats_2025_10_fields_hash_time_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX heartbeats_2025_10_fields_hash_time_idx ON public.heartbeats_2025_10 USING btree (fields_hash, "time") WHERE (deleted_at IS NULL);


--
-- Name: heartbeats_2025_10_ip_address_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_2025_10_ip_address_idx ON public.heartbeats_2025_10 USING btree (ip_address) WHERE ((deleted_at IS NULL) AND (ip_address IS NOT NULL));


--
-- Name: heartbeats_2025_10_machine_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_2025_10_machine_idx ON public.heartbeats_2025_10 USING btree (machine) WHERE ((deleted_at IS NULL) AND (machine IS NOT NULL));


--
-- Name: heartbeats_2025_10_time_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_2025_10_time_idx ON public.heartbeats_2025_10 USING btree ("time" DESC) WHERE ((deleted_at IS NULL) AND (source_type = 0) AND ((category)::text = 'coding'::text));


--
-- Name: heartbeats_2025_10_user_id_category_time_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_2025_10_user_id_category_time_idx ON public.heartbeats_2025_10 USING btree (user_id, category, "time") WHERE ((deleted_at IS NULL) AND (category IS NOT NULL));


--
-- Name: heartbeats_2025_10_user_id_editor_time_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_2025_10_user_id_editor_time_idx ON public.heartbeats_2025_10 USING btree (user_id, editor, "time") WHERE ((deleted_at IS NULL) AND (editor IS NOT NULL));


--
-- Name: heartbeats_2025_10_user_id_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_2025_10_user_id_id_idx ON public.heartbeats_2025_10 USING btree (user_id, id) WHERE ((deleted_at IS NULL) AND (source_type = 0));


--
-- Name: heartbeats_2025_10_user_id_id_idx1; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_2025_10_user_id_id_idx1 ON public.heartbeats_2025_10 USING btree (user_id, id DESC) WHERE ((deleted_at IS NULL) AND (ip_address IS NOT NULL));


--
-- Name: heartbeats_2025_10_user_id_language_time_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_2025_10_user_id_language_time_idx ON public.heartbeats_2025_10 USING btree (user_id, language, "time") WHERE ((deleted_at IS NULL) AND (language IS NOT NULL));


--
-- Name: heartbeats_2025_10_user_id_operating_system_time_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_2025_10_user_id_operating_system_time_idx ON public.heartbeats_2025_10 USING btree (user_id, operating_system, "time") WHERE ((deleted_at IS NULL) AND (operating_system IS NOT NULL));


--
-- Name: heartbeats_2025_10_user_id_project_time_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_2025_10_user_id_project_time_idx ON public.heartbeats_2025_10 USING btree (user_id, project, "time") WHERE ((deleted_at IS NULL) AND (project IS NOT NULL));


--
-- Name: heartbeats_2025_10_user_id_time_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_2025_10_user_id_time_idx ON public.heartbeats_2025_10 USING btree (user_id, "time") WHERE (deleted_at IS NULL);


--
-- Name: heartbeats_2025_11_fields_hash_time_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX heartbeats_2025_11_fields_hash_time_idx ON public.heartbeats_2025_11 USING btree (fields_hash, "time") WHERE (deleted_at IS NULL);


--
-- Name: heartbeats_2025_11_ip_address_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_2025_11_ip_address_idx ON public.heartbeats_2025_11 USING btree (ip_address) WHERE ((deleted_at IS NULL) AND (ip_address IS NOT NULL));


--
-- Name: heartbeats_2025_11_machine_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_2025_11_machine_idx ON public.heartbeats_2025_11 USING btree (machine) WHERE ((deleted_at IS NULL) AND (machine IS NOT NULL));


--
-- Name: heartbeats_2025_11_time_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_2025_11_time_idx ON public.heartbeats_2025_11 USING btree ("time" DESC) WHERE ((deleted_at IS NULL) AND (source_type = 0) AND ((category)::text = 'coding'::text));


--
-- Name: heartbeats_2025_11_user_id_category_time_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_2025_11_user_id_category_time_idx ON public.heartbeats_2025_11 USING btree (user_id, category, "time") WHERE ((deleted_at IS NULL) AND (category IS NOT NULL));


--
-- Name: heartbeats_2025_11_user_id_editor_time_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_2025_11_user_id_editor_time_idx ON public.heartbeats_2025_11 USING btree (user_id, editor, "time") WHERE ((deleted_at IS NULL) AND (editor IS NOT NULL));


--
-- Name: heartbeats_2025_11_user_id_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_2025_11_user_id_id_idx ON public.heartbeats_2025_11 USING btree (user_id, id) WHERE ((deleted_at IS NULL) AND (source_type = 0));


--
-- Name: heartbeats_2025_11_user_id_id_idx1; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_2025_11_user_id_id_idx1 ON public.heartbeats_2025_11 USING btree (user_id, id DESC) WHERE ((deleted_at IS NULL) AND (ip_address IS NOT NULL));


--
-- Name: heartbeats_2025_11_user_id_language_time_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_2025_11_user_id_language_time_idx ON public.heartbeats_2025_11 USING btree (user_id, language, "time") WHERE ((deleted_at IS NULL) AND (language IS NOT NULL));


--
-- Name: heartbeats_2025_11_user_id_operating_system_time_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_2025_11_user_id_operating_system_time_idx ON public.heartbeats_2025_11 USING btree (user_id, operating_system, "time") WHERE ((deleted_at IS NULL) AND (operating_system IS NOT NULL));


--
-- Name: heartbeats_2025_11_user_id_project_time_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_2025_11_user_id_project_time_idx ON public.heartbeats_2025_11 USING btree (user_id, project, "time") WHERE ((deleted_at IS NULL) AND (project IS NOT NULL));


--
-- Name: heartbeats_2025_11_user_id_time_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_2025_11_user_id_time_idx ON public.heartbeats_2025_11 USING btree (user_id, "time") WHERE (deleted_at IS NULL);


--
-- Name: heartbeats_2025_12_fields_hash_time_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX heartbeats_2025_12_fields_hash_time_idx ON public.heartbeats_2025_12 USING btree (fields_hash, "time") WHERE (deleted_at IS NULL);


--
-- Name: heartbeats_2025_12_ip_address_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_2025_12_ip_address_idx ON public.heartbeats_2025_12 USING btree (ip_address) WHERE ((deleted_at IS NULL) AND (ip_address IS NOT NULL));


--
-- Name: heartbeats_2025_12_machine_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_2025_12_machine_idx ON public.heartbeats_2025_12 USING btree (machine) WHERE ((deleted_at IS NULL) AND (machine IS NOT NULL));


--
-- Name: heartbeats_2025_12_time_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_2025_12_time_idx ON public.heartbeats_2025_12 USING btree ("time" DESC) WHERE ((deleted_at IS NULL) AND (source_type = 0) AND ((category)::text = 'coding'::text));


--
-- Name: heartbeats_2025_12_user_id_category_time_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_2025_12_user_id_category_time_idx ON public.heartbeats_2025_12 USING btree (user_id, category, "time") WHERE ((deleted_at IS NULL) AND (category IS NOT NULL));


--
-- Name: heartbeats_2025_12_user_id_editor_time_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_2025_12_user_id_editor_time_idx ON public.heartbeats_2025_12 USING btree (user_id, editor, "time") WHERE ((deleted_at IS NULL) AND (editor IS NOT NULL));


--
-- Name: heartbeats_2025_12_user_id_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_2025_12_user_id_id_idx ON public.heartbeats_2025_12 USING btree (user_id, id) WHERE ((deleted_at IS NULL) AND (source_type = 0));


--
-- Name: heartbeats_2025_12_user_id_id_idx1; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_2025_12_user_id_id_idx1 ON public.heartbeats_2025_12 USING btree (user_id, id DESC) WHERE ((deleted_at IS NULL) AND (ip_address IS NOT NULL));


--
-- Name: heartbeats_2025_12_user_id_language_time_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_2025_12_user_id_language_time_idx ON public.heartbeats_2025_12 USING btree (user_id, language, "time") WHERE ((deleted_at IS NULL) AND (language IS NOT NULL));


--
-- Name: heartbeats_2025_12_user_id_operating_system_time_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_2025_12_user_id_operating_system_time_idx ON public.heartbeats_2025_12 USING btree (user_id, operating_system, "time") WHERE ((deleted_at IS NULL) AND (operating_system IS NOT NULL));


--
-- Name: heartbeats_2025_12_user_id_project_time_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_2025_12_user_id_project_time_idx ON public.heartbeats_2025_12 USING btree (user_id, project, "time") WHERE ((deleted_at IS NULL) AND (project IS NOT NULL));


--
-- Name: heartbeats_2025_12_user_id_time_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_2025_12_user_id_time_idx ON public.heartbeats_2025_12 USING btree (user_id, "time") WHERE (deleted_at IS NULL);


--
-- Name: heartbeats_2026_01_fields_hash_time_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX heartbeats_2026_01_fields_hash_time_idx ON public.heartbeats_2026_01 USING btree (fields_hash, "time") WHERE (deleted_at IS NULL);


--
-- Name: heartbeats_2026_01_ip_address_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_2026_01_ip_address_idx ON public.heartbeats_2026_01 USING btree (ip_address) WHERE ((deleted_at IS NULL) AND (ip_address IS NOT NULL));


--
-- Name: heartbeats_2026_01_machine_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_2026_01_machine_idx ON public.heartbeats_2026_01 USING btree (machine) WHERE ((deleted_at IS NULL) AND (machine IS NOT NULL));


--
-- Name: heartbeats_2026_01_time_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_2026_01_time_idx ON public.heartbeats_2026_01 USING btree ("time" DESC) WHERE ((deleted_at IS NULL) AND (source_type = 0) AND ((category)::text = 'coding'::text));


--
-- Name: heartbeats_2026_01_user_id_category_time_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_2026_01_user_id_category_time_idx ON public.heartbeats_2026_01 USING btree (user_id, category, "time") WHERE ((deleted_at IS NULL) AND (category IS NOT NULL));


--
-- Name: heartbeats_2026_01_user_id_editor_time_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_2026_01_user_id_editor_time_idx ON public.heartbeats_2026_01 USING btree (user_id, editor, "time") WHERE ((deleted_at IS NULL) AND (editor IS NOT NULL));


--
-- Name: heartbeats_2026_01_user_id_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_2026_01_user_id_id_idx ON public.heartbeats_2026_01 USING btree (user_id, id) WHERE ((deleted_at IS NULL) AND (source_type = 0));


--
-- Name: heartbeats_2026_01_user_id_id_idx1; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_2026_01_user_id_id_idx1 ON public.heartbeats_2026_01 USING btree (user_id, id DESC) WHERE ((deleted_at IS NULL) AND (ip_address IS NOT NULL));


--
-- Name: heartbeats_2026_01_user_id_language_time_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_2026_01_user_id_language_time_idx ON public.heartbeats_2026_01 USING btree (user_id, language, "time") WHERE ((deleted_at IS NULL) AND (language IS NOT NULL));


--
-- Name: heartbeats_2026_01_user_id_operating_system_time_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_2026_01_user_id_operating_system_time_idx ON public.heartbeats_2026_01 USING btree (user_id, operating_system, "time") WHERE ((deleted_at IS NULL) AND (operating_system IS NOT NULL));


--
-- Name: heartbeats_2026_01_user_id_project_time_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_2026_01_user_id_project_time_idx ON public.heartbeats_2026_01 USING btree (user_id, project, "time") WHERE ((deleted_at IS NULL) AND (project IS NOT NULL));


--
-- Name: heartbeats_2026_01_user_id_time_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_2026_01_user_id_time_idx ON public.heartbeats_2026_01 USING btree (user_id, "time") WHERE (deleted_at IS NULL);


--
-- Name: heartbeats_2026_02_fields_hash_time_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX heartbeats_2026_02_fields_hash_time_idx ON public.heartbeats_2026_02 USING btree (fields_hash, "time") WHERE (deleted_at IS NULL);


--
-- Name: heartbeats_2026_02_ip_address_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_2026_02_ip_address_idx ON public.heartbeats_2026_02 USING btree (ip_address) WHERE ((deleted_at IS NULL) AND (ip_address IS NOT NULL));


--
-- Name: heartbeats_2026_02_machine_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_2026_02_machine_idx ON public.heartbeats_2026_02 USING btree (machine) WHERE ((deleted_at IS NULL) AND (machine IS NOT NULL));


--
-- Name: heartbeats_2026_02_time_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_2026_02_time_idx ON public.heartbeats_2026_02 USING btree ("time" DESC) WHERE ((deleted_at IS NULL) AND (source_type = 0) AND ((category)::text = 'coding'::text));


--
-- Name: heartbeats_2026_02_user_id_category_time_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_2026_02_user_id_category_time_idx ON public.heartbeats_2026_02 USING btree (user_id, category, "time") WHERE ((deleted_at IS NULL) AND (category IS NOT NULL));


--
-- Name: heartbeats_2026_02_user_id_editor_time_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_2026_02_user_id_editor_time_idx ON public.heartbeats_2026_02 USING btree (user_id, editor, "time") WHERE ((deleted_at IS NULL) AND (editor IS NOT NULL));


--
-- Name: heartbeats_2026_02_user_id_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_2026_02_user_id_id_idx ON public.heartbeats_2026_02 USING btree (user_id, id) WHERE ((deleted_at IS NULL) AND (source_type = 0));


--
-- Name: heartbeats_2026_02_user_id_id_idx1; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_2026_02_user_id_id_idx1 ON public.heartbeats_2026_02 USING btree (user_id, id DESC) WHERE ((deleted_at IS NULL) AND (ip_address IS NOT NULL));


--
-- Name: heartbeats_2026_02_user_id_language_time_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_2026_02_user_id_language_time_idx ON public.heartbeats_2026_02 USING btree (user_id, language, "time") WHERE ((deleted_at IS NULL) AND (language IS NOT NULL));


--
-- Name: heartbeats_2026_02_user_id_operating_system_time_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_2026_02_user_id_operating_system_time_idx ON public.heartbeats_2026_02 USING btree (user_id, operating_system, "time") WHERE ((deleted_at IS NULL) AND (operating_system IS NOT NULL));


--
-- Name: heartbeats_2026_02_user_id_project_time_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_2026_02_user_id_project_time_idx ON public.heartbeats_2026_02 USING btree (user_id, project, "time") WHERE ((deleted_at IS NULL) AND (project IS NOT NULL));


--
-- Name: heartbeats_2026_02_user_id_time_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_2026_02_user_id_time_idx ON public.heartbeats_2026_02 USING btree (user_id, "time") WHERE (deleted_at IS NULL);


--
-- Name: heartbeats_2026_03_fields_hash_time_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX heartbeats_2026_03_fields_hash_time_idx ON public.heartbeats_2026_03 USING btree (fields_hash, "time") WHERE (deleted_at IS NULL);


--
-- Name: heartbeats_2026_03_ip_address_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_2026_03_ip_address_idx ON public.heartbeats_2026_03 USING btree (ip_address) WHERE ((deleted_at IS NULL) AND (ip_address IS NOT NULL));


--
-- Name: heartbeats_2026_03_machine_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_2026_03_machine_idx ON public.heartbeats_2026_03 USING btree (machine) WHERE ((deleted_at IS NULL) AND (machine IS NOT NULL));


--
-- Name: heartbeats_2026_03_time_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_2026_03_time_idx ON public.heartbeats_2026_03 USING btree ("time" DESC) WHERE ((deleted_at IS NULL) AND (source_type = 0) AND ((category)::text = 'coding'::text));


--
-- Name: heartbeats_2026_03_user_id_category_time_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_2026_03_user_id_category_time_idx ON public.heartbeats_2026_03 USING btree (user_id, category, "time") WHERE ((deleted_at IS NULL) AND (category IS NOT NULL));


--
-- Name: heartbeats_2026_03_user_id_editor_time_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_2026_03_user_id_editor_time_idx ON public.heartbeats_2026_03 USING btree (user_id, editor, "time") WHERE ((deleted_at IS NULL) AND (editor IS NOT NULL));


--
-- Name: heartbeats_2026_03_user_id_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_2026_03_user_id_id_idx ON public.heartbeats_2026_03 USING btree (user_id, id) WHERE ((deleted_at IS NULL) AND (source_type = 0));


--
-- Name: heartbeats_2026_03_user_id_id_idx1; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_2026_03_user_id_id_idx1 ON public.heartbeats_2026_03 USING btree (user_id, id DESC) WHERE ((deleted_at IS NULL) AND (ip_address IS NOT NULL));


--
-- Name: heartbeats_2026_03_user_id_language_time_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_2026_03_user_id_language_time_idx ON public.heartbeats_2026_03 USING btree (user_id, language, "time") WHERE ((deleted_at IS NULL) AND (language IS NOT NULL));


--
-- Name: heartbeats_2026_03_user_id_operating_system_time_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_2026_03_user_id_operating_system_time_idx ON public.heartbeats_2026_03 USING btree (user_id, operating_system, "time") WHERE ((deleted_at IS NULL) AND (operating_system IS NOT NULL));


--
-- Name: heartbeats_2026_03_user_id_project_time_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_2026_03_user_id_project_time_idx ON public.heartbeats_2026_03 USING btree (user_id, project, "time") WHERE ((deleted_at IS NULL) AND (project IS NOT NULL));


--
-- Name: heartbeats_2026_03_user_id_time_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_2026_03_user_id_time_idx ON public.heartbeats_2026_03 USING btree (user_id, "time") WHERE (deleted_at IS NULL);


--
-- Name: heartbeats_2026_04_fields_hash_time_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX heartbeats_2026_04_fields_hash_time_idx ON public.heartbeats_2026_04 USING btree (fields_hash, "time") WHERE (deleted_at IS NULL);


--
-- Name: heartbeats_2026_04_ip_address_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_2026_04_ip_address_idx ON public.heartbeats_2026_04 USING btree (ip_address) WHERE ((deleted_at IS NULL) AND (ip_address IS NOT NULL));


--
-- Name: heartbeats_2026_04_machine_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_2026_04_machine_idx ON public.heartbeats_2026_04 USING btree (machine) WHERE ((deleted_at IS NULL) AND (machine IS NOT NULL));


--
-- Name: heartbeats_2026_04_time_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_2026_04_time_idx ON public.heartbeats_2026_04 USING btree ("time" DESC) WHERE ((deleted_at IS NULL) AND (source_type = 0) AND ((category)::text = 'coding'::text));


--
-- Name: heartbeats_2026_04_user_id_category_time_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_2026_04_user_id_category_time_idx ON public.heartbeats_2026_04 USING btree (user_id, category, "time") WHERE ((deleted_at IS NULL) AND (category IS NOT NULL));


--
-- Name: heartbeats_2026_04_user_id_editor_time_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_2026_04_user_id_editor_time_idx ON public.heartbeats_2026_04 USING btree (user_id, editor, "time") WHERE ((deleted_at IS NULL) AND (editor IS NOT NULL));


--
-- Name: heartbeats_2026_04_user_id_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_2026_04_user_id_id_idx ON public.heartbeats_2026_04 USING btree (user_id, id) WHERE ((deleted_at IS NULL) AND (source_type = 0));


--
-- Name: heartbeats_2026_04_user_id_id_idx1; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_2026_04_user_id_id_idx1 ON public.heartbeats_2026_04 USING btree (user_id, id DESC) WHERE ((deleted_at IS NULL) AND (ip_address IS NOT NULL));


--
-- Name: heartbeats_2026_04_user_id_language_time_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_2026_04_user_id_language_time_idx ON public.heartbeats_2026_04 USING btree (user_id, language, "time") WHERE ((deleted_at IS NULL) AND (language IS NOT NULL));


--
-- Name: heartbeats_2026_04_user_id_operating_system_time_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_2026_04_user_id_operating_system_time_idx ON public.heartbeats_2026_04 USING btree (user_id, operating_system, "time") WHERE ((deleted_at IS NULL) AND (operating_system IS NOT NULL));


--
-- Name: heartbeats_2026_04_user_id_project_time_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_2026_04_user_id_project_time_idx ON public.heartbeats_2026_04 USING btree (user_id, project, "time") WHERE ((deleted_at IS NULL) AND (project IS NOT NULL));


--
-- Name: heartbeats_2026_04_user_id_time_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_2026_04_user_id_time_idx ON public.heartbeats_2026_04 USING btree (user_id, "time") WHERE (deleted_at IS NULL);


--
-- Name: heartbeats_2026_05_fields_hash_time_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX heartbeats_2026_05_fields_hash_time_idx ON public.heartbeats_2026_05 USING btree (fields_hash, "time") WHERE (deleted_at IS NULL);


--
-- Name: heartbeats_2026_05_ip_address_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_2026_05_ip_address_idx ON public.heartbeats_2026_05 USING btree (ip_address) WHERE ((deleted_at IS NULL) AND (ip_address IS NOT NULL));


--
-- Name: heartbeats_2026_05_machine_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_2026_05_machine_idx ON public.heartbeats_2026_05 USING btree (machine) WHERE ((deleted_at IS NULL) AND (machine IS NOT NULL));


--
-- Name: heartbeats_2026_05_time_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_2026_05_time_idx ON public.heartbeats_2026_05 USING btree ("time" DESC) WHERE ((deleted_at IS NULL) AND (source_type = 0) AND ((category)::text = 'coding'::text));


--
-- Name: heartbeats_2026_05_user_id_category_time_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_2026_05_user_id_category_time_idx ON public.heartbeats_2026_05 USING btree (user_id, category, "time") WHERE ((deleted_at IS NULL) AND (category IS NOT NULL));


--
-- Name: heartbeats_2026_05_user_id_editor_time_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_2026_05_user_id_editor_time_idx ON public.heartbeats_2026_05 USING btree (user_id, editor, "time") WHERE ((deleted_at IS NULL) AND (editor IS NOT NULL));


--
-- Name: heartbeats_2026_05_user_id_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_2026_05_user_id_id_idx ON public.heartbeats_2026_05 USING btree (user_id, id) WHERE ((deleted_at IS NULL) AND (source_type = 0));


--
-- Name: heartbeats_2026_05_user_id_id_idx1; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_2026_05_user_id_id_idx1 ON public.heartbeats_2026_05 USING btree (user_id, id DESC) WHERE ((deleted_at IS NULL) AND (ip_address IS NOT NULL));


--
-- Name: heartbeats_2026_05_user_id_language_time_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_2026_05_user_id_language_time_idx ON public.heartbeats_2026_05 USING btree (user_id, language, "time") WHERE ((deleted_at IS NULL) AND (language IS NOT NULL));


--
-- Name: heartbeats_2026_05_user_id_operating_system_time_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_2026_05_user_id_operating_system_time_idx ON public.heartbeats_2026_05 USING btree (user_id, operating_system, "time") WHERE ((deleted_at IS NULL) AND (operating_system IS NOT NULL));


--
-- Name: heartbeats_2026_05_user_id_project_time_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_2026_05_user_id_project_time_idx ON public.heartbeats_2026_05 USING btree (user_id, project, "time") WHERE ((deleted_at IS NULL) AND (project IS NOT NULL));


--
-- Name: heartbeats_2026_05_user_id_time_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_2026_05_user_id_time_idx ON public.heartbeats_2026_05 USING btree (user_id, "time") WHERE (deleted_at IS NULL);


--
-- Name: heartbeats_2026_06_fields_hash_time_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX heartbeats_2026_06_fields_hash_time_idx ON public.heartbeats_2026_06 USING btree (fields_hash, "time") WHERE (deleted_at IS NULL);


--
-- Name: heartbeats_2026_06_ip_address_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_2026_06_ip_address_idx ON public.heartbeats_2026_06 USING btree (ip_address) WHERE ((deleted_at IS NULL) AND (ip_address IS NOT NULL));


--
-- Name: heartbeats_2026_06_machine_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_2026_06_machine_idx ON public.heartbeats_2026_06 USING btree (machine) WHERE ((deleted_at IS NULL) AND (machine IS NOT NULL));


--
-- Name: heartbeats_2026_06_time_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_2026_06_time_idx ON public.heartbeats_2026_06 USING btree ("time" DESC) WHERE ((deleted_at IS NULL) AND (source_type = 0) AND ((category)::text = 'coding'::text));


--
-- Name: heartbeats_2026_06_user_id_category_time_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_2026_06_user_id_category_time_idx ON public.heartbeats_2026_06 USING btree (user_id, category, "time") WHERE ((deleted_at IS NULL) AND (category IS NOT NULL));


--
-- Name: heartbeats_2026_06_user_id_editor_time_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_2026_06_user_id_editor_time_idx ON public.heartbeats_2026_06 USING btree (user_id, editor, "time") WHERE ((deleted_at IS NULL) AND (editor IS NOT NULL));


--
-- Name: heartbeats_2026_06_user_id_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_2026_06_user_id_id_idx ON public.heartbeats_2026_06 USING btree (user_id, id) WHERE ((deleted_at IS NULL) AND (source_type = 0));


--
-- Name: heartbeats_2026_06_user_id_id_idx1; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_2026_06_user_id_id_idx1 ON public.heartbeats_2026_06 USING btree (user_id, id DESC) WHERE ((deleted_at IS NULL) AND (ip_address IS NOT NULL));


--
-- Name: heartbeats_2026_06_user_id_language_time_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_2026_06_user_id_language_time_idx ON public.heartbeats_2026_06 USING btree (user_id, language, "time") WHERE ((deleted_at IS NULL) AND (language IS NOT NULL));


--
-- Name: heartbeats_2026_06_user_id_operating_system_time_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_2026_06_user_id_operating_system_time_idx ON public.heartbeats_2026_06 USING btree (user_id, operating_system, "time") WHERE ((deleted_at IS NULL) AND (operating_system IS NOT NULL));


--
-- Name: heartbeats_2026_06_user_id_project_time_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_2026_06_user_id_project_time_idx ON public.heartbeats_2026_06 USING btree (user_id, project, "time") WHERE ((deleted_at IS NULL) AND (project IS NOT NULL));


--
-- Name: heartbeats_2026_06_user_id_time_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_2026_06_user_id_time_idx ON public.heartbeats_2026_06 USING btree (user_id, "time") WHERE (deleted_at IS NULL);


--
-- Name: heartbeats_2026_07_fields_hash_time_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX heartbeats_2026_07_fields_hash_time_idx ON public.heartbeats_2026_07 USING btree (fields_hash, "time") WHERE (deleted_at IS NULL);


--
-- Name: heartbeats_2026_07_ip_address_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_2026_07_ip_address_idx ON public.heartbeats_2026_07 USING btree (ip_address) WHERE ((deleted_at IS NULL) AND (ip_address IS NOT NULL));


--
-- Name: heartbeats_2026_07_machine_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_2026_07_machine_idx ON public.heartbeats_2026_07 USING btree (machine) WHERE ((deleted_at IS NULL) AND (machine IS NOT NULL));


--
-- Name: heartbeats_2026_07_time_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_2026_07_time_idx ON public.heartbeats_2026_07 USING btree ("time" DESC) WHERE ((deleted_at IS NULL) AND (source_type = 0) AND ((category)::text = 'coding'::text));


--
-- Name: heartbeats_2026_07_user_id_category_time_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_2026_07_user_id_category_time_idx ON public.heartbeats_2026_07 USING btree (user_id, category, "time") WHERE ((deleted_at IS NULL) AND (category IS NOT NULL));


--
-- Name: heartbeats_2026_07_user_id_editor_time_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_2026_07_user_id_editor_time_idx ON public.heartbeats_2026_07 USING btree (user_id, editor, "time") WHERE ((deleted_at IS NULL) AND (editor IS NOT NULL));


--
-- Name: heartbeats_2026_07_user_id_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_2026_07_user_id_id_idx ON public.heartbeats_2026_07 USING btree (user_id, id) WHERE ((deleted_at IS NULL) AND (source_type = 0));


--
-- Name: heartbeats_2026_07_user_id_id_idx1; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_2026_07_user_id_id_idx1 ON public.heartbeats_2026_07 USING btree (user_id, id DESC) WHERE ((deleted_at IS NULL) AND (ip_address IS NOT NULL));


--
-- Name: heartbeats_2026_07_user_id_language_time_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_2026_07_user_id_language_time_idx ON public.heartbeats_2026_07 USING btree (user_id, language, "time") WHERE ((deleted_at IS NULL) AND (language IS NOT NULL));


--
-- Name: heartbeats_2026_07_user_id_operating_system_time_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_2026_07_user_id_operating_system_time_idx ON public.heartbeats_2026_07 USING btree (user_id, operating_system, "time") WHERE ((deleted_at IS NULL) AND (operating_system IS NOT NULL));


--
-- Name: heartbeats_2026_07_user_id_project_time_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_2026_07_user_id_project_time_idx ON public.heartbeats_2026_07 USING btree (user_id, project, "time") WHERE ((deleted_at IS NULL) AND (project IS NOT NULL));


--
-- Name: heartbeats_2026_07_user_id_time_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_2026_07_user_id_time_idx ON public.heartbeats_2026_07 USING btree (user_id, "time") WHERE (deleted_at IS NULL);


--
-- Name: heartbeats_before_2024_fields_hash_time_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX heartbeats_before_2024_fields_hash_time_idx ON public.heartbeats_before_2024 USING btree (fields_hash, "time") WHERE (deleted_at IS NULL);


--
-- Name: heartbeats_before_2024_ip_address_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_before_2024_ip_address_idx ON public.heartbeats_before_2024 USING btree (ip_address) WHERE ((deleted_at IS NULL) AND (ip_address IS NOT NULL));


--
-- Name: heartbeats_before_2024_machine_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_before_2024_machine_idx ON public.heartbeats_before_2024 USING btree (machine) WHERE ((deleted_at IS NULL) AND (machine IS NOT NULL));


--
-- Name: heartbeats_before_2024_time_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_before_2024_time_idx ON public.heartbeats_before_2024 USING btree ("time" DESC) WHERE ((deleted_at IS NULL) AND (source_type = 0) AND ((category)::text = 'coding'::text));


--
-- Name: heartbeats_before_2024_user_id_category_time_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_before_2024_user_id_category_time_idx ON public.heartbeats_before_2024 USING btree (user_id, category, "time") WHERE ((deleted_at IS NULL) AND (category IS NOT NULL));


--
-- Name: heartbeats_before_2024_user_id_editor_time_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_before_2024_user_id_editor_time_idx ON public.heartbeats_before_2024 USING btree (user_id, editor, "time") WHERE ((deleted_at IS NULL) AND (editor IS NOT NULL));


--
-- Name: heartbeats_before_2024_user_id_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_before_2024_user_id_id_idx ON public.heartbeats_before_2024 USING btree (user_id, id) WHERE ((deleted_at IS NULL) AND (source_type = 0));


--
-- Name: heartbeats_before_2024_user_id_id_idx1; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_before_2024_user_id_id_idx1 ON public.heartbeats_before_2024 USING btree (user_id, id DESC) WHERE ((deleted_at IS NULL) AND (ip_address IS NOT NULL));


--
-- Name: heartbeats_before_2024_user_id_language_time_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_before_2024_user_id_language_time_idx ON public.heartbeats_before_2024 USING btree (user_id, language, "time") WHERE ((deleted_at IS NULL) AND (language IS NOT NULL));


--
-- Name: heartbeats_before_2024_user_id_operating_system_time_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_before_2024_user_id_operating_system_time_idx ON public.heartbeats_before_2024 USING btree (user_id, operating_system, "time") WHERE ((deleted_at IS NULL) AND (operating_system IS NOT NULL));


--
-- Name: heartbeats_before_2024_user_id_project_time_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_before_2024_user_id_project_time_idx ON public.heartbeats_before_2024 USING btree (user_id, project, "time") WHERE ((deleted_at IS NULL) AND (project IS NOT NULL));


--
-- Name: heartbeats_before_2024_user_id_time_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_before_2024_user_id_time_idx ON public.heartbeats_before_2024 USING btree (user_id, "time") WHERE (deleted_at IS NULL);


--
-- Name: heartbeats_default_fields_hash_time_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX heartbeats_default_fields_hash_time_idx ON public.heartbeats_default USING btree (fields_hash, "time") WHERE (deleted_at IS NULL);


--
-- Name: heartbeats_default_ip_address_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_default_ip_address_idx ON public.heartbeats_default USING btree (ip_address) WHERE ((deleted_at IS NULL) AND (ip_address IS NOT NULL));


--
-- Name: heartbeats_default_machine_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_default_machine_idx ON public.heartbeats_default USING btree (machine) WHERE ((deleted_at IS NULL) AND (machine IS NOT NULL));


--
-- Name: heartbeats_default_time_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_default_time_idx ON public.heartbeats_default USING btree ("time" DESC) WHERE ((deleted_at IS NULL) AND (source_type = 0) AND ((category)::text = 'coding'::text));


--
-- Name: heartbeats_default_user_id_category_time_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_default_user_id_category_time_idx ON public.heartbeats_default USING btree (user_id, category, "time") WHERE ((deleted_at IS NULL) AND (category IS NOT NULL));


--
-- Name: heartbeats_default_user_id_editor_time_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_default_user_id_editor_time_idx ON public.heartbeats_default USING btree (user_id, editor, "time") WHERE ((deleted_at IS NULL) AND (editor IS NOT NULL));


--
-- Name: heartbeats_default_user_id_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_default_user_id_id_idx ON public.heartbeats_default USING btree (user_id, id) WHERE ((deleted_at IS NULL) AND (source_type = 0));


--
-- Name: heartbeats_default_user_id_id_idx1; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_default_user_id_id_idx1 ON public.heartbeats_default USING btree (user_id, id DESC) WHERE ((deleted_at IS NULL) AND (ip_address IS NOT NULL));


--
-- Name: heartbeats_default_user_id_language_time_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_default_user_id_language_time_idx ON public.heartbeats_default USING btree (user_id, language, "time") WHERE ((deleted_at IS NULL) AND (language IS NOT NULL));


--
-- Name: heartbeats_default_user_id_operating_system_time_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_default_user_id_operating_system_time_idx ON public.heartbeats_default USING btree (user_id, operating_system, "time") WHERE ((deleted_at IS NULL) AND (operating_system IS NOT NULL));


--
-- Name: heartbeats_default_user_id_project_time_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_default_user_id_project_time_idx ON public.heartbeats_default USING btree (user_id, project, "time") WHERE ((deleted_at IS NULL) AND (project IS NOT NULL));


--
-- Name: heartbeats_default_user_id_time_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX heartbeats_default_user_id_time_idx ON public.heartbeats_default USING btree (user_id, "time") WHERE (deleted_at IS NULL);


--
-- Name: idx_leaderboard_entries_on_leaderboard_and_user; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_leaderboard_entries_on_leaderboard_and_user ON public.leaderboard_entries USING btree (leaderboard_id, user_id);


--
-- Name: idx_sailors_log_notification_preferences_unique_user_channel; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_sailors_log_notification_preferences_unique_user_channel ON public.sailors_log_notification_preferences USING btree (slack_uid, slack_channel_id);


--
-- Name: index_active_storage_attachments_on_blob_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_active_storage_attachments_on_blob_id ON public.active_storage_attachments USING btree (blob_id);


--
-- Name: index_active_storage_attachments_uniqueness; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_active_storage_attachments_uniqueness ON public.active_storage_attachments USING btree (record_type, record_id, name, blob_id);


--
-- Name: index_active_storage_blobs_on_key; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_active_storage_blobs_on_key ON public.active_storage_blobs USING btree (key);


--
-- Name: index_active_storage_variant_records_uniqueness; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_active_storage_variant_records_uniqueness ON public.active_storage_variant_records USING btree (blob_id, variation_digest);


--
-- Name: index_admin_api_keys_on_token; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_admin_api_keys_on_token ON public.admin_api_keys USING btree (token);


--
-- Name: index_admin_api_keys_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_admin_api_keys_on_user_id ON public.admin_api_keys USING btree (user_id);


--
-- Name: index_admin_api_keys_on_user_id_and_name; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_admin_api_keys_on_user_id_and_name ON public.admin_api_keys USING btree (user_id, name);


--
-- Name: index_api_keys_on_token; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_api_keys_on_token ON public.api_keys USING btree (token);


--
-- Name: index_api_keys_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_api_keys_on_user_id ON public.api_keys USING btree (user_id);


--
-- Name: index_api_keys_on_user_id_and_name; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_api_keys_on_user_id_and_name ON public.api_keys USING btree (user_id, name);


--
-- Name: index_api_keys_on_user_id_and_token; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_api_keys_on_user_id_and_token ON public.api_keys USING btree (user_id, token);


--
-- Name: index_commits_on_repository_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_commits_on_repository_id ON public.commits USING btree (repository_id);


--
-- Name: index_commits_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_commits_on_user_id ON public.commits USING btree (user_id);


--
-- Name: index_commits_on_user_id_and_created_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_commits_on_user_id_and_created_at ON public.commits USING btree (user_id, created_at);


--
-- Name: index_deletion_requests_on_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_deletion_requests_on_status ON public.deletion_requests USING btree (status);


--
-- Name: index_deletion_requests_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_deletion_requests_on_user_id ON public.deletion_requests USING btree (user_id);


--
-- Name: index_deletion_requests_on_user_id_and_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_deletion_requests_on_user_id_and_status ON public.deletion_requests USING btree (user_id, status);


--
-- Name: index_email_addresses_on_email; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_email_addresses_on_email ON public.email_addresses USING btree (email);


--
-- Name: index_email_addresses_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_email_addresses_on_user_id ON public.email_addresses USING btree (user_id);


--
-- Name: index_email_verification_requests_on_email; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_email_verification_requests_on_email ON public.email_verification_requests USING btree (email);


--
-- Name: index_email_verification_requests_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_email_verification_requests_on_user_id ON public.email_verification_requests USING btree (user_id);


--
-- Name: index_flipper_features_on_key; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_flipper_features_on_key ON public.flipper_features USING btree (key);


--
-- Name: index_flipper_gates_on_feature_key_and_key_and_value; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_flipper_gates_on_feature_key_and_key_and_value ON public.flipper_gates USING btree (feature_key, key, value);


--
-- Name: index_goals_on_user_and_scope; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_goals_on_user_and_scope ON public.goals USING btree (user_id, period, target_seconds, languages, projects);


--
-- Name: index_goals_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_goals_on_user_id ON public.goals USING btree (user_id);


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
-- Name: index_good_jobs_finished_at_with_error; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_good_jobs_finished_at_with_error ON public.good_jobs USING btree (finished_at) WHERE (error IS NOT NULL);


--
-- Name: index_good_jobs_jobs_on_finished_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_good_jobs_jobs_on_finished_at ON public.good_jobs USING btree (finished_at) WHERE ((retried_good_job_id IS NULL) AND (finished_at IS NOT NULL));


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
-- Name: index_good_jobs_on_concurrency_key_when_unfinished; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_good_jobs_on_concurrency_key_when_unfinished ON public.good_jobs USING btree (concurrency_key) WHERE (finished_at IS NULL);


--
-- Name: index_good_jobs_on_cron_key_and_created_at_cond; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_good_jobs_on_cron_key_and_created_at_cond ON public.good_jobs USING btree (cron_key, created_at) WHERE (cron_key IS NOT NULL);


--
-- Name: index_good_jobs_on_cron_key_and_cron_at_cond; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_good_jobs_on_cron_key_and_cron_at_cond ON public.good_jobs USING btree (cron_key, cron_at) WHERE (cron_key IS NOT NULL);


--
-- Name: index_good_jobs_on_labels; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_good_jobs_on_labels ON public.good_jobs USING gin (labels) WHERE (labels IS NOT NULL);


--
-- Name: index_good_jobs_on_locked_by_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_good_jobs_on_locked_by_id ON public.good_jobs USING btree (locked_by_id) WHERE (locked_by_id IS NOT NULL);


--
-- Name: index_good_jobs_on_priority_scheduled_at_unfinished_unlocked; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_good_jobs_on_priority_scheduled_at_unfinished_unlocked ON public.good_jobs USING btree (priority, scheduled_at) WHERE ((finished_at IS NULL) AND (locked_by_id IS NULL));


--
-- Name: index_good_jobs_on_queue_name_and_scheduled_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_good_jobs_on_queue_name_and_scheduled_at ON public.good_jobs USING btree (queue_name, scheduled_at) WHERE (finished_at IS NULL);


--
-- Name: index_good_jobs_on_scheduled_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_good_jobs_on_scheduled_at ON public.good_jobs USING btree (scheduled_at) WHERE (finished_at IS NULL);


--
-- Name: index_heartbeat_branches_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_heartbeat_branches_on_user_id ON public.heartbeat_branches USING btree (user_id);


--
-- Name: index_heartbeat_branches_on_user_id_and_name; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_heartbeat_branches_on_user_id_and_name ON public.heartbeat_branches USING btree (user_id, name);


--
-- Name: index_heartbeat_categories_on_name; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_heartbeat_categories_on_name ON public.heartbeat_categories USING btree (name);


--
-- Name: index_heartbeat_editors_on_name; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_heartbeat_editors_on_name ON public.heartbeat_editors USING btree (name);


--
-- Name: index_heartbeat_import_sources_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_heartbeat_import_sources_on_user_id ON public.heartbeat_import_sources USING btree (user_id);


--
-- Name: index_heartbeat_languages_on_name; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_heartbeat_languages_on_name ON public.heartbeat_languages USING btree (name);


--
-- Name: index_heartbeat_machines_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_heartbeat_machines_on_user_id ON public.heartbeat_machines USING btree (user_id);


--
-- Name: index_heartbeat_machines_on_user_id_and_name; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_heartbeat_machines_on_user_id_and_name ON public.heartbeat_machines USING btree (user_id, name);


--
-- Name: index_heartbeat_operating_systems_on_name; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_heartbeat_operating_systems_on_name ON public.heartbeat_operating_systems USING btree (name);


--
-- Name: index_heartbeat_projects_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_heartbeat_projects_on_user_id ON public.heartbeat_projects USING btree (user_id);


--
-- Name: index_heartbeat_projects_on_user_id_and_name; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_heartbeat_projects_on_user_id_and_name ON public.heartbeat_projects USING btree (user_id, name);


--
-- Name: index_heartbeat_user_agents_on_value; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_heartbeat_user_agents_on_value ON public.heartbeat_user_agents USING btree (value);


--
-- Name: index_leaderboard_entries_on_leaderboard_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_leaderboard_entries_on_leaderboard_id ON public.leaderboard_entries USING btree (leaderboard_id);


--
-- Name: index_leaderboards_on_start_date; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_leaderboards_on_start_date ON public.leaderboards USING btree (start_date) WHERE (deleted_at IS NULL);


--
-- Name: index_leaderboards_on_start_date_period_type_timezone_offset; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_leaderboards_on_start_date_period_type_timezone_offset ON public.leaderboards USING btree (start_date, period_type, timezone_offset) WHERE (deleted_at IS NULL);


--
-- Name: index_mailkick_subscriptions_on_subscriber; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_mailkick_subscriptions_on_subscriber ON public.mailkick_subscriptions USING btree (subscriber_type, subscriber_id);


--
-- Name: index_mailkick_subscriptions_on_subscriber_and_list; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_mailkick_subscriptions_on_subscriber_and_list ON public.mailkick_subscriptions USING btree (subscriber_type, subscriber_id, list);


--
-- Name: index_notable_requests_on_user; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_notable_requests_on_user ON public.notable_requests USING btree (user_type, user_id);


--
-- Name: index_oauth_access_grants_on_application_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_oauth_access_grants_on_application_id ON public.oauth_access_grants USING btree (application_id);


--
-- Name: index_oauth_access_grants_on_resource_owner_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_oauth_access_grants_on_resource_owner_id ON public.oauth_access_grants USING btree (resource_owner_id);


--
-- Name: index_oauth_access_grants_on_token; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_oauth_access_grants_on_token ON public.oauth_access_grants USING btree (token);


--
-- Name: index_oauth_access_tokens_on_application_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_oauth_access_tokens_on_application_id ON public.oauth_access_tokens USING btree (application_id);


--
-- Name: index_oauth_access_tokens_on_refresh_token; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_oauth_access_tokens_on_refresh_token ON public.oauth_access_tokens USING btree (refresh_token);


--
-- Name: index_oauth_access_tokens_on_resource_owner_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_oauth_access_tokens_on_resource_owner_id ON public.oauth_access_tokens USING btree (resource_owner_id);


--
-- Name: index_oauth_access_tokens_on_token; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_oauth_access_tokens_on_token ON public.oauth_access_tokens USING btree (token);


--
-- Name: index_oauth_applications_on_owner; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_oauth_applications_on_owner ON public.oauth_applications USING btree (owner_type, owner_id);


--
-- Name: index_oauth_applications_on_uid; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_oauth_applications_on_uid ON public.oauth_applications USING btree (uid);


--
-- Name: index_pghero_query_stats_on_database_and_captured_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_pghero_query_stats_on_database_and_captured_at ON public.pghero_query_stats USING btree (database, captured_at);


--
-- Name: index_pghero_space_stats_on_database_and_captured_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_pghero_space_stats_on_database_and_captured_at ON public.pghero_space_stats USING btree (database, captured_at);


--
-- Name: index_project_labels_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_project_labels_on_user_id ON public.project_labels USING btree (user_id);


--
-- Name: index_project_labels_on_user_id_and_project_key; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_project_labels_on_user_id_and_project_key ON public.project_labels USING btree (user_id, project_key);


--
-- Name: index_project_repo_mappings_on_project_name; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_project_repo_mappings_on_project_name ON public.project_repo_mappings USING btree (project_name);


--
-- Name: index_project_repo_mappings_on_repository_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_project_repo_mappings_on_repository_id ON public.project_repo_mappings USING btree (repository_id);


--
-- Name: index_project_repo_mappings_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_project_repo_mappings_on_user_id ON public.project_repo_mappings USING btree (user_id);


--
-- Name: index_project_repo_mappings_on_user_id_and_archived_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_project_repo_mappings_on_user_id_and_archived_at ON public.project_repo_mappings USING btree (user_id, archived_at);


--
-- Name: index_project_repo_mappings_on_user_id_and_project_name; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_project_repo_mappings_on_user_id_and_project_name ON public.project_repo_mappings USING btree (user_id, project_name);


--
-- Name: index_repo_host_events_on_provider; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_repo_host_events_on_provider ON public.repo_host_events USING btree (provider);


--
-- Name: index_repo_host_events_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_repo_host_events_on_user_id ON public.repo_host_events USING btree (user_id);


--
-- Name: index_repo_host_events_on_user_provider_created_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_repo_host_events_on_user_provider_created_at ON public.repo_host_events USING btree (user_id, provider, created_at);


--
-- Name: index_repositories_on_url; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_repositories_on_url ON public.repositories USING btree (url);


--
-- Name: index_sign_in_tokens_on_token; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_sign_in_tokens_on_token ON public.sign_in_tokens USING btree (token);


--
-- Name: index_sign_in_tokens_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_sign_in_tokens_on_user_id ON public.sign_in_tokens USING btree (user_id);


--
-- Name: index_solid_cache_entries_on_byte_size; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_solid_cache_entries_on_byte_size ON public.solid_cache_entries USING btree (byte_size);


--
-- Name: index_solid_cache_entries_on_key_hash; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_solid_cache_entries_on_key_hash ON public.solid_cache_entries USING btree (key_hash);


--
-- Name: index_solid_cache_entries_on_key_hash_and_byte_size; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_solid_cache_entries_on_key_hash_and_byte_size ON public.solid_cache_entries USING btree (key_hash, byte_size);


--
-- Name: index_trust_level_audit_logs_on_changed_by_and_created_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_trust_level_audit_logs_on_changed_by_and_created_at ON public.trust_level_audit_logs USING btree (changed_by_id, created_at);


--
-- Name: index_trust_level_audit_logs_on_changed_by_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_trust_level_audit_logs_on_changed_by_id ON public.trust_level_audit_logs USING btree (changed_by_id);


--
-- Name: index_trust_level_audit_logs_on_user_and_created_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_trust_level_audit_logs_on_user_and_created_at ON public.trust_level_audit_logs USING btree (user_id, created_at);


--
-- Name: index_trust_level_audit_logs_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_trust_level_audit_logs_on_user_id ON public.trust_level_audit_logs USING btree (user_id);


--
-- Name: index_users_on_github_uid; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_users_on_github_uid ON public.users USING btree (github_uid);


--
-- Name: index_users_on_github_uid_and_access_token; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_users_on_github_uid_and_access_token ON public.users USING btree (github_uid, github_access_token);


--
-- Name: index_users_on_slack_uid; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_users_on_slack_uid ON public.users USING btree (slack_uid);


--
-- Name: index_users_on_timezone; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_users_on_timezone ON public.users USING btree (timezone);


--
-- Name: index_users_on_timezone_trust_level; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_users_on_timezone_trust_level ON public.users USING btree (timezone, trust_level);


--
-- Name: index_users_on_username; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_users_on_username ON public.users USING btree (username);


--
-- Name: index_versions_on_item_type_and_item_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_versions_on_item_type_and_item_id ON public.versions USING btree (item_type, item_id);


--
-- Name: heartbeats_2024_01_fields_hash_time_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_fields_hash_uniq ATTACH PARTITION public.heartbeats_2024_01_fields_hash_time_idx;


--
-- Name: heartbeats_2024_01_ip_address_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_ip ATTACH PARTITION public.heartbeats_2024_01_ip_address_idx;


--
-- Name: heartbeats_2024_01_machine_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_machine ATTACH PARTITION public.heartbeats_2024_01_machine_idx;


--
-- Name: heartbeats_2024_01_time_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_current_hacking ATTACH PARTITION public.heartbeats_2024_01_time_idx;


--
-- Name: heartbeats_2024_01_user_id_category_time_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_user_category_time ATTACH PARTITION public.heartbeats_2024_01_user_id_category_time_idx;


--
-- Name: heartbeats_2024_01_user_id_editor_time_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_user_editor_time ATTACH PARTITION public.heartbeats_2024_01_user_id_editor_time_idx;


--
-- Name: heartbeats_2024_01_user_id_id_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_user_id_direct ATTACH PARTITION public.heartbeats_2024_01_user_id_id_idx;


--
-- Name: heartbeats_2024_01_user_id_id_idx1; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_user_ip_id ATTACH PARTITION public.heartbeats_2024_01_user_id_id_idx1;


--
-- Name: heartbeats_2024_01_user_id_language_time_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_user_language_time ATTACH PARTITION public.heartbeats_2024_01_user_id_language_time_idx;


--
-- Name: heartbeats_2024_01_user_id_operating_system_time_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_user_os_time ATTACH PARTITION public.heartbeats_2024_01_user_id_operating_system_time_idx;


--
-- Name: heartbeats_2024_01_user_id_project_time_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_user_project_time ATTACH PARTITION public.heartbeats_2024_01_user_id_project_time_idx;


--
-- Name: heartbeats_2024_01_user_id_time_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_user_time ATTACH PARTITION public.heartbeats_2024_01_user_id_time_idx;


--
-- Name: heartbeats_2024_02_fields_hash_time_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_fields_hash_uniq ATTACH PARTITION public.heartbeats_2024_02_fields_hash_time_idx;


--
-- Name: heartbeats_2024_02_ip_address_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_ip ATTACH PARTITION public.heartbeats_2024_02_ip_address_idx;


--
-- Name: heartbeats_2024_02_machine_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_machine ATTACH PARTITION public.heartbeats_2024_02_machine_idx;


--
-- Name: heartbeats_2024_02_time_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_current_hacking ATTACH PARTITION public.heartbeats_2024_02_time_idx;


--
-- Name: heartbeats_2024_02_user_id_category_time_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_user_category_time ATTACH PARTITION public.heartbeats_2024_02_user_id_category_time_idx;


--
-- Name: heartbeats_2024_02_user_id_editor_time_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_user_editor_time ATTACH PARTITION public.heartbeats_2024_02_user_id_editor_time_idx;


--
-- Name: heartbeats_2024_02_user_id_id_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_user_id_direct ATTACH PARTITION public.heartbeats_2024_02_user_id_id_idx;


--
-- Name: heartbeats_2024_02_user_id_id_idx1; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_user_ip_id ATTACH PARTITION public.heartbeats_2024_02_user_id_id_idx1;


--
-- Name: heartbeats_2024_02_user_id_language_time_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_user_language_time ATTACH PARTITION public.heartbeats_2024_02_user_id_language_time_idx;


--
-- Name: heartbeats_2024_02_user_id_operating_system_time_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_user_os_time ATTACH PARTITION public.heartbeats_2024_02_user_id_operating_system_time_idx;


--
-- Name: heartbeats_2024_02_user_id_project_time_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_user_project_time ATTACH PARTITION public.heartbeats_2024_02_user_id_project_time_idx;


--
-- Name: heartbeats_2024_02_user_id_time_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_user_time ATTACH PARTITION public.heartbeats_2024_02_user_id_time_idx;


--
-- Name: heartbeats_2024_03_fields_hash_time_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_fields_hash_uniq ATTACH PARTITION public.heartbeats_2024_03_fields_hash_time_idx;


--
-- Name: heartbeats_2024_03_ip_address_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_ip ATTACH PARTITION public.heartbeats_2024_03_ip_address_idx;


--
-- Name: heartbeats_2024_03_machine_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_machine ATTACH PARTITION public.heartbeats_2024_03_machine_idx;


--
-- Name: heartbeats_2024_03_time_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_current_hacking ATTACH PARTITION public.heartbeats_2024_03_time_idx;


--
-- Name: heartbeats_2024_03_user_id_category_time_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_user_category_time ATTACH PARTITION public.heartbeats_2024_03_user_id_category_time_idx;


--
-- Name: heartbeats_2024_03_user_id_editor_time_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_user_editor_time ATTACH PARTITION public.heartbeats_2024_03_user_id_editor_time_idx;


--
-- Name: heartbeats_2024_03_user_id_id_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_user_id_direct ATTACH PARTITION public.heartbeats_2024_03_user_id_id_idx;


--
-- Name: heartbeats_2024_03_user_id_id_idx1; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_user_ip_id ATTACH PARTITION public.heartbeats_2024_03_user_id_id_idx1;


--
-- Name: heartbeats_2024_03_user_id_language_time_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_user_language_time ATTACH PARTITION public.heartbeats_2024_03_user_id_language_time_idx;


--
-- Name: heartbeats_2024_03_user_id_operating_system_time_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_user_os_time ATTACH PARTITION public.heartbeats_2024_03_user_id_operating_system_time_idx;


--
-- Name: heartbeats_2024_03_user_id_project_time_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_user_project_time ATTACH PARTITION public.heartbeats_2024_03_user_id_project_time_idx;


--
-- Name: heartbeats_2024_03_user_id_time_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_user_time ATTACH PARTITION public.heartbeats_2024_03_user_id_time_idx;


--
-- Name: heartbeats_2024_04_fields_hash_time_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_fields_hash_uniq ATTACH PARTITION public.heartbeats_2024_04_fields_hash_time_idx;


--
-- Name: heartbeats_2024_04_ip_address_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_ip ATTACH PARTITION public.heartbeats_2024_04_ip_address_idx;


--
-- Name: heartbeats_2024_04_machine_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_machine ATTACH PARTITION public.heartbeats_2024_04_machine_idx;


--
-- Name: heartbeats_2024_04_time_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_current_hacking ATTACH PARTITION public.heartbeats_2024_04_time_idx;


--
-- Name: heartbeats_2024_04_user_id_category_time_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_user_category_time ATTACH PARTITION public.heartbeats_2024_04_user_id_category_time_idx;


--
-- Name: heartbeats_2024_04_user_id_editor_time_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_user_editor_time ATTACH PARTITION public.heartbeats_2024_04_user_id_editor_time_idx;


--
-- Name: heartbeats_2024_04_user_id_id_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_user_id_direct ATTACH PARTITION public.heartbeats_2024_04_user_id_id_idx;


--
-- Name: heartbeats_2024_04_user_id_id_idx1; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_user_ip_id ATTACH PARTITION public.heartbeats_2024_04_user_id_id_idx1;


--
-- Name: heartbeats_2024_04_user_id_language_time_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_user_language_time ATTACH PARTITION public.heartbeats_2024_04_user_id_language_time_idx;


--
-- Name: heartbeats_2024_04_user_id_operating_system_time_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_user_os_time ATTACH PARTITION public.heartbeats_2024_04_user_id_operating_system_time_idx;


--
-- Name: heartbeats_2024_04_user_id_project_time_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_user_project_time ATTACH PARTITION public.heartbeats_2024_04_user_id_project_time_idx;


--
-- Name: heartbeats_2024_04_user_id_time_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_user_time ATTACH PARTITION public.heartbeats_2024_04_user_id_time_idx;


--
-- Name: heartbeats_2024_05_fields_hash_time_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_fields_hash_uniq ATTACH PARTITION public.heartbeats_2024_05_fields_hash_time_idx;


--
-- Name: heartbeats_2024_05_ip_address_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_ip ATTACH PARTITION public.heartbeats_2024_05_ip_address_idx;


--
-- Name: heartbeats_2024_05_machine_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_machine ATTACH PARTITION public.heartbeats_2024_05_machine_idx;


--
-- Name: heartbeats_2024_05_time_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_current_hacking ATTACH PARTITION public.heartbeats_2024_05_time_idx;


--
-- Name: heartbeats_2024_05_user_id_category_time_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_user_category_time ATTACH PARTITION public.heartbeats_2024_05_user_id_category_time_idx;


--
-- Name: heartbeats_2024_05_user_id_editor_time_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_user_editor_time ATTACH PARTITION public.heartbeats_2024_05_user_id_editor_time_idx;


--
-- Name: heartbeats_2024_05_user_id_id_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_user_id_direct ATTACH PARTITION public.heartbeats_2024_05_user_id_id_idx;


--
-- Name: heartbeats_2024_05_user_id_id_idx1; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_user_ip_id ATTACH PARTITION public.heartbeats_2024_05_user_id_id_idx1;


--
-- Name: heartbeats_2024_05_user_id_language_time_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_user_language_time ATTACH PARTITION public.heartbeats_2024_05_user_id_language_time_idx;


--
-- Name: heartbeats_2024_05_user_id_operating_system_time_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_user_os_time ATTACH PARTITION public.heartbeats_2024_05_user_id_operating_system_time_idx;


--
-- Name: heartbeats_2024_05_user_id_project_time_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_user_project_time ATTACH PARTITION public.heartbeats_2024_05_user_id_project_time_idx;


--
-- Name: heartbeats_2024_05_user_id_time_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_user_time ATTACH PARTITION public.heartbeats_2024_05_user_id_time_idx;


--
-- Name: heartbeats_2024_06_fields_hash_time_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_fields_hash_uniq ATTACH PARTITION public.heartbeats_2024_06_fields_hash_time_idx;


--
-- Name: heartbeats_2024_06_ip_address_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_ip ATTACH PARTITION public.heartbeats_2024_06_ip_address_idx;


--
-- Name: heartbeats_2024_06_machine_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_machine ATTACH PARTITION public.heartbeats_2024_06_machine_idx;


--
-- Name: heartbeats_2024_06_time_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_current_hacking ATTACH PARTITION public.heartbeats_2024_06_time_idx;


--
-- Name: heartbeats_2024_06_user_id_category_time_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_user_category_time ATTACH PARTITION public.heartbeats_2024_06_user_id_category_time_idx;


--
-- Name: heartbeats_2024_06_user_id_editor_time_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_user_editor_time ATTACH PARTITION public.heartbeats_2024_06_user_id_editor_time_idx;


--
-- Name: heartbeats_2024_06_user_id_id_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_user_id_direct ATTACH PARTITION public.heartbeats_2024_06_user_id_id_idx;


--
-- Name: heartbeats_2024_06_user_id_id_idx1; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_user_ip_id ATTACH PARTITION public.heartbeats_2024_06_user_id_id_idx1;


--
-- Name: heartbeats_2024_06_user_id_language_time_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_user_language_time ATTACH PARTITION public.heartbeats_2024_06_user_id_language_time_idx;


--
-- Name: heartbeats_2024_06_user_id_operating_system_time_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_user_os_time ATTACH PARTITION public.heartbeats_2024_06_user_id_operating_system_time_idx;


--
-- Name: heartbeats_2024_06_user_id_project_time_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_user_project_time ATTACH PARTITION public.heartbeats_2024_06_user_id_project_time_idx;


--
-- Name: heartbeats_2024_06_user_id_time_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_user_time ATTACH PARTITION public.heartbeats_2024_06_user_id_time_idx;


--
-- Name: heartbeats_2024_07_fields_hash_time_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_fields_hash_uniq ATTACH PARTITION public.heartbeats_2024_07_fields_hash_time_idx;


--
-- Name: heartbeats_2024_07_ip_address_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_ip ATTACH PARTITION public.heartbeats_2024_07_ip_address_idx;


--
-- Name: heartbeats_2024_07_machine_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_machine ATTACH PARTITION public.heartbeats_2024_07_machine_idx;


--
-- Name: heartbeats_2024_07_time_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_current_hacking ATTACH PARTITION public.heartbeats_2024_07_time_idx;


--
-- Name: heartbeats_2024_07_user_id_category_time_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_user_category_time ATTACH PARTITION public.heartbeats_2024_07_user_id_category_time_idx;


--
-- Name: heartbeats_2024_07_user_id_editor_time_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_user_editor_time ATTACH PARTITION public.heartbeats_2024_07_user_id_editor_time_idx;


--
-- Name: heartbeats_2024_07_user_id_id_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_user_id_direct ATTACH PARTITION public.heartbeats_2024_07_user_id_id_idx;


--
-- Name: heartbeats_2024_07_user_id_id_idx1; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_user_ip_id ATTACH PARTITION public.heartbeats_2024_07_user_id_id_idx1;


--
-- Name: heartbeats_2024_07_user_id_language_time_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_user_language_time ATTACH PARTITION public.heartbeats_2024_07_user_id_language_time_idx;


--
-- Name: heartbeats_2024_07_user_id_operating_system_time_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_user_os_time ATTACH PARTITION public.heartbeats_2024_07_user_id_operating_system_time_idx;


--
-- Name: heartbeats_2024_07_user_id_project_time_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_user_project_time ATTACH PARTITION public.heartbeats_2024_07_user_id_project_time_idx;


--
-- Name: heartbeats_2024_07_user_id_time_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_user_time ATTACH PARTITION public.heartbeats_2024_07_user_id_time_idx;


--
-- Name: heartbeats_2024_08_fields_hash_time_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_fields_hash_uniq ATTACH PARTITION public.heartbeats_2024_08_fields_hash_time_idx;


--
-- Name: heartbeats_2024_08_ip_address_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_ip ATTACH PARTITION public.heartbeats_2024_08_ip_address_idx;


--
-- Name: heartbeats_2024_08_machine_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_machine ATTACH PARTITION public.heartbeats_2024_08_machine_idx;


--
-- Name: heartbeats_2024_08_time_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_current_hacking ATTACH PARTITION public.heartbeats_2024_08_time_idx;


--
-- Name: heartbeats_2024_08_user_id_category_time_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_user_category_time ATTACH PARTITION public.heartbeats_2024_08_user_id_category_time_idx;


--
-- Name: heartbeats_2024_08_user_id_editor_time_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_user_editor_time ATTACH PARTITION public.heartbeats_2024_08_user_id_editor_time_idx;


--
-- Name: heartbeats_2024_08_user_id_id_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_user_id_direct ATTACH PARTITION public.heartbeats_2024_08_user_id_id_idx;


--
-- Name: heartbeats_2024_08_user_id_id_idx1; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_user_ip_id ATTACH PARTITION public.heartbeats_2024_08_user_id_id_idx1;


--
-- Name: heartbeats_2024_08_user_id_language_time_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_user_language_time ATTACH PARTITION public.heartbeats_2024_08_user_id_language_time_idx;


--
-- Name: heartbeats_2024_08_user_id_operating_system_time_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_user_os_time ATTACH PARTITION public.heartbeats_2024_08_user_id_operating_system_time_idx;


--
-- Name: heartbeats_2024_08_user_id_project_time_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_user_project_time ATTACH PARTITION public.heartbeats_2024_08_user_id_project_time_idx;


--
-- Name: heartbeats_2024_08_user_id_time_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_user_time ATTACH PARTITION public.heartbeats_2024_08_user_id_time_idx;


--
-- Name: heartbeats_2024_09_fields_hash_time_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_fields_hash_uniq ATTACH PARTITION public.heartbeats_2024_09_fields_hash_time_idx;


--
-- Name: heartbeats_2024_09_ip_address_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_ip ATTACH PARTITION public.heartbeats_2024_09_ip_address_idx;


--
-- Name: heartbeats_2024_09_machine_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_machine ATTACH PARTITION public.heartbeats_2024_09_machine_idx;


--
-- Name: heartbeats_2024_09_time_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_current_hacking ATTACH PARTITION public.heartbeats_2024_09_time_idx;


--
-- Name: heartbeats_2024_09_user_id_category_time_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_user_category_time ATTACH PARTITION public.heartbeats_2024_09_user_id_category_time_idx;


--
-- Name: heartbeats_2024_09_user_id_editor_time_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_user_editor_time ATTACH PARTITION public.heartbeats_2024_09_user_id_editor_time_idx;


--
-- Name: heartbeats_2024_09_user_id_id_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_user_id_direct ATTACH PARTITION public.heartbeats_2024_09_user_id_id_idx;


--
-- Name: heartbeats_2024_09_user_id_id_idx1; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_user_ip_id ATTACH PARTITION public.heartbeats_2024_09_user_id_id_idx1;


--
-- Name: heartbeats_2024_09_user_id_language_time_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_user_language_time ATTACH PARTITION public.heartbeats_2024_09_user_id_language_time_idx;


--
-- Name: heartbeats_2024_09_user_id_operating_system_time_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_user_os_time ATTACH PARTITION public.heartbeats_2024_09_user_id_operating_system_time_idx;


--
-- Name: heartbeats_2024_09_user_id_project_time_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_user_project_time ATTACH PARTITION public.heartbeats_2024_09_user_id_project_time_idx;


--
-- Name: heartbeats_2024_09_user_id_time_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_user_time ATTACH PARTITION public.heartbeats_2024_09_user_id_time_idx;


--
-- Name: heartbeats_2024_10_fields_hash_time_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_fields_hash_uniq ATTACH PARTITION public.heartbeats_2024_10_fields_hash_time_idx;


--
-- Name: heartbeats_2024_10_ip_address_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_ip ATTACH PARTITION public.heartbeats_2024_10_ip_address_idx;


--
-- Name: heartbeats_2024_10_machine_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_machine ATTACH PARTITION public.heartbeats_2024_10_machine_idx;


--
-- Name: heartbeats_2024_10_time_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_current_hacking ATTACH PARTITION public.heartbeats_2024_10_time_idx;


--
-- Name: heartbeats_2024_10_user_id_category_time_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_user_category_time ATTACH PARTITION public.heartbeats_2024_10_user_id_category_time_idx;


--
-- Name: heartbeats_2024_10_user_id_editor_time_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_user_editor_time ATTACH PARTITION public.heartbeats_2024_10_user_id_editor_time_idx;


--
-- Name: heartbeats_2024_10_user_id_id_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_user_id_direct ATTACH PARTITION public.heartbeats_2024_10_user_id_id_idx;


--
-- Name: heartbeats_2024_10_user_id_id_idx1; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_user_ip_id ATTACH PARTITION public.heartbeats_2024_10_user_id_id_idx1;


--
-- Name: heartbeats_2024_10_user_id_language_time_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_user_language_time ATTACH PARTITION public.heartbeats_2024_10_user_id_language_time_idx;


--
-- Name: heartbeats_2024_10_user_id_operating_system_time_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_user_os_time ATTACH PARTITION public.heartbeats_2024_10_user_id_operating_system_time_idx;


--
-- Name: heartbeats_2024_10_user_id_project_time_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_user_project_time ATTACH PARTITION public.heartbeats_2024_10_user_id_project_time_idx;


--
-- Name: heartbeats_2024_10_user_id_time_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_user_time ATTACH PARTITION public.heartbeats_2024_10_user_id_time_idx;


--
-- Name: heartbeats_2024_11_fields_hash_time_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_fields_hash_uniq ATTACH PARTITION public.heartbeats_2024_11_fields_hash_time_idx;


--
-- Name: heartbeats_2024_11_ip_address_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_ip ATTACH PARTITION public.heartbeats_2024_11_ip_address_idx;


--
-- Name: heartbeats_2024_11_machine_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_machine ATTACH PARTITION public.heartbeats_2024_11_machine_idx;


--
-- Name: heartbeats_2024_11_time_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_current_hacking ATTACH PARTITION public.heartbeats_2024_11_time_idx;


--
-- Name: heartbeats_2024_11_user_id_category_time_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_user_category_time ATTACH PARTITION public.heartbeats_2024_11_user_id_category_time_idx;


--
-- Name: heartbeats_2024_11_user_id_editor_time_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_user_editor_time ATTACH PARTITION public.heartbeats_2024_11_user_id_editor_time_idx;


--
-- Name: heartbeats_2024_11_user_id_id_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_user_id_direct ATTACH PARTITION public.heartbeats_2024_11_user_id_id_idx;


--
-- Name: heartbeats_2024_11_user_id_id_idx1; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_user_ip_id ATTACH PARTITION public.heartbeats_2024_11_user_id_id_idx1;


--
-- Name: heartbeats_2024_11_user_id_language_time_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_user_language_time ATTACH PARTITION public.heartbeats_2024_11_user_id_language_time_idx;


--
-- Name: heartbeats_2024_11_user_id_operating_system_time_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_user_os_time ATTACH PARTITION public.heartbeats_2024_11_user_id_operating_system_time_idx;


--
-- Name: heartbeats_2024_11_user_id_project_time_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_user_project_time ATTACH PARTITION public.heartbeats_2024_11_user_id_project_time_idx;


--
-- Name: heartbeats_2024_11_user_id_time_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_user_time ATTACH PARTITION public.heartbeats_2024_11_user_id_time_idx;


--
-- Name: heartbeats_2024_12_fields_hash_time_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_fields_hash_uniq ATTACH PARTITION public.heartbeats_2024_12_fields_hash_time_idx;


--
-- Name: heartbeats_2024_12_ip_address_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_ip ATTACH PARTITION public.heartbeats_2024_12_ip_address_idx;


--
-- Name: heartbeats_2024_12_machine_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_machine ATTACH PARTITION public.heartbeats_2024_12_machine_idx;


--
-- Name: heartbeats_2024_12_time_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_current_hacking ATTACH PARTITION public.heartbeats_2024_12_time_idx;


--
-- Name: heartbeats_2024_12_user_id_category_time_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_user_category_time ATTACH PARTITION public.heartbeats_2024_12_user_id_category_time_idx;


--
-- Name: heartbeats_2024_12_user_id_editor_time_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_user_editor_time ATTACH PARTITION public.heartbeats_2024_12_user_id_editor_time_idx;


--
-- Name: heartbeats_2024_12_user_id_id_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_user_id_direct ATTACH PARTITION public.heartbeats_2024_12_user_id_id_idx;


--
-- Name: heartbeats_2024_12_user_id_id_idx1; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_user_ip_id ATTACH PARTITION public.heartbeats_2024_12_user_id_id_idx1;


--
-- Name: heartbeats_2024_12_user_id_language_time_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_user_language_time ATTACH PARTITION public.heartbeats_2024_12_user_id_language_time_idx;


--
-- Name: heartbeats_2024_12_user_id_operating_system_time_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_user_os_time ATTACH PARTITION public.heartbeats_2024_12_user_id_operating_system_time_idx;


--
-- Name: heartbeats_2024_12_user_id_project_time_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_user_project_time ATTACH PARTITION public.heartbeats_2024_12_user_id_project_time_idx;


--
-- Name: heartbeats_2024_12_user_id_time_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_user_time ATTACH PARTITION public.heartbeats_2024_12_user_id_time_idx;


--
-- Name: heartbeats_2025_01_fields_hash_time_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_fields_hash_uniq ATTACH PARTITION public.heartbeats_2025_01_fields_hash_time_idx;


--
-- Name: heartbeats_2025_01_ip_address_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_ip ATTACH PARTITION public.heartbeats_2025_01_ip_address_idx;


--
-- Name: heartbeats_2025_01_machine_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_machine ATTACH PARTITION public.heartbeats_2025_01_machine_idx;


--
-- Name: heartbeats_2025_01_time_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_current_hacking ATTACH PARTITION public.heartbeats_2025_01_time_idx;


--
-- Name: heartbeats_2025_01_user_id_category_time_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_user_category_time ATTACH PARTITION public.heartbeats_2025_01_user_id_category_time_idx;


--
-- Name: heartbeats_2025_01_user_id_editor_time_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_user_editor_time ATTACH PARTITION public.heartbeats_2025_01_user_id_editor_time_idx;


--
-- Name: heartbeats_2025_01_user_id_id_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_user_id_direct ATTACH PARTITION public.heartbeats_2025_01_user_id_id_idx;


--
-- Name: heartbeats_2025_01_user_id_id_idx1; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_user_ip_id ATTACH PARTITION public.heartbeats_2025_01_user_id_id_idx1;


--
-- Name: heartbeats_2025_01_user_id_language_time_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_user_language_time ATTACH PARTITION public.heartbeats_2025_01_user_id_language_time_idx;


--
-- Name: heartbeats_2025_01_user_id_operating_system_time_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_user_os_time ATTACH PARTITION public.heartbeats_2025_01_user_id_operating_system_time_idx;


--
-- Name: heartbeats_2025_01_user_id_project_time_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_user_project_time ATTACH PARTITION public.heartbeats_2025_01_user_id_project_time_idx;


--
-- Name: heartbeats_2025_01_user_id_time_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_user_time ATTACH PARTITION public.heartbeats_2025_01_user_id_time_idx;


--
-- Name: heartbeats_2025_02_fields_hash_time_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_fields_hash_uniq ATTACH PARTITION public.heartbeats_2025_02_fields_hash_time_idx;


--
-- Name: heartbeats_2025_02_ip_address_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_ip ATTACH PARTITION public.heartbeats_2025_02_ip_address_idx;


--
-- Name: heartbeats_2025_02_machine_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_machine ATTACH PARTITION public.heartbeats_2025_02_machine_idx;


--
-- Name: heartbeats_2025_02_time_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_current_hacking ATTACH PARTITION public.heartbeats_2025_02_time_idx;


--
-- Name: heartbeats_2025_02_user_id_category_time_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_user_category_time ATTACH PARTITION public.heartbeats_2025_02_user_id_category_time_idx;


--
-- Name: heartbeats_2025_02_user_id_editor_time_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_user_editor_time ATTACH PARTITION public.heartbeats_2025_02_user_id_editor_time_idx;


--
-- Name: heartbeats_2025_02_user_id_id_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_user_id_direct ATTACH PARTITION public.heartbeats_2025_02_user_id_id_idx;


--
-- Name: heartbeats_2025_02_user_id_id_idx1; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_user_ip_id ATTACH PARTITION public.heartbeats_2025_02_user_id_id_idx1;


--
-- Name: heartbeats_2025_02_user_id_language_time_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_user_language_time ATTACH PARTITION public.heartbeats_2025_02_user_id_language_time_idx;


--
-- Name: heartbeats_2025_02_user_id_operating_system_time_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_user_os_time ATTACH PARTITION public.heartbeats_2025_02_user_id_operating_system_time_idx;


--
-- Name: heartbeats_2025_02_user_id_project_time_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_user_project_time ATTACH PARTITION public.heartbeats_2025_02_user_id_project_time_idx;


--
-- Name: heartbeats_2025_02_user_id_time_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_user_time ATTACH PARTITION public.heartbeats_2025_02_user_id_time_idx;


--
-- Name: heartbeats_2025_03_fields_hash_time_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_fields_hash_uniq ATTACH PARTITION public.heartbeats_2025_03_fields_hash_time_idx;


--
-- Name: heartbeats_2025_03_ip_address_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_ip ATTACH PARTITION public.heartbeats_2025_03_ip_address_idx;


--
-- Name: heartbeats_2025_03_machine_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_machine ATTACH PARTITION public.heartbeats_2025_03_machine_idx;


--
-- Name: heartbeats_2025_03_time_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_current_hacking ATTACH PARTITION public.heartbeats_2025_03_time_idx;


--
-- Name: heartbeats_2025_03_user_id_category_time_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_user_category_time ATTACH PARTITION public.heartbeats_2025_03_user_id_category_time_idx;


--
-- Name: heartbeats_2025_03_user_id_editor_time_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_user_editor_time ATTACH PARTITION public.heartbeats_2025_03_user_id_editor_time_idx;


--
-- Name: heartbeats_2025_03_user_id_id_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_user_id_direct ATTACH PARTITION public.heartbeats_2025_03_user_id_id_idx;


--
-- Name: heartbeats_2025_03_user_id_id_idx1; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_user_ip_id ATTACH PARTITION public.heartbeats_2025_03_user_id_id_idx1;


--
-- Name: heartbeats_2025_03_user_id_language_time_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_user_language_time ATTACH PARTITION public.heartbeats_2025_03_user_id_language_time_idx;


--
-- Name: heartbeats_2025_03_user_id_operating_system_time_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_user_os_time ATTACH PARTITION public.heartbeats_2025_03_user_id_operating_system_time_idx;


--
-- Name: heartbeats_2025_03_user_id_project_time_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_user_project_time ATTACH PARTITION public.heartbeats_2025_03_user_id_project_time_idx;


--
-- Name: heartbeats_2025_03_user_id_time_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_user_time ATTACH PARTITION public.heartbeats_2025_03_user_id_time_idx;


--
-- Name: heartbeats_2025_04_fields_hash_time_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_fields_hash_uniq ATTACH PARTITION public.heartbeats_2025_04_fields_hash_time_idx;


--
-- Name: heartbeats_2025_04_ip_address_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_ip ATTACH PARTITION public.heartbeats_2025_04_ip_address_idx;


--
-- Name: heartbeats_2025_04_machine_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_machine ATTACH PARTITION public.heartbeats_2025_04_machine_idx;


--
-- Name: heartbeats_2025_04_time_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_current_hacking ATTACH PARTITION public.heartbeats_2025_04_time_idx;


--
-- Name: heartbeats_2025_04_user_id_category_time_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_user_category_time ATTACH PARTITION public.heartbeats_2025_04_user_id_category_time_idx;


--
-- Name: heartbeats_2025_04_user_id_editor_time_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_user_editor_time ATTACH PARTITION public.heartbeats_2025_04_user_id_editor_time_idx;


--
-- Name: heartbeats_2025_04_user_id_id_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_user_id_direct ATTACH PARTITION public.heartbeats_2025_04_user_id_id_idx;


--
-- Name: heartbeats_2025_04_user_id_id_idx1; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_user_ip_id ATTACH PARTITION public.heartbeats_2025_04_user_id_id_idx1;


--
-- Name: heartbeats_2025_04_user_id_language_time_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_user_language_time ATTACH PARTITION public.heartbeats_2025_04_user_id_language_time_idx;


--
-- Name: heartbeats_2025_04_user_id_operating_system_time_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_user_os_time ATTACH PARTITION public.heartbeats_2025_04_user_id_operating_system_time_idx;


--
-- Name: heartbeats_2025_04_user_id_project_time_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_user_project_time ATTACH PARTITION public.heartbeats_2025_04_user_id_project_time_idx;


--
-- Name: heartbeats_2025_04_user_id_time_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_user_time ATTACH PARTITION public.heartbeats_2025_04_user_id_time_idx;


--
-- Name: heartbeats_2025_05_fields_hash_time_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_fields_hash_uniq ATTACH PARTITION public.heartbeats_2025_05_fields_hash_time_idx;


--
-- Name: heartbeats_2025_05_ip_address_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_ip ATTACH PARTITION public.heartbeats_2025_05_ip_address_idx;


--
-- Name: heartbeats_2025_05_machine_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_machine ATTACH PARTITION public.heartbeats_2025_05_machine_idx;


--
-- Name: heartbeats_2025_05_time_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_current_hacking ATTACH PARTITION public.heartbeats_2025_05_time_idx;


--
-- Name: heartbeats_2025_05_user_id_category_time_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_user_category_time ATTACH PARTITION public.heartbeats_2025_05_user_id_category_time_idx;


--
-- Name: heartbeats_2025_05_user_id_editor_time_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_user_editor_time ATTACH PARTITION public.heartbeats_2025_05_user_id_editor_time_idx;


--
-- Name: heartbeats_2025_05_user_id_id_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_user_id_direct ATTACH PARTITION public.heartbeats_2025_05_user_id_id_idx;


--
-- Name: heartbeats_2025_05_user_id_id_idx1; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_user_ip_id ATTACH PARTITION public.heartbeats_2025_05_user_id_id_idx1;


--
-- Name: heartbeats_2025_05_user_id_language_time_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_user_language_time ATTACH PARTITION public.heartbeats_2025_05_user_id_language_time_idx;


--
-- Name: heartbeats_2025_05_user_id_operating_system_time_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_user_os_time ATTACH PARTITION public.heartbeats_2025_05_user_id_operating_system_time_idx;


--
-- Name: heartbeats_2025_05_user_id_project_time_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_user_project_time ATTACH PARTITION public.heartbeats_2025_05_user_id_project_time_idx;


--
-- Name: heartbeats_2025_05_user_id_time_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_user_time ATTACH PARTITION public.heartbeats_2025_05_user_id_time_idx;


--
-- Name: heartbeats_2025_06_fields_hash_time_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_fields_hash_uniq ATTACH PARTITION public.heartbeats_2025_06_fields_hash_time_idx;


--
-- Name: heartbeats_2025_06_ip_address_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_ip ATTACH PARTITION public.heartbeats_2025_06_ip_address_idx;


--
-- Name: heartbeats_2025_06_machine_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_machine ATTACH PARTITION public.heartbeats_2025_06_machine_idx;


--
-- Name: heartbeats_2025_06_time_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_current_hacking ATTACH PARTITION public.heartbeats_2025_06_time_idx;


--
-- Name: heartbeats_2025_06_user_id_category_time_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_user_category_time ATTACH PARTITION public.heartbeats_2025_06_user_id_category_time_idx;


--
-- Name: heartbeats_2025_06_user_id_editor_time_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_user_editor_time ATTACH PARTITION public.heartbeats_2025_06_user_id_editor_time_idx;


--
-- Name: heartbeats_2025_06_user_id_id_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_user_id_direct ATTACH PARTITION public.heartbeats_2025_06_user_id_id_idx;


--
-- Name: heartbeats_2025_06_user_id_id_idx1; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_user_ip_id ATTACH PARTITION public.heartbeats_2025_06_user_id_id_idx1;


--
-- Name: heartbeats_2025_06_user_id_language_time_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_user_language_time ATTACH PARTITION public.heartbeats_2025_06_user_id_language_time_idx;


--
-- Name: heartbeats_2025_06_user_id_operating_system_time_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_user_os_time ATTACH PARTITION public.heartbeats_2025_06_user_id_operating_system_time_idx;


--
-- Name: heartbeats_2025_06_user_id_project_time_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_user_project_time ATTACH PARTITION public.heartbeats_2025_06_user_id_project_time_idx;


--
-- Name: heartbeats_2025_06_user_id_time_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_user_time ATTACH PARTITION public.heartbeats_2025_06_user_id_time_idx;


--
-- Name: heartbeats_2025_07_fields_hash_time_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_fields_hash_uniq ATTACH PARTITION public.heartbeats_2025_07_fields_hash_time_idx;


--
-- Name: heartbeats_2025_07_ip_address_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_ip ATTACH PARTITION public.heartbeats_2025_07_ip_address_idx;


--
-- Name: heartbeats_2025_07_machine_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_machine ATTACH PARTITION public.heartbeats_2025_07_machine_idx;


--
-- Name: heartbeats_2025_07_time_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_current_hacking ATTACH PARTITION public.heartbeats_2025_07_time_idx;


--
-- Name: heartbeats_2025_07_user_id_category_time_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_user_category_time ATTACH PARTITION public.heartbeats_2025_07_user_id_category_time_idx;


--
-- Name: heartbeats_2025_07_user_id_editor_time_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_user_editor_time ATTACH PARTITION public.heartbeats_2025_07_user_id_editor_time_idx;


--
-- Name: heartbeats_2025_07_user_id_id_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_user_id_direct ATTACH PARTITION public.heartbeats_2025_07_user_id_id_idx;


--
-- Name: heartbeats_2025_07_user_id_id_idx1; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_user_ip_id ATTACH PARTITION public.heartbeats_2025_07_user_id_id_idx1;


--
-- Name: heartbeats_2025_07_user_id_language_time_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_user_language_time ATTACH PARTITION public.heartbeats_2025_07_user_id_language_time_idx;


--
-- Name: heartbeats_2025_07_user_id_operating_system_time_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_user_os_time ATTACH PARTITION public.heartbeats_2025_07_user_id_operating_system_time_idx;


--
-- Name: heartbeats_2025_07_user_id_project_time_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_user_project_time ATTACH PARTITION public.heartbeats_2025_07_user_id_project_time_idx;


--
-- Name: heartbeats_2025_07_user_id_time_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_user_time ATTACH PARTITION public.heartbeats_2025_07_user_id_time_idx;


--
-- Name: heartbeats_2025_08_fields_hash_time_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_fields_hash_uniq ATTACH PARTITION public.heartbeats_2025_08_fields_hash_time_idx;


--
-- Name: heartbeats_2025_08_ip_address_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_ip ATTACH PARTITION public.heartbeats_2025_08_ip_address_idx;


--
-- Name: heartbeats_2025_08_machine_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_machine ATTACH PARTITION public.heartbeats_2025_08_machine_idx;


--
-- Name: heartbeats_2025_08_time_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_current_hacking ATTACH PARTITION public.heartbeats_2025_08_time_idx;


--
-- Name: heartbeats_2025_08_user_id_category_time_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_user_category_time ATTACH PARTITION public.heartbeats_2025_08_user_id_category_time_idx;


--
-- Name: heartbeats_2025_08_user_id_editor_time_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_user_editor_time ATTACH PARTITION public.heartbeats_2025_08_user_id_editor_time_idx;


--
-- Name: heartbeats_2025_08_user_id_id_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_user_id_direct ATTACH PARTITION public.heartbeats_2025_08_user_id_id_idx;


--
-- Name: heartbeats_2025_08_user_id_id_idx1; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_user_ip_id ATTACH PARTITION public.heartbeats_2025_08_user_id_id_idx1;


--
-- Name: heartbeats_2025_08_user_id_language_time_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_user_language_time ATTACH PARTITION public.heartbeats_2025_08_user_id_language_time_idx;


--
-- Name: heartbeats_2025_08_user_id_operating_system_time_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_user_os_time ATTACH PARTITION public.heartbeats_2025_08_user_id_operating_system_time_idx;


--
-- Name: heartbeats_2025_08_user_id_project_time_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_user_project_time ATTACH PARTITION public.heartbeats_2025_08_user_id_project_time_idx;


--
-- Name: heartbeats_2025_08_user_id_time_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_user_time ATTACH PARTITION public.heartbeats_2025_08_user_id_time_idx;


--
-- Name: heartbeats_2025_09_fields_hash_time_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_fields_hash_uniq ATTACH PARTITION public.heartbeats_2025_09_fields_hash_time_idx;


--
-- Name: heartbeats_2025_09_ip_address_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_ip ATTACH PARTITION public.heartbeats_2025_09_ip_address_idx;


--
-- Name: heartbeats_2025_09_machine_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_machine ATTACH PARTITION public.heartbeats_2025_09_machine_idx;


--
-- Name: heartbeats_2025_09_time_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_current_hacking ATTACH PARTITION public.heartbeats_2025_09_time_idx;


--
-- Name: heartbeats_2025_09_user_id_category_time_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_user_category_time ATTACH PARTITION public.heartbeats_2025_09_user_id_category_time_idx;


--
-- Name: heartbeats_2025_09_user_id_editor_time_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_user_editor_time ATTACH PARTITION public.heartbeats_2025_09_user_id_editor_time_idx;


--
-- Name: heartbeats_2025_09_user_id_id_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_user_id_direct ATTACH PARTITION public.heartbeats_2025_09_user_id_id_idx;


--
-- Name: heartbeats_2025_09_user_id_id_idx1; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_user_ip_id ATTACH PARTITION public.heartbeats_2025_09_user_id_id_idx1;


--
-- Name: heartbeats_2025_09_user_id_language_time_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_user_language_time ATTACH PARTITION public.heartbeats_2025_09_user_id_language_time_idx;


--
-- Name: heartbeats_2025_09_user_id_operating_system_time_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_user_os_time ATTACH PARTITION public.heartbeats_2025_09_user_id_operating_system_time_idx;


--
-- Name: heartbeats_2025_09_user_id_project_time_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_user_project_time ATTACH PARTITION public.heartbeats_2025_09_user_id_project_time_idx;


--
-- Name: heartbeats_2025_09_user_id_time_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_user_time ATTACH PARTITION public.heartbeats_2025_09_user_id_time_idx;


--
-- Name: heartbeats_2025_10_fields_hash_time_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_fields_hash_uniq ATTACH PARTITION public.heartbeats_2025_10_fields_hash_time_idx;


--
-- Name: heartbeats_2025_10_ip_address_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_ip ATTACH PARTITION public.heartbeats_2025_10_ip_address_idx;


--
-- Name: heartbeats_2025_10_machine_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_machine ATTACH PARTITION public.heartbeats_2025_10_machine_idx;


--
-- Name: heartbeats_2025_10_time_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_current_hacking ATTACH PARTITION public.heartbeats_2025_10_time_idx;


--
-- Name: heartbeats_2025_10_user_id_category_time_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_user_category_time ATTACH PARTITION public.heartbeats_2025_10_user_id_category_time_idx;


--
-- Name: heartbeats_2025_10_user_id_editor_time_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_user_editor_time ATTACH PARTITION public.heartbeats_2025_10_user_id_editor_time_idx;


--
-- Name: heartbeats_2025_10_user_id_id_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_user_id_direct ATTACH PARTITION public.heartbeats_2025_10_user_id_id_idx;


--
-- Name: heartbeats_2025_10_user_id_id_idx1; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_user_ip_id ATTACH PARTITION public.heartbeats_2025_10_user_id_id_idx1;


--
-- Name: heartbeats_2025_10_user_id_language_time_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_user_language_time ATTACH PARTITION public.heartbeats_2025_10_user_id_language_time_idx;


--
-- Name: heartbeats_2025_10_user_id_operating_system_time_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_user_os_time ATTACH PARTITION public.heartbeats_2025_10_user_id_operating_system_time_idx;


--
-- Name: heartbeats_2025_10_user_id_project_time_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_user_project_time ATTACH PARTITION public.heartbeats_2025_10_user_id_project_time_idx;


--
-- Name: heartbeats_2025_10_user_id_time_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_user_time ATTACH PARTITION public.heartbeats_2025_10_user_id_time_idx;


--
-- Name: heartbeats_2025_11_fields_hash_time_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_fields_hash_uniq ATTACH PARTITION public.heartbeats_2025_11_fields_hash_time_idx;


--
-- Name: heartbeats_2025_11_ip_address_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_ip ATTACH PARTITION public.heartbeats_2025_11_ip_address_idx;


--
-- Name: heartbeats_2025_11_machine_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_machine ATTACH PARTITION public.heartbeats_2025_11_machine_idx;


--
-- Name: heartbeats_2025_11_time_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_current_hacking ATTACH PARTITION public.heartbeats_2025_11_time_idx;


--
-- Name: heartbeats_2025_11_user_id_category_time_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_user_category_time ATTACH PARTITION public.heartbeats_2025_11_user_id_category_time_idx;


--
-- Name: heartbeats_2025_11_user_id_editor_time_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_user_editor_time ATTACH PARTITION public.heartbeats_2025_11_user_id_editor_time_idx;


--
-- Name: heartbeats_2025_11_user_id_id_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_user_id_direct ATTACH PARTITION public.heartbeats_2025_11_user_id_id_idx;


--
-- Name: heartbeats_2025_11_user_id_id_idx1; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_user_ip_id ATTACH PARTITION public.heartbeats_2025_11_user_id_id_idx1;


--
-- Name: heartbeats_2025_11_user_id_language_time_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_user_language_time ATTACH PARTITION public.heartbeats_2025_11_user_id_language_time_idx;


--
-- Name: heartbeats_2025_11_user_id_operating_system_time_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_user_os_time ATTACH PARTITION public.heartbeats_2025_11_user_id_operating_system_time_idx;


--
-- Name: heartbeats_2025_11_user_id_project_time_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_user_project_time ATTACH PARTITION public.heartbeats_2025_11_user_id_project_time_idx;


--
-- Name: heartbeats_2025_11_user_id_time_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_user_time ATTACH PARTITION public.heartbeats_2025_11_user_id_time_idx;


--
-- Name: heartbeats_2025_12_fields_hash_time_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_fields_hash_uniq ATTACH PARTITION public.heartbeats_2025_12_fields_hash_time_idx;


--
-- Name: heartbeats_2025_12_ip_address_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_ip ATTACH PARTITION public.heartbeats_2025_12_ip_address_idx;


--
-- Name: heartbeats_2025_12_machine_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_machine ATTACH PARTITION public.heartbeats_2025_12_machine_idx;


--
-- Name: heartbeats_2025_12_time_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_current_hacking ATTACH PARTITION public.heartbeats_2025_12_time_idx;


--
-- Name: heartbeats_2025_12_user_id_category_time_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_user_category_time ATTACH PARTITION public.heartbeats_2025_12_user_id_category_time_idx;


--
-- Name: heartbeats_2025_12_user_id_editor_time_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_user_editor_time ATTACH PARTITION public.heartbeats_2025_12_user_id_editor_time_idx;


--
-- Name: heartbeats_2025_12_user_id_id_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_user_id_direct ATTACH PARTITION public.heartbeats_2025_12_user_id_id_idx;


--
-- Name: heartbeats_2025_12_user_id_id_idx1; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_user_ip_id ATTACH PARTITION public.heartbeats_2025_12_user_id_id_idx1;


--
-- Name: heartbeats_2025_12_user_id_language_time_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_user_language_time ATTACH PARTITION public.heartbeats_2025_12_user_id_language_time_idx;


--
-- Name: heartbeats_2025_12_user_id_operating_system_time_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_user_os_time ATTACH PARTITION public.heartbeats_2025_12_user_id_operating_system_time_idx;


--
-- Name: heartbeats_2025_12_user_id_project_time_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_user_project_time ATTACH PARTITION public.heartbeats_2025_12_user_id_project_time_idx;


--
-- Name: heartbeats_2025_12_user_id_time_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_user_time ATTACH PARTITION public.heartbeats_2025_12_user_id_time_idx;


--
-- Name: heartbeats_2026_01_fields_hash_time_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_fields_hash_uniq ATTACH PARTITION public.heartbeats_2026_01_fields_hash_time_idx;


--
-- Name: heartbeats_2026_01_ip_address_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_ip ATTACH PARTITION public.heartbeats_2026_01_ip_address_idx;


--
-- Name: heartbeats_2026_01_machine_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_machine ATTACH PARTITION public.heartbeats_2026_01_machine_idx;


--
-- Name: heartbeats_2026_01_time_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_current_hacking ATTACH PARTITION public.heartbeats_2026_01_time_idx;


--
-- Name: heartbeats_2026_01_user_id_category_time_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_user_category_time ATTACH PARTITION public.heartbeats_2026_01_user_id_category_time_idx;


--
-- Name: heartbeats_2026_01_user_id_editor_time_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_user_editor_time ATTACH PARTITION public.heartbeats_2026_01_user_id_editor_time_idx;


--
-- Name: heartbeats_2026_01_user_id_id_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_user_id_direct ATTACH PARTITION public.heartbeats_2026_01_user_id_id_idx;


--
-- Name: heartbeats_2026_01_user_id_id_idx1; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_user_ip_id ATTACH PARTITION public.heartbeats_2026_01_user_id_id_idx1;


--
-- Name: heartbeats_2026_01_user_id_language_time_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_user_language_time ATTACH PARTITION public.heartbeats_2026_01_user_id_language_time_idx;


--
-- Name: heartbeats_2026_01_user_id_operating_system_time_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_user_os_time ATTACH PARTITION public.heartbeats_2026_01_user_id_operating_system_time_idx;


--
-- Name: heartbeats_2026_01_user_id_project_time_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_user_project_time ATTACH PARTITION public.heartbeats_2026_01_user_id_project_time_idx;


--
-- Name: heartbeats_2026_01_user_id_time_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_user_time ATTACH PARTITION public.heartbeats_2026_01_user_id_time_idx;


--
-- Name: heartbeats_2026_02_fields_hash_time_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_fields_hash_uniq ATTACH PARTITION public.heartbeats_2026_02_fields_hash_time_idx;


--
-- Name: heartbeats_2026_02_ip_address_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_ip ATTACH PARTITION public.heartbeats_2026_02_ip_address_idx;


--
-- Name: heartbeats_2026_02_machine_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_machine ATTACH PARTITION public.heartbeats_2026_02_machine_idx;


--
-- Name: heartbeats_2026_02_time_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_current_hacking ATTACH PARTITION public.heartbeats_2026_02_time_idx;


--
-- Name: heartbeats_2026_02_user_id_category_time_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_user_category_time ATTACH PARTITION public.heartbeats_2026_02_user_id_category_time_idx;


--
-- Name: heartbeats_2026_02_user_id_editor_time_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_user_editor_time ATTACH PARTITION public.heartbeats_2026_02_user_id_editor_time_idx;


--
-- Name: heartbeats_2026_02_user_id_id_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_user_id_direct ATTACH PARTITION public.heartbeats_2026_02_user_id_id_idx;


--
-- Name: heartbeats_2026_02_user_id_id_idx1; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_user_ip_id ATTACH PARTITION public.heartbeats_2026_02_user_id_id_idx1;


--
-- Name: heartbeats_2026_02_user_id_language_time_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_user_language_time ATTACH PARTITION public.heartbeats_2026_02_user_id_language_time_idx;


--
-- Name: heartbeats_2026_02_user_id_operating_system_time_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_user_os_time ATTACH PARTITION public.heartbeats_2026_02_user_id_operating_system_time_idx;


--
-- Name: heartbeats_2026_02_user_id_project_time_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_user_project_time ATTACH PARTITION public.heartbeats_2026_02_user_id_project_time_idx;


--
-- Name: heartbeats_2026_02_user_id_time_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_user_time ATTACH PARTITION public.heartbeats_2026_02_user_id_time_idx;


--
-- Name: heartbeats_2026_03_fields_hash_time_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_fields_hash_uniq ATTACH PARTITION public.heartbeats_2026_03_fields_hash_time_idx;


--
-- Name: heartbeats_2026_03_ip_address_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_ip ATTACH PARTITION public.heartbeats_2026_03_ip_address_idx;


--
-- Name: heartbeats_2026_03_machine_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_machine ATTACH PARTITION public.heartbeats_2026_03_machine_idx;


--
-- Name: heartbeats_2026_03_time_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_current_hacking ATTACH PARTITION public.heartbeats_2026_03_time_idx;


--
-- Name: heartbeats_2026_03_user_id_category_time_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_user_category_time ATTACH PARTITION public.heartbeats_2026_03_user_id_category_time_idx;


--
-- Name: heartbeats_2026_03_user_id_editor_time_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_user_editor_time ATTACH PARTITION public.heartbeats_2026_03_user_id_editor_time_idx;


--
-- Name: heartbeats_2026_03_user_id_id_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_user_id_direct ATTACH PARTITION public.heartbeats_2026_03_user_id_id_idx;


--
-- Name: heartbeats_2026_03_user_id_id_idx1; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_user_ip_id ATTACH PARTITION public.heartbeats_2026_03_user_id_id_idx1;


--
-- Name: heartbeats_2026_03_user_id_language_time_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_user_language_time ATTACH PARTITION public.heartbeats_2026_03_user_id_language_time_idx;


--
-- Name: heartbeats_2026_03_user_id_operating_system_time_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_user_os_time ATTACH PARTITION public.heartbeats_2026_03_user_id_operating_system_time_idx;


--
-- Name: heartbeats_2026_03_user_id_project_time_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_user_project_time ATTACH PARTITION public.heartbeats_2026_03_user_id_project_time_idx;


--
-- Name: heartbeats_2026_03_user_id_time_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_user_time ATTACH PARTITION public.heartbeats_2026_03_user_id_time_idx;


--
-- Name: heartbeats_2026_04_fields_hash_time_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_fields_hash_uniq ATTACH PARTITION public.heartbeats_2026_04_fields_hash_time_idx;


--
-- Name: heartbeats_2026_04_ip_address_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_ip ATTACH PARTITION public.heartbeats_2026_04_ip_address_idx;


--
-- Name: heartbeats_2026_04_machine_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_machine ATTACH PARTITION public.heartbeats_2026_04_machine_idx;


--
-- Name: heartbeats_2026_04_time_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_current_hacking ATTACH PARTITION public.heartbeats_2026_04_time_idx;


--
-- Name: heartbeats_2026_04_user_id_category_time_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_user_category_time ATTACH PARTITION public.heartbeats_2026_04_user_id_category_time_idx;


--
-- Name: heartbeats_2026_04_user_id_editor_time_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_user_editor_time ATTACH PARTITION public.heartbeats_2026_04_user_id_editor_time_idx;


--
-- Name: heartbeats_2026_04_user_id_id_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_user_id_direct ATTACH PARTITION public.heartbeats_2026_04_user_id_id_idx;


--
-- Name: heartbeats_2026_04_user_id_id_idx1; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_user_ip_id ATTACH PARTITION public.heartbeats_2026_04_user_id_id_idx1;


--
-- Name: heartbeats_2026_04_user_id_language_time_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_user_language_time ATTACH PARTITION public.heartbeats_2026_04_user_id_language_time_idx;


--
-- Name: heartbeats_2026_04_user_id_operating_system_time_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_user_os_time ATTACH PARTITION public.heartbeats_2026_04_user_id_operating_system_time_idx;


--
-- Name: heartbeats_2026_04_user_id_project_time_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_user_project_time ATTACH PARTITION public.heartbeats_2026_04_user_id_project_time_idx;


--
-- Name: heartbeats_2026_04_user_id_time_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_user_time ATTACH PARTITION public.heartbeats_2026_04_user_id_time_idx;


--
-- Name: heartbeats_2026_05_fields_hash_time_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_fields_hash_uniq ATTACH PARTITION public.heartbeats_2026_05_fields_hash_time_idx;


--
-- Name: heartbeats_2026_05_ip_address_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_ip ATTACH PARTITION public.heartbeats_2026_05_ip_address_idx;


--
-- Name: heartbeats_2026_05_machine_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_machine ATTACH PARTITION public.heartbeats_2026_05_machine_idx;


--
-- Name: heartbeats_2026_05_time_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_current_hacking ATTACH PARTITION public.heartbeats_2026_05_time_idx;


--
-- Name: heartbeats_2026_05_user_id_category_time_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_user_category_time ATTACH PARTITION public.heartbeats_2026_05_user_id_category_time_idx;


--
-- Name: heartbeats_2026_05_user_id_editor_time_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_user_editor_time ATTACH PARTITION public.heartbeats_2026_05_user_id_editor_time_idx;


--
-- Name: heartbeats_2026_05_user_id_id_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_user_id_direct ATTACH PARTITION public.heartbeats_2026_05_user_id_id_idx;


--
-- Name: heartbeats_2026_05_user_id_id_idx1; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_user_ip_id ATTACH PARTITION public.heartbeats_2026_05_user_id_id_idx1;


--
-- Name: heartbeats_2026_05_user_id_language_time_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_user_language_time ATTACH PARTITION public.heartbeats_2026_05_user_id_language_time_idx;


--
-- Name: heartbeats_2026_05_user_id_operating_system_time_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_user_os_time ATTACH PARTITION public.heartbeats_2026_05_user_id_operating_system_time_idx;


--
-- Name: heartbeats_2026_05_user_id_project_time_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_user_project_time ATTACH PARTITION public.heartbeats_2026_05_user_id_project_time_idx;


--
-- Name: heartbeats_2026_05_user_id_time_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_user_time ATTACH PARTITION public.heartbeats_2026_05_user_id_time_idx;


--
-- Name: heartbeats_2026_06_fields_hash_time_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_fields_hash_uniq ATTACH PARTITION public.heartbeats_2026_06_fields_hash_time_idx;


--
-- Name: heartbeats_2026_06_ip_address_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_ip ATTACH PARTITION public.heartbeats_2026_06_ip_address_idx;


--
-- Name: heartbeats_2026_06_machine_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_machine ATTACH PARTITION public.heartbeats_2026_06_machine_idx;


--
-- Name: heartbeats_2026_06_time_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_current_hacking ATTACH PARTITION public.heartbeats_2026_06_time_idx;


--
-- Name: heartbeats_2026_06_user_id_category_time_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_user_category_time ATTACH PARTITION public.heartbeats_2026_06_user_id_category_time_idx;


--
-- Name: heartbeats_2026_06_user_id_editor_time_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_user_editor_time ATTACH PARTITION public.heartbeats_2026_06_user_id_editor_time_idx;


--
-- Name: heartbeats_2026_06_user_id_id_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_user_id_direct ATTACH PARTITION public.heartbeats_2026_06_user_id_id_idx;


--
-- Name: heartbeats_2026_06_user_id_id_idx1; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_user_ip_id ATTACH PARTITION public.heartbeats_2026_06_user_id_id_idx1;


--
-- Name: heartbeats_2026_06_user_id_language_time_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_user_language_time ATTACH PARTITION public.heartbeats_2026_06_user_id_language_time_idx;


--
-- Name: heartbeats_2026_06_user_id_operating_system_time_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_user_os_time ATTACH PARTITION public.heartbeats_2026_06_user_id_operating_system_time_idx;


--
-- Name: heartbeats_2026_06_user_id_project_time_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_user_project_time ATTACH PARTITION public.heartbeats_2026_06_user_id_project_time_idx;


--
-- Name: heartbeats_2026_06_user_id_time_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_user_time ATTACH PARTITION public.heartbeats_2026_06_user_id_time_idx;


--
-- Name: heartbeats_2026_07_fields_hash_time_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_fields_hash_uniq ATTACH PARTITION public.heartbeats_2026_07_fields_hash_time_idx;


--
-- Name: heartbeats_2026_07_ip_address_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_ip ATTACH PARTITION public.heartbeats_2026_07_ip_address_idx;


--
-- Name: heartbeats_2026_07_machine_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_machine ATTACH PARTITION public.heartbeats_2026_07_machine_idx;


--
-- Name: heartbeats_2026_07_time_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_current_hacking ATTACH PARTITION public.heartbeats_2026_07_time_idx;


--
-- Name: heartbeats_2026_07_user_id_category_time_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_user_category_time ATTACH PARTITION public.heartbeats_2026_07_user_id_category_time_idx;


--
-- Name: heartbeats_2026_07_user_id_editor_time_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_user_editor_time ATTACH PARTITION public.heartbeats_2026_07_user_id_editor_time_idx;


--
-- Name: heartbeats_2026_07_user_id_id_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_user_id_direct ATTACH PARTITION public.heartbeats_2026_07_user_id_id_idx;


--
-- Name: heartbeats_2026_07_user_id_id_idx1; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_user_ip_id ATTACH PARTITION public.heartbeats_2026_07_user_id_id_idx1;


--
-- Name: heartbeats_2026_07_user_id_language_time_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_user_language_time ATTACH PARTITION public.heartbeats_2026_07_user_id_language_time_idx;


--
-- Name: heartbeats_2026_07_user_id_operating_system_time_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_user_os_time ATTACH PARTITION public.heartbeats_2026_07_user_id_operating_system_time_idx;


--
-- Name: heartbeats_2026_07_user_id_project_time_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_user_project_time ATTACH PARTITION public.heartbeats_2026_07_user_id_project_time_idx;


--
-- Name: heartbeats_2026_07_user_id_time_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_user_time ATTACH PARTITION public.heartbeats_2026_07_user_id_time_idx;


--
-- Name: heartbeats_before_2024_fields_hash_time_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_fields_hash_uniq ATTACH PARTITION public.heartbeats_before_2024_fields_hash_time_idx;


--
-- Name: heartbeats_before_2024_ip_address_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_ip ATTACH PARTITION public.heartbeats_before_2024_ip_address_idx;


--
-- Name: heartbeats_before_2024_machine_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_machine ATTACH PARTITION public.heartbeats_before_2024_machine_idx;


--
-- Name: heartbeats_before_2024_time_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_current_hacking ATTACH PARTITION public.heartbeats_before_2024_time_idx;


--
-- Name: heartbeats_before_2024_user_id_category_time_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_user_category_time ATTACH PARTITION public.heartbeats_before_2024_user_id_category_time_idx;


--
-- Name: heartbeats_before_2024_user_id_editor_time_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_user_editor_time ATTACH PARTITION public.heartbeats_before_2024_user_id_editor_time_idx;


--
-- Name: heartbeats_before_2024_user_id_id_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_user_id_direct ATTACH PARTITION public.heartbeats_before_2024_user_id_id_idx;


--
-- Name: heartbeats_before_2024_user_id_id_idx1; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_user_ip_id ATTACH PARTITION public.heartbeats_before_2024_user_id_id_idx1;


--
-- Name: heartbeats_before_2024_user_id_language_time_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_user_language_time ATTACH PARTITION public.heartbeats_before_2024_user_id_language_time_idx;


--
-- Name: heartbeats_before_2024_user_id_operating_system_time_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_user_os_time ATTACH PARTITION public.heartbeats_before_2024_user_id_operating_system_time_idx;


--
-- Name: heartbeats_before_2024_user_id_project_time_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_user_project_time ATTACH PARTITION public.heartbeats_before_2024_user_id_project_time_idx;


--
-- Name: heartbeats_before_2024_user_id_time_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_user_time ATTACH PARTITION public.heartbeats_before_2024_user_id_time_idx;


--
-- Name: heartbeats_default_fields_hash_time_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_fields_hash_uniq ATTACH PARTITION public.heartbeats_default_fields_hash_time_idx;


--
-- Name: heartbeats_default_ip_address_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_ip ATTACH PARTITION public.heartbeats_default_ip_address_idx;


--
-- Name: heartbeats_default_machine_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_machine ATTACH PARTITION public.heartbeats_default_machine_idx;


--
-- Name: heartbeats_default_time_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_current_hacking ATTACH PARTITION public.heartbeats_default_time_idx;


--
-- Name: heartbeats_default_user_id_category_time_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_user_category_time ATTACH PARTITION public.heartbeats_default_user_id_category_time_idx;


--
-- Name: heartbeats_default_user_id_editor_time_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_user_editor_time ATTACH PARTITION public.heartbeats_default_user_id_editor_time_idx;


--
-- Name: heartbeats_default_user_id_id_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_user_id_direct ATTACH PARTITION public.heartbeats_default_user_id_id_idx;


--
-- Name: heartbeats_default_user_id_id_idx1; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_user_ip_id ATTACH PARTITION public.heartbeats_default_user_id_id_idx1;


--
-- Name: heartbeats_default_user_id_language_time_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_user_language_time ATTACH PARTITION public.heartbeats_default_user_id_language_time_idx;


--
-- Name: heartbeats_default_user_id_operating_system_time_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_user_os_time ATTACH PARTITION public.heartbeats_default_user_id_operating_system_time_idx;


--
-- Name: heartbeats_default_user_id_project_time_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_user_project_time ATTACH PARTITION public.heartbeats_default_user_id_project_time_idx;


--
-- Name: heartbeats_default_user_id_time_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.idx_heartbeats_part_user_time ATTACH PARTITION public.heartbeats_default_user_id_time_idx;


--
-- Name: deletion_requests fk_rails_0aa4839f87; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.deletion_requests
    ADD CONSTRAINT fk_rails_0aa4839f87 FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: leaderboard_entries fk_rails_1620868c64; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.leaderboard_entries
    ADD CONSTRAINT fk_rails_1620868c64 FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: trust_level_audit_logs fk_rails_202efc347d; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.trust_level_audit_logs
    ADD CONSTRAINT fk_rails_202efc347d FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: api_keys fk_rails_32c28d0dc2; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.api_keys
    ADD CONSTRAINT fk_rails_32c28d0dc2 FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: oauth_access_grants fk_rails_330c32d8d9; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.oauth_access_grants
    ADD CONSTRAINT fk_rails_330c32d8d9 FOREIGN KEY (resource_owner_id) REFERENCES public.users(id);


--
-- Name: commits fk_rails_409a66d7e3; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.commits
    ADD CONSTRAINT fk_rails_409a66d7e3 FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: repo_host_events fk_rails_5d4e3eae11; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.repo_host_events
    ADD CONSTRAINT fk_rails_5d4e3eae11 FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: heartbeat_projects fk_rails_62e3e57ba1; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.heartbeat_projects
    ADD CONSTRAINT fk_rails_62e3e57ba1 FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: email_verification_requests fk_rails_64ad1fa810; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.email_verification_requests
    ADD CONSTRAINT fk_rails_64ad1fa810 FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: oauth_access_tokens fk_rails_732cb83ab7; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.oauth_access_tokens
    ADD CONSTRAINT fk_rails_732cb83ab7 FOREIGN KEY (application_id) REFERENCES public.oauth_applications(id);


--
-- Name: project_repo_mappings fk_rails_7ff6743abb; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.project_repo_mappings
    ADD CONSTRAINT fk_rails_7ff6743abb FOREIGN KEY (repository_id) REFERENCES public.repositories(id);


--
-- Name: active_storage_variant_records fk_rails_993965df05; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.active_storage_variant_records
    ADD CONSTRAINT fk_rails_993965df05 FOREIGN KEY (blob_id) REFERENCES public.active_storage_blobs(id);


--
-- Name: commits fk_rails_a8299bc69b; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.commits
    ADD CONSTRAINT fk_rails_a8299bc69b FOREIGN KEY (repository_id) REFERENCES public.repositories(id);


--
-- Name: sign_in_tokens fk_rails_a9860dd74e; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sign_in_tokens
    ADD CONSTRAINT fk_rails_a9860dd74e FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: deletion_requests fk_rails_adddd9e8ef; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.deletion_requests
    ADD CONSTRAINT fk_rails_adddd9e8ef FOREIGN KEY (admin_approved_by_id) REFERENCES public.users(id);


--
-- Name: project_repo_mappings fk_rails_aee8f6ca5b; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.project_repo_mappings
    ADD CONSTRAINT fk_rails_aee8f6ca5b FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: oauth_access_grants fk_rails_b4b53e07b8; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.oauth_access_grants
    ADD CONSTRAINT fk_rails_b4b53e07b8 FOREIGN KEY (application_id) REFERENCES public.oauth_applications(id);


--
-- Name: trust_level_audit_logs fk_rails_b8bf9dd115; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.trust_level_audit_logs
    ADD CONSTRAINT fk_rails_b8bf9dd115 FOREIGN KEY (changed_by_id) REFERENCES public.users(id);


--
-- Name: active_storage_attachments fk_rails_c3b3935057; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.active_storage_attachments
    ADD CONSTRAINT fk_rails_c3b3935057 FOREIGN KEY (blob_id) REFERENCES public.active_storage_blobs(id);


--
-- Name: goals fk_rails_c5fd9c8a38; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.goals
    ADD CONSTRAINT fk_rails_c5fd9c8a38 FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: email_addresses fk_rails_de643267e7; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.email_addresses
    ADD CONSTRAINT fk_rails_de643267e7 FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: heartbeat_import_sources fk_rails_e731e6a5ad; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.heartbeat_import_sources
    ADD CONSTRAINT fk_rails_e731e6a5ad FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: heartbeat_machines fk_rails_e7cba2a923; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.heartbeat_machines
    ADD CONSTRAINT fk_rails_e7cba2a923 FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: oauth_access_tokens fk_rails_ee63f25419; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.oauth_access_tokens
    ADD CONSTRAINT fk_rails_ee63f25419 FOREIGN KEY (resource_owner_id) REFERENCES public.users(id);


--
-- Name: leaderboard_entries fk_rails_f523f294cc; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.leaderboard_entries
    ADD CONSTRAINT fk_rails_f523f294cc FOREIGN KEY (leaderboard_id) REFERENCES public.leaderboards(id);


--
-- Name: heartbeat_branches fk_rails_f555b68b93; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.heartbeat_branches
    ADD CONSTRAINT fk_rails_f555b68b93 FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: admin_api_keys fk_rails_fc8be7fc55; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.admin_api_keys
    ADD CONSTRAINT fk_rails_fc8be7fc55 FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- PostgreSQL database dump complete
--

SET search_path TO "$user", public;

INSERT INTO "schema_migrations" (version) VALUES
('20260310150000'),
('20260310112820'),
('20260304121229'),
('20260301200002'),
('20260301200001'),
('20260301200000'),
('20260301125356'),
('20260301112933'),
('20260301112514'),
('20260301112503'),
('20260301111406'),
('20260301111352'),
('20260223212054'),
('20260223134705'),
('20260223134704'),
('20260223134702'),
('20260221113553'),
('20260219153152'),
('20260219125517'),
('20260215220822'),
('20260215191500'),
('20260215094000'),
('20260215093600'),
('20260204113033'),
('20260202210555'),
('20260202210552'),
('20260120014910'),
('20260120014145'),
('20260117224613'),
('20260117202656'),
('20260106143925'),
('20260105230132'),
('20260103141942'),
('20251230202839'),
('20251229142540'),
('20251208020226'),
('20251205211711'),
('20251202221230'),
('20251201161700'),
('20251116045400'),
('20251021211039'),
('20251021202329'),
('20251018181955'),
('20251003215127'),
('20251003161836'),
('20250821021751'),
('20250722233948'),
('20250709001202'),
('20250705'),
('20250701142553'),
('20250630000002'),
('20250630000001'),
('20250628011017'),
('20250626001500'),
('20250623135342'),
('20250618170000'),
('20250616192214'),
('20250616191832'),
('20250613163710'),
('20250611071124'),
('20250611070646'),
('20250611062456'),
('20250611062306'),
('20250611061502'),
('20250609203830'),
('20250609144356'),
('20250609143856'),
('20250608205244'),
('20250608195535'),
('20250531120000'),
('20250530135145'),
('20250530015530'),
('20250530015024'),
('20250530015016'),
('20250527052632'),
('20250522062125'),
('20250516142043'),
('20250516142026'),
('20250516140014'),
('20250514212714'),
('20250514180503'),
('20250514150404'),
('20250513184040'),
('20250513183739'),
('20250512205858'),
('20250509191155'),
('20250509183721'),
('20250509170101'),
('20250509160228'),
('20250507211848'),
('20250507204732'),
('20250507184341'),
('20250507183451'),
('20250507182617'),
('20250507174855'),
('20250506155521'),
('20250505152654'),
('20250505151057'),
('20250505045020'),
('20250503215404'),
('20250425211619'),
('20250324203539'),
('20250319193636'),
('20250319165910'),
('20250319142656'),
('20250315214819'),
('20250315030446'),
('20250313205725'),
('20250312172534'),
('20250312160326'),
('20250312110220'),
('20250310165010'),
('20250307225347'),
('20250307224352'),
('20250307223936'),
('20250307201004'),
('20250306033109'),
('20250305195904'),
('20250305194250'),
('20250305061242'),
('20250304032720'),
('20250303180842'),
('20250303175821'),
('20250223085114'),
('20250223072034'),
('20250222082500'),
('20250222032930'),
('20250222032551'),
('20250222031955'),
('20250222005401'),
('20250222004511'),
('20250222002320'),
('20250221224605'),
('20250221205702'),
('20250221204236'),
('20250216173459'),
('20250216173458'),
('20240320000002'),
('20240320000001'),
('20240320000000'),
('20240316000003'),
('20240316000002'),
('20240316000001'),
('20240101000000');


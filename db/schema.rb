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

ActiveRecord::Schema[8.1].define(version: 2026_01_05_230132) do
  create_schema "pganalyze"
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"
  enable_extension "pg_stat_statements"

  create_table "activities", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "key"
    t.bigint "owner_id"
    t.string "owner_type"
    t.text "parameters"
    t.bigint "recipient_id"
    t.string "recipient_type"
    t.bigint "trackable_id"
    t.string "trackable_type"
    t.datetime "updated_at", null: false
    t.index ["owner_id", "owner_type"], name: "index_activities_on_owner_id_and_owner_type"
    t.index ["owner_type", "owner_id"], name: "index_activities_on_owner"
    t.index ["recipient_id", "recipient_type"], name: "index_activities_on_recipient_id_and_recipient_type"
    t.index ["recipient_type", "recipient_id"], name: "index_activities_on_recipient"
    t.index ["trackable_id", "trackable_type"], name: "index_activities_on_trackable_id_and_trackable_type"
    t.index ["trackable_type", "trackable_id"], name: "index_activities_on_trackable"
  end

  create_table "admin_api_keys", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "name", null: false
    t.datetime "revoked_at"
    t.text "token", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["token"], name: "index_admin_api_keys_on_token", unique: true
    t.index ["user_id", "name"], name: "index_admin_api_keys_on_user_id_and_name", unique: true
    t.index ["user_id"], name: "index_admin_api_keys_on_user_id"
  end

  create_table "ahoy_events", force: :cascade do |t|
    t.string "name"
    t.jsonb "properties"
    t.datetime "time"
    t.bigint "user_id"
    t.bigint "visit_id"
    t.index ["name", "time"], name: "index_ahoy_events_on_name_and_time"
    t.index ["properties"], name: "index_ahoy_events_on_properties", opclass: :jsonb_path_ops, using: :gin
    t.index ["time"], name: "index_ahoy_events_on_time"
    t.index ["user_id"], name: "index_ahoy_events_on_user_id"
    t.index ["visit_id"], name: "index_ahoy_events_on_visit_id"
  end

  create_table "ahoy_visits", force: :cascade do |t|
    t.string "app_version"
    t.string "browser"
    t.string "city"
    t.string "country"
    t.string "device_type"
    t.string "ip"
    t.text "landing_page"
    t.float "latitude"
    t.float "longitude"
    t.string "os"
    t.string "os_version"
    t.string "platform"
    t.text "referrer"
    t.string "referring_domain"
    t.string "region"
    t.datetime "started_at"
    t.text "user_agent"
    t.bigint "user_id"
    t.string "utm_campaign"
    t.string "utm_content"
    t.string "utm_medium"
    t.string "utm_source"
    t.string "utm_term"
    t.string "visit_token"
    t.string "visitor_token"
    t.index ["started_at"], name: "index_ahoy_visits_on_started_at"
    t.index ["started_at"], name: "index_ahoy_visits_started_at_with_referring_domain", where: "(referring_domain IS NOT NULL)"
    t.index ["user_id"], name: "index_ahoy_visits_on_user_id"
    t.index ["visit_token"], name: "index_ahoy_visits_on_visit_token", unique: true
    t.index ["visitor_token", "started_at"], name: "index_ahoy_visits_on_visitor_token_and_started_at"
  end

  create_table "api_keys", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "name", null: false
    t.text "token", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["token"], name: "index_api_keys_on_token", unique: true
    t.index ["user_id", "name"], name: "index_api_keys_on_user_id_and_name", unique: true
    t.index ["user_id", "token"], name: "index_api_keys_on_user_id_and_token", unique: true
    t.index ["user_id"], name: "index_api_keys_on_user_id"
  end

  create_table "commits", primary_key: "sha", id: :string, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.jsonb "github_raw"
    t.bigint "repository_id"
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["repository_id"], name: "index_commits_on_repository_id"
    t.index ["user_id", "created_at"], name: "index_commits_on_user_id_and_created_at"
    t.index ["user_id"], name: "index_commits_on_user_id"
  end

  create_table "deletion_requests", force: :cascade do |t|
    t.datetime "admin_approved_at"
    t.bigint "admin_approved_by_id"
    t.datetime "cancelled_at"
    t.datetime "completed_at"
    t.datetime "created_at", null: false
    t.datetime "requested_at", null: false
    t.datetime "scheduled_deletion_at"
    t.integer "status", default: 0, null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["status"], name: "index_deletion_requests_on_status"
    t.index ["user_id", "status"], name: "index_deletion_requests_on_user_id_and_status"
    t.index ["user_id"], name: "index_deletion_requests_on_user_id"
  end

  create_table "email_addresses", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email"
    t.integer "source"
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["email"], name: "index_email_addresses_on_email", unique: true
    t.index ["user_id"], name: "index_email_addresses_on_user_id"
  end

  create_table "email_verification_requests", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "deleted_at"
    t.string "email"
    t.datetime "expires_at"
    t.string "token"
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["email"], name: "index_email_verification_requests_on_email", unique: true
    t.index ["user_id"], name: "index_email_verification_requests_on_user_id"
  end

  create_table "flipper_features", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "key", null: false
    t.datetime "updated_at", null: false
    t.index ["key"], name: "index_flipper_features_on_key", unique: true
  end

  create_table "flipper_gates", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "feature_key", null: false
    t.string "key", null: false
    t.datetime "updated_at", null: false
    t.text "value"
    t.index ["feature_key", "key", "value"], name: "index_flipper_gates_on_feature_key_and_key_and_value", unique: true
  end

  create_table "good_job_batches", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.integer "callback_priority"
    t.text "callback_queue_name"
    t.datetime "created_at", null: false
    t.text "description"
    t.datetime "discarded_at"
    t.datetime "enqueued_at"
    t.datetime "finished_at"
    t.datetime "jobs_finished_at"
    t.text "on_discard"
    t.text "on_finish"
    t.text "on_success"
    t.jsonb "serialized_properties"
    t.datetime "updated_at", null: false
  end

  create_table "good_job_executions", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "active_job_id", null: false
    t.datetime "created_at", null: false
    t.interval "duration"
    t.text "error"
    t.text "error_backtrace", array: true
    t.integer "error_event", limit: 2
    t.datetime "finished_at"
    t.text "job_class"
    t.uuid "process_id"
    t.text "queue_name"
    t.datetime "scheduled_at"
    t.jsonb "serialized_params"
    t.datetime "updated_at", null: false
    t.index ["active_job_id", "created_at"], name: "index_good_job_executions_on_active_job_id_and_created_at"
    t.index ["process_id", "created_at"], name: "index_good_job_executions_on_process_id_and_created_at"
  end

  create_table "good_job_processes", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "lock_type", limit: 2
    t.jsonb "state"
    t.datetime "updated_at", null: false
  end

  create_table "good_job_settings", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "key"
    t.datetime "updated_at", null: false
    t.jsonb "value"
    t.index ["key"], name: "index_good_job_settings_on_key", unique: true
  end

  create_table "good_jobs", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "active_job_id"
    t.uuid "batch_callback_id"
    t.uuid "batch_id"
    t.text "concurrency_key"
    t.datetime "created_at", null: false
    t.datetime "cron_at"
    t.text "cron_key"
    t.text "error"
    t.integer "error_event", limit: 2
    t.integer "executions_count"
    t.datetime "finished_at"
    t.boolean "is_discrete"
    t.text "job_class"
    t.text "labels", array: true
    t.datetime "locked_at"
    t.uuid "locked_by_id"
    t.datetime "performed_at"
    t.integer "priority"
    t.text "queue_name"
    t.uuid "retried_good_job_id"
    t.datetime "scheduled_at"
    t.jsonb "serialized_params"
    t.datetime "updated_at", null: false
    t.index ["active_job_id", "created_at"], name: "index_good_jobs_on_active_job_id_and_created_at"
    t.index ["batch_callback_id"], name: "index_good_jobs_on_batch_callback_id", where: "(batch_callback_id IS NOT NULL)"
    t.index ["batch_id"], name: "index_good_jobs_on_batch_id", where: "(batch_id IS NOT NULL)"
    t.index ["concurrency_key"], name: "index_good_jobs_on_concurrency_key_when_unfinished", where: "(finished_at IS NULL)"
    t.index ["cron_key", "created_at"], name: "index_good_jobs_on_cron_key_and_created_at_cond", where: "(cron_key IS NOT NULL)"
    t.index ["cron_key", "cron_at"], name: "index_good_jobs_on_cron_key_and_cron_at_cond", unique: true, where: "(cron_key IS NOT NULL)"
    t.index ["finished_at"], name: "index_good_jobs_finished_at_with_error", where: "(error IS NOT NULL)"
    t.index ["finished_at"], name: "index_good_jobs_jobs_on_finished_at", where: "((retried_good_job_id IS NULL) AND (finished_at IS NOT NULL))"
    t.index ["labels"], name: "index_good_jobs_on_labels", where: "(labels IS NOT NULL)", using: :gin
    t.index ["locked_by_id"], name: "index_good_jobs_on_locked_by_id", where: "(locked_by_id IS NOT NULL)"
    t.index ["priority", "created_at"], name: "index_good_job_jobs_for_candidate_lookup", where: "(finished_at IS NULL)"
    t.index ["priority", "created_at"], name: "index_good_jobs_jobs_on_priority_created_at_when_unfinished", order: { priority: "DESC NULLS LAST" }, where: "(finished_at IS NULL)"
    t.index ["priority", "scheduled_at"], name: "index_good_jobs_on_priority_scheduled_at_unfinished_unlocked", where: "((finished_at IS NULL) AND (locked_by_id IS NULL))"
    t.index ["queue_name", "scheduled_at"], name: "index_good_jobs_on_queue_name_and_scheduled_at", where: "(finished_at IS NULL)"
    t.index ["scheduled_at"], name: "index_good_jobs_on_scheduled_at", where: "(finished_at IS NULL)"
  end

  create_table "heartbeats", force: :cascade do |t|
    t.string "branch"
    t.string "category"
    t.datetime "created_at", null: false
    t.integer "cursorpos"
    t.datetime "deleted_at"
    t.string "dependencies", default: [], array: true
    t.string "editor"
    t.string "entity"
    t.text "fields_hash"
    t.inet "ip_address"
    t.boolean "is_write"
    t.string "language"
    t.integer "line_additions"
    t.integer "line_deletions"
    t.integer "lineno"
    t.integer "lines"
    t.string "machine"
    t.string "operating_system"
    t.string "project"
    t.integer "project_root_count"
    t.jsonb "raw_data"
    t.bigint "raw_heartbeat_upload_id"
    t.integer "source_type", null: false
    t.float "time", null: false
    t.string "type"
    t.datetime "updated_at", null: false
    t.string "user_agent"
    t.bigint "user_id", null: false
    t.integer "ysws_program", default: 0, null: false
    t.index ["category", "time"], name: "index_heartbeats_on_category_and_time"
    t.index ["fields_hash"], name: "index_heartbeats_on_fields_hash_when_not_deleted", unique: true, where: "(deleted_at IS NULL)"
    t.index ["ip_address"], name: "index_heartbeats_on_ip_address"
    t.index ["machine"], name: "index_heartbeats_on_machine"
    t.index ["project", "time"], name: "index_heartbeats_on_project_and_time"
    t.index ["project"], name: "index_heartbeats_on_project"
    t.index ["raw_heartbeat_upload_id"], name: "index_heartbeats_on_raw_heartbeat_upload_id"
    t.index ["source_type", "time", "user_id", "project"], name: "index_heartbeats_on_source_type_time_user_project"
    t.index ["user_id", "project", "time"], name: "idx_heartbeats_user_project_time_stats", where: "((deleted_at IS NULL) AND (project IS NOT NULL))"
    t.index ["user_id", "time", "category"], name: "index_heartbeats_on_user_time_category"
    t.index ["user_id", "time", "language"], name: "idx_heartbeats_user_time_language_stats", where: "(deleted_at IS NULL)"
    t.index ["user_id", "time", "project"], name: "idx_heartbeats_user_time_project_stats", where: "(deleted_at IS NULL)"
    t.index ["user_id", "time"], name: "idx_heartbeats_user_time_active", where: "(deleted_at IS NULL)"
    t.index ["user_id"], name: "index_heartbeats_on_user_id"
  end

  create_table "leaderboard_entries", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "leaderboard_id", null: false
    t.integer "rank"
    t.integer "streak_count", default: 0
    t.integer "total_seconds", default: 0, null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["leaderboard_id", "user_id"], name: "idx_leaderboard_entries_on_leaderboard_and_user", unique: true
    t.index ["leaderboard_id"], name: "index_leaderboard_entries_on_leaderboard_id"
  end

  create_table "leaderboards", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "deleted_at"
    t.datetime "finished_generating_at"
    t.integer "period_type", default: 0, null: false
    t.date "start_date", null: false
    t.integer "timezone_offset"
    t.integer "timezone_utc_offset"
    t.datetime "updated_at", null: false
    t.index ["start_date", "period_type", "timezone_offset"], name: "index_leaderboards_on_start_date_period_type_timezone_offset", where: "(deleted_at IS NULL)"
    t.index ["start_date"], name: "index_leaderboards_on_start_date", where: "(deleted_at IS NULL)"
  end

  create_table "oauth_access_grants", force: :cascade do |t|
    t.bigint "application_id", null: false
    t.datetime "created_at", null: false
    t.integer "expires_in", null: false
    t.text "redirect_uri", null: false
    t.bigint "resource_owner_id", null: false
    t.datetime "revoked_at"
    t.string "scopes", default: "", null: false
    t.string "token", null: false
    t.index ["application_id"], name: "index_oauth_access_grants_on_application_id"
    t.index ["resource_owner_id"], name: "index_oauth_access_grants_on_resource_owner_id"
    t.index ["token"], name: "index_oauth_access_grants_on_token", unique: true
  end

  create_table "oauth_access_tokens", force: :cascade do |t|
    t.bigint "application_id", null: false
    t.datetime "created_at", null: false
    t.integer "expires_in"
    t.string "previous_refresh_token", default: "", null: false
    t.string "refresh_token"
    t.bigint "resource_owner_id"
    t.datetime "revoked_at"
    t.string "scopes"
    t.string "token", null: false
    t.index ["application_id"], name: "index_oauth_access_tokens_on_application_id"
    t.index ["refresh_token"], name: "index_oauth_access_tokens_on_refresh_token", unique: true
    t.index ["resource_owner_id"], name: "index_oauth_access_tokens_on_resource_owner_id"
    t.index ["token"], name: "index_oauth_access_tokens_on_token", unique: true
  end

  create_table "oauth_applications", force: :cascade do |t|
    t.boolean "confidential", default: true, null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.text "redirect_uri", null: false
    t.string "scopes", default: "", null: false
    t.string "secret", null: false
    t.string "uid", null: false
    t.datetime "updated_at", null: false
    t.index ["uid"], name: "index_oauth_applications_on_uid", unique: true
  end

  create_table "project_labels", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "label"
    t.string "project_key"
    t.datetime "updated_at", null: false
    t.string "user_id"
    t.index ["user_id", "project_key"], name: "index_project_labels_on_user_id_and_project_key", unique: true
    t.index ["user_id"], name: "index_project_labels_on_user_id"
  end

  create_table "project_repo_mappings", force: :cascade do |t|
    t.datetime "archived_at"
    t.datetime "created_at", null: false
    t.string "project_name", null: false
    t.string "repo_url", null: false
    t.bigint "repository_id"
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["project_name"], name: "index_project_repo_mappings_on_project_name"
    t.index ["repository_id"], name: "index_project_repo_mappings_on_repository_id"
    t.index ["user_id", "archived_at"], name: "index_project_repo_mappings_on_user_id_and_archived_at"
    t.index ["user_id", "project_name"], name: "index_project_repo_mappings_on_user_id_and_project_name", unique: true
    t.index ["user_id"], name: "index_project_repo_mappings_on_user_id"
  end

  create_table "raw_heartbeat_uploads", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.jsonb "request_body", null: false
    t.jsonb "request_headers", null: false
    t.datetime "updated_at", null: false
  end

  create_table "repo_host_events", id: :string, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "provider", default: 0, null: false
    t.jsonb "raw_event_payload", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["provider"], name: "index_repo_host_events_on_provider"
    t.index ["user_id", "provider", "created_at"], name: "index_repo_host_events_on_user_provider_created_at"
    t.index ["user_id"], name: "index_repo_host_events_on_user_id"
  end

  create_table "repositories", force: :cascade do |t|
    t.integer "commit_count"
    t.datetime "created_at", null: false
    t.text "description"
    t.string "homepage"
    t.string "host"
    t.string "language"
    t.text "languages"
    t.datetime "last_commit_at"
    t.datetime "last_synced_at"
    t.string "name"
    t.string "owner"
    t.integer "stars"
    t.datetime "updated_at", null: false
    t.string "url"
    t.index ["url"], name: "index_repositories_on_url", unique: true
  end

  create_table "sailors_log_leaderboards", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "deleted_at"
    t.text "message"
    t.string "slack_channel_id"
    t.string "slack_uid"
    t.datetime "updated_at", null: false
  end

  create_table "sailors_log_notification_preferences", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.boolean "enabled", default: true, null: false
    t.string "slack_channel_id", null: false
    t.string "slack_uid", null: false
    t.datetime "updated_at", null: false
    t.index ["slack_uid", "slack_channel_id"], name: "idx_sailors_log_notification_preferences_unique_user_channel", unique: true
  end

  create_table "sailors_log_slack_notifications", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "project_duration", null: false
    t.string "project_name", null: false
    t.boolean "sent", default: false, null: false
    t.string "slack_channel_id", null: false
    t.string "slack_uid", null: false
    t.datetime "updated_at", null: false
  end

  create_table "sailors_logs", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.jsonb "projects_summary", default: {}, null: false
    t.string "slack_uid", null: false
    t.datetime "updated_at", null: false
  end

  create_table "sign_in_tokens", force: :cascade do |t|
    t.integer "auth_type"
    t.string "continue_param"
    t.datetime "created_at", null: false
    t.datetime "expires_at"
    t.jsonb "return_data"
    t.string "token"
    t.datetime "updated_at", null: false
    t.datetime "used_at"
    t.bigint "user_id", null: false
    t.index ["token"], name: "index_sign_in_tokens_on_token"
    t.index ["user_id"], name: "index_sign_in_tokens_on_user_id"
  end

  create_table "solid_cache_entries", force: :cascade do |t|
    t.integer "byte_size", null: false
    t.datetime "created_at", null: false
    t.binary "key", null: false
    t.bigint "key_hash", null: false
    t.binary "value", null: false
    t.index ["byte_size"], name: "index_solid_cache_entries_on_byte_size"
    t.index ["key_hash", "byte_size"], name: "index_solid_cache_entries_on_key_hash_and_byte_size"
    t.index ["key_hash"], name: "index_solid_cache_entries_on_key_hash", unique: true
  end

  create_table "trust_level_audit_logs", force: :cascade do |t|
    t.bigint "changed_by_id", null: false
    t.datetime "created_at", null: false
    t.string "new_trust_level", null: false
    t.text "notes"
    t.string "previous_trust_level", null: false
    t.text "reason"
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["changed_by_id", "created_at"], name: "index_trust_level_audit_logs_on_changed_by_and_created_at"
    t.index ["changed_by_id"], name: "index_trust_level_audit_logs_on_changed_by_id"
    t.index ["user_id", "created_at"], name: "index_trust_level_audit_logs_on_user_and_created_at"
    t.index ["user_id"], name: "index_trust_level_audit_logs_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.integer "admin_level", default: 0, null: false
    t.boolean "allow_public_stats_lookup", default: true, null: false
    t.string "country_code"
    t.datetime "created_at", null: false
    t.boolean "default_timezone_leaderboard", default: true, null: false
    t.string "deprecated_name"
    t.text "github_access_token"
    t.string "github_avatar_url"
    t.string "github_uid"
    t.string "github_username"
    t.integer "hackatime_extension_text_type", default: 0, null: false
    t.string "hca_access_token"
    t.string "hca_id"
    t.string "hca_scopes", default: [], array: true
    t.text "slack_access_token"
    t.string "slack_avatar_url"
    t.string "slack_scopes", default: [], array: true
    t.string "slack_uid"
    t.string "slack_username"
    t.string "timezone", default: "UTC"
    t.integer "trust_level", default: 0, null: false
    t.datetime "updated_at", null: false
    t.string "username"
    t.boolean "uses_slack_status", default: false, null: false
    t.index ["github_uid", "github_access_token"], name: "index_users_on_github_uid_and_access_token"
    t.index ["github_uid"], name: "index_users_on_github_uid"
    t.index ["slack_uid"], name: "index_users_on_slack_uid", unique: true
    t.index ["timezone", "trust_level"], name: "index_users_on_timezone_trust_level"
    t.index ["timezone"], name: "index_users_on_timezone"
    t.index ["username"], name: "index_users_on_username"
  end

  create_table "versions", force: :cascade do |t|
    t.datetime "created_at"
    t.string "event", null: false
    t.bigint "item_id", null: false
    t.string "item_type", null: false
    t.text "object"
    t.text "object_changes"
    t.string "whodunnit"
    t.index ["item_type", "item_id"], name: "index_versions_on_item_type_and_item_id"
  end

  create_table "wakatime_mirrors", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "encrypted_api_key", null: false
    t.string "endpoint_url", default: "https://wakatime.com/api/v1", null: false
    t.datetime "last_synced_at"
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["user_id", "endpoint_url"], name: "index_wakatime_mirrors_on_user_id_and_endpoint_url", unique: true
    t.index ["user_id"], name: "index_wakatime_mirrors_on_user_id"
  end

  add_foreign_key "admin_api_keys", "users"
  add_foreign_key "api_keys", "users"
  add_foreign_key "commits", "repositories"
  add_foreign_key "commits", "users"
  add_foreign_key "deletion_requests", "users"
  add_foreign_key "deletion_requests", "users", column: "admin_approved_by_id"
  add_foreign_key "email_addresses", "users"
  add_foreign_key "email_verification_requests", "users"
  add_foreign_key "heartbeats", "raw_heartbeat_uploads"
  add_foreign_key "heartbeats", "users"
  add_foreign_key "leaderboard_entries", "leaderboards"
  add_foreign_key "leaderboard_entries", "users"
  add_foreign_key "oauth_access_grants", "oauth_applications", column: "application_id"
  add_foreign_key "oauth_access_grants", "users", column: "resource_owner_id"
  add_foreign_key "oauth_access_tokens", "oauth_applications", column: "application_id"
  add_foreign_key "oauth_access_tokens", "users", column: "resource_owner_id"
  add_foreign_key "project_repo_mappings", "repositories"
  add_foreign_key "project_repo_mappings", "users"
  add_foreign_key "repo_host_events", "users"
  add_foreign_key "sign_in_tokens", "users"
  add_foreign_key "trust_level_audit_logs", "users"
  add_foreign_key "trust_level_audit_logs", "users", column: "changed_by_id"
  add_foreign_key "wakatime_mirrors", "users"
end

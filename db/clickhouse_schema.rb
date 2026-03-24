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

ActiveRecord::Schema[8.1].define(version: 2026_03_24_000002) do
  # TABLE: heartbeat_user_daily_summary
  # SQL: CREATE TABLE heartbeat_user_daily_summary ( `user_id` Int64, `day` Date, `duration_s` Float64, `heartbeats` UInt32, `_version` DateTime DEFAULT now() ) ENGINE = ReplacingMergeTree(_version) ORDER BY (user_id, day) SETTINGS index_granularity = 8192
  create_table "heartbeat_user_daily_summary", id: false, options: "ReplacingMergeTree(_version) ORDER BY (user_id, day) SETTINGS index_granularity = 8192", force: :cascade do |t|
    t.integer "user_id", unsigned: false, limit: 8, null: false
    t.date "day", null: false
    t.float "duration_s", null: false
    t.integer "heartbeats", null: false
    t.datetime "_version", precision: nil, default: -> { "now()" }, null: false
  end

  # TABLE: heartbeats
  # SQL: CREATE TABLE heartbeats ( `id` Int64, `user_id` Int64, `branch` String DEFAULT '', `category` String DEFAULT '', `dependencies` Array(String), `editor` String DEFAULT '', `entity` String DEFAULT '', `language` String DEFAULT '', `machine` String DEFAULT '', `operating_system` String DEFAULT '', `project` String DEFAULT '', `type` String DEFAULT '', `user_agent` String DEFAULT '', `line_additions` Int32 DEFAULT 0, `line_deletions` Int32 DEFAULT 0, `lineno` Int32 DEFAULT 0, `lines` Int32 DEFAULT 0, `cursorpos` Int32 DEFAULT 0, `project_root_count` Int32 DEFAULT 0, `time` Float64, `is_write` UInt8 DEFAULT 0, `created_at` DateTime64(6) DEFAULT now64(), `updated_at` DateTime64(6) DEFAULT now64(), `source_type` UInt8 DEFAULT 0, `ip_address` String DEFAULT '', `ysws_program` UInt8 DEFAULT 0, `fields_hash` String DEFAULT '' ) ENGINE = ReplacingMergeTree PARTITION BY toYYYYMM(toDateTime(toUInt32(time))) ORDER BY (user_id, toDate(toDateTime(toUInt32(time))), project, id) SETTINGS index_granularity = 8192
  create_table "heartbeats", id: :int64, options: "ReplacingMergeTree PARTITION BY toYYYYMM(toDateTime(toUInt32(time))) ORDER BY (user_id, toDate(toDateTime(toUInt32(time))), project, id) SETTINGS index_granularity = 8192", force: :cascade do |t|
    t.integer "id", unsigned: false, limit: 8, null: false
    t.integer "user_id", unsigned: false, limit: 8, null: false
    t.string "branch", default: "", null: false
    t.string "category", default: "", null: false
    t.string "dependencies", array: true, null: false
    t.string "editor", default: "", null: false
    t.string "entity", default: "", null: false
    t.string "language", default: "", null: false
    t.string "machine", default: "", null: false
    t.string "operating_system", default: "", null: false
    t.string "project", default: "", null: false
    t.string "type", default: "", null: false
    t.string "user_agent", default: "", null: false
    t.integer "line_additions", unsigned: false, default: 0, null: false
    t.integer "line_deletions", unsigned: false, default: 0, null: false
    t.integer "lineno", unsigned: false, default: 0, null: false
    t.integer "lines", unsigned: false, default: 0, null: false
    t.integer "cursorpos", unsigned: false, default: 0, null: false
    t.integer "project_root_count", unsigned: false, default: 0, null: false
    t.float "time", null: false
    t.integer "is_write", limit: 1, default: 0, null: false
    t.datetime "created_at", default: -> { "now64()" }, null: false
    t.datetime "updated_at", default: -> { "now64()" }, null: false
    t.integer "source_type", limit: 1, default: 0, null: false
    t.string "ip_address", default: "", null: false
    t.integer "ysws_program", limit: 1, default: 0, null: false
    t.string "fields_hash", default: "", null: false
  end
end

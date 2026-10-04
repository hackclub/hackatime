require "test_helper"

# Contract tests for the clickhouse-activerecord adapter against the real
# heartbeats DDL (db/clickhouse/001_create_heartbeats.sql). These pin the
# behaviours the rest of the app relies on: exact types, nil vs empty, big ids,
# explicit write settings, read-after-write, lightweight updates and
# cross-database associations.
class ClickhouseContractTest < ActiveSupport::TestCase
  BIG_ID = 2**53 + 7 # beyond Float precision

  setup do
    @user = create(:user)
  end

  def insert_row(**attrs)
    now = Time.utc(2026, 10, 4, 12, 0, 0, 123_456)
    row = {
      id: attrs.delete(:id) || Heartbeat.allocate_ids(1).first,
      user_id: @user.id,
      time: 1_791_111_482.123456,
      source_type: 0,
      dependencies: [],
      dependencies_is_null: false,
      created_at: now,
      updated_at: now
    }.merge(attrs)
    Heartbeat.with_clickhouse_settings(**ClickhouseRecord::SYNC_INSERT_SETTINGS) { Heartbeat.insert_all!([ row ]) }
    row[:id]
  end

  test "uses the clickhouse connection and the declared primary key" do
    assert_equal "clickhouse", Heartbeat.connection.adapter_name.downcase
    assert_equal "id", Heartbeat.primary_key
  end

  test "ids above 2**53 survive insert, lookup and pluck" do
    insert_row(id: BIG_ID)
    assert_equal BIG_ID, Heartbeat.unscoped.with_excluded.where(id: BIG_ID).pick(:id)
    assert_equal BIG_ID, Heartbeat.unscoped.with_excluded.find(BIG_ID).id
  end

  test "Float64 time keeps fractional seconds" do
    id = insert_row(time: 1_791_111_482.123456)
    assert_in_delta 1_791_111_482.123456, Heartbeat.unscoped.with_excluded.where(id:).pick(:time), 1e-6
  end

  test "nullable strings keep nil distinct from empty" do
    a = insert_row(project: nil, editor: nil)
    b = insert_row(project: "", editor: "")
    assert_equal [ nil, nil ], Heartbeat.unscoped.with_excluded.where(id: a).pick(:project, :editor)
    assert_equal [ "", "" ], Heartbeat.unscoped.with_excluded.where(id: b).pick(:project, :editor)
  end

  test "nullable bool keeps nil distinct from false" do
    a = insert_row(is_write: nil)
    b = insert_row(is_write: false)
    c = insert_row(is_write: true)
    assert_equal [ nil, false, true ], [ a, b, c ].map { |id| Heartbeat.unscoped.with_excluded.where(id:).pick(:is_write) }
  end

  test "dependencies round-trip as a Ruby array" do
    id = insert_row(dependencies: %w[rails pg "quoted"])
    assert_equal %w[rails pg "quoted"], Heartbeat.unscoped.with_excluded.where(id:).pick(:dependencies)
  end

  test "enum source_type maps to UInt8" do
    id = insert_row(source_type: Heartbeat.source_types[:wakapi_import])
    assert_equal "wakapi_import", Heartbeat.unscoped.with_excluded.find(id).source_type
  end

  test "DateTime64(6) keeps UTC and microseconds" do
    stamp = Time.utc(2026, 10, 4, 12, 0, 0, 654_321)
    id = insert_row(created_at: stamp, updated_at: stamp)
    got = Heartbeat.unscoped.with_excluded.where(id:).pick(:created_at)
    assert_equal stamp.to_r, got.to_r
    assert_equal "UTC", got.utc? ? "UTC" : got.zone
  end

  test "async insert with wait is visible to the next read" do
    id = Heartbeat.allocate_ids(1).first
    now = Time.current
    Heartbeat.with_clickhouse_settings(**ClickhouseRecord::INGEST_INSERT_SETTINGS) do
      Heartbeat.insert_all!([ { id:, user_id: @user.id, time: now.to_f, source_type: 0, dependencies: [], created_at: now, updated_at: now } ])
    end
    assert Heartbeat.unscoped.with_excluded.where(id:).exists?
  end

  test "lightweight soft delete is visible immediately" do
    id = insert_row
    Heartbeat.soft_delete_where!(user_id: @user.id, ids: [ id ])
    assert_nil Heartbeat.where(id:).pick(:id)
    assert Heartbeat.unscoped.with_excluded.where(id:).pick(:deleted_at)
  end

  test "user.heartbeats crosses databases" do
    insert_row
    assert_equal 1, @user.heartbeats.count
    assert_equal @user, @user.heartbeats.first.user
  end

  test "empty max returns nil" do
    assert_nil Heartbeat.where(user_id: @user.id).maximum(:time)
  end
end

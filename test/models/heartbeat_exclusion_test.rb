require "test_helper"

class HeartbeatExclusionTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  setup do
    Rails.cache.clear
    clear_enqueued_jobs
    @original_queue_adapter = ActiveJob::Base.queue_adapter
    ActiveJob::Base.queue_adapter = :test

    @user = create(:user, timezone: "UTC")
    @cutoff = Time.utc(2026, 3, 1)
    @before_cutoff = build_heartbeat(@cutoff - 2.days, "old-project")
    @after_cutoff = build_heartbeat(@cutoff + 2.days, "new-project")
  end

  teardown do
    Rails.cache.clear
    clear_enqueued_jobs
    ActiveJob::Base.queue_adapter = @original_queue_adapter
  end

  def build_heartbeat(time, project, user: @user)
    create(:heartbeat, user:, entity: "src/main.rb", type: "file",
      category: "coding", time: time.to_f, project:, source_type: :test_entry)
  end

  def poisoned_until = @user.reload.active_poison&.ends_at&.utc

  test "poisoning hides heartbeats before the cutoff but keeps the rows" do
    @user.apply_poison!(@cutoff)

    assert_not_includes Heartbeat.all, @before_cutoff
    assert_includes Heartbeat.all, @after_cutoff
    assert Heartbeat.unscoped.exists?(@before_cutoff.id)
  end

  test "poisoning applies to the user's own association reads" do
    @user.apply_poison!(@cutoff)

    assert_not_includes @user.heartbeats.reload, @before_cutoff
    assert_includes @user.heartbeats.reload, @after_cutoff
  end

  test "poisoned time is excluded from durations and project grouping" do
    @user.apply_poison!(@cutoff)

    assert_not_includes @user.heartbeats.group(:project).duration_seconds.keys, "old-project"
  end

  test "poisoning one user does not hide another user's heartbeats" do
    other_old = build_heartbeat(@cutoff - 5.days, "other", user: create(:user, timezone: "UTC"))

    @user.apply_poison!(@cutoff)

    assert_includes Heartbeat.all, other_old
  end

  test "removing the poison restores the heartbeats and keeps the rule as history" do
    admin = create(:user, admin_level: :superadmin)
    @user.apply_poison!(@cutoff, reason: "fabricated", by: admin)

    assert @user.remove_poison!(by: admin)

    assert_includes Heartbeat.all, @before_cutoff
    assert_not @user.reload.poisoned?
    rule = @user.heartbeat_exclusions.sole
    assert rule.poison?
    assert_equal admin, rule.created_by
    assert_equal admin, rule.revoked_by
    assert_not_nil rule.revoked_at
  end

  test "removing a poison that does not exist returns false" do
    assert_not @user.remove_poison!
  end

  test "a second poison replaces the active one" do
    @user.apply_poison!(@cutoff)
    @user.apply_poison!(@cutoff + 5.days)

    assert_equal @cutoff + 5.days, poisoned_until
    assert_not_includes Heartbeat.all, @after_cutoff
    assert_equal 1, @user.heartbeat_exclusions.active.count
    assert_equal 2, @user.heartbeat_exclusions.count
  end

  test "the database allows only one active poison per user" do
    @user.apply_poison!(@cutoff)

    assert_raises(ActiveRecord::RecordNotUnique) do
      HeartbeatExclusion.create!(user: @user, kind: :poison, ends_at: @cutoff)
    end
  end

  test "resubmitting a hidden heartbeat is a duplicate, not a failure" do
    attrs = {
      "entity" => "src/dedup.rb", "type" => "file", "category" => "coding",
      "editor" => "vscode", "project" => "dedup", "language" => "Ruby",
      "branch" => "main", "time" => (@cutoff - 2.days).to_f
    }
    create(:heartbeat, user: @user, source_type: :direct_entry,
      entity: "src/dedup.rb", type: "file", category: "coding", editor: "vscode",
      project: "dedup", language: "Ruby", branch: "main", time: (@cutoff - 2.days).to_f)

    @user.apply_poison!(@cutoff)

    result = HeartbeatIngest.call(user: @user, mode: :direct, request_context: {}, heartbeats: [ attrs ])

    assert_equal 0, result.failed_count
    assert_equal 1, result.duplicate_count
  end

  test "a project rule hides only that project's heartbeats" do
    same_day_other_project = build_heartbeat(@cutoff - 2.days, "kept-project")

    HeartbeatExclusion.create!(user: @user, kind: :project_deletion, project: "old-project")

    assert_not_includes Heartbeat.all, @before_cutoff
    assert_includes Heartbeat.all, same_day_other_project
    assert_includes Heartbeat.all, @after_cutoff
  end

  test "a project rule honours its time range" do
    later_same_project = build_heartbeat(@cutoff + 1.day, "old-project")

    HeartbeatExclusion.create!(user: @user, kind: :project_deletion, project: "old-project", ends_at: @cutoff)

    assert_not_includes Heartbeat.all, @before_cutoff
    assert_includes Heartbeat.all, later_same_project
  end

  test "a project rule does not hide another user's project with the same name" do
    other_same_name = build_heartbeat(@cutoff - 2.days, "old-project", user: create(:user, timezone: "UTC"))

    HeartbeatExclusion.create!(user: @user, kind: :project_deletion, project: "old-project")

    assert_includes Heartbeat.all, other_same_name
  end

  test "a revoked rule hides nothing" do
    rule = HeartbeatExclusion.create!(user: @user, kind: :project_deletion, project: "old-project")
    rule.revoke!

    assert_includes Heartbeat.all, @before_cutoff
  end

  test "rule shape is enforced in the model and the database" do
    assert_not HeartbeatExclusion.new(user: @user, kind: :project_deletion).valid?
    assert_not HeartbeatExclusion.new(user: @user, kind: :poison).valid?
    assert_not HeartbeatExclusion.new(user: @user, kind: :poison, ends_at: @cutoff, project: "x").valid?

    assert_raises(ActiveRecord::StatementInvalid) do
      HeartbeatExclusion.new(user: @user, kind: :project_deletion, project: "x",
        starts_at: @cutoff, ends_at: @cutoff - 1.day).save!(validate: false)
    end
  end

  test "heartbeats returns exactly the rows a rule hides" do
    rule = @user.apply_poison!(@cutoff)

    assert_equal [ @before_cutoff ], rule.heartbeats.to_a
  end

  test "with_excluded reveals hidden heartbeats and keeps other conditions" do
    @user.apply_poison!(@cutoff)
    other_old = build_heartbeat(@cutoff - 5.days, "other", user: create(:user, timezone: "UTC"))

    revealed = @user.heartbeats.with_excluded

    assert_includes revealed, @before_cutoff
    assert_not_includes revealed, other_old
    assert_equal [ @before_cutoff ], Heartbeat.where(project: "old-project").with_excluded.to_a
  end

  test "with_excluded still hides soft deleted heartbeats" do
    @before_cutoff.soft_delete
    @user.apply_poison!(@cutoff)

    assert_not_includes Heartbeat.with_excluded, @before_cutoff
  end

  test "the default scope applies the exclusion filter exactly once" do
    assert_equal 1, Heartbeat.all.to_sql.scan("heartbeat_exclusions.revoked_at IS NULL").length
    assert_equal 0, Heartbeat.with_excluded.to_sql.scan("heartbeat_exclusions").length
  end

  test "exclusions compose with or" do
    @user.apply_poison!(@cutoff)

    combined = @user.heartbeats.where(project: "old-project").or(@user.heartbeats.where(project: "new-project"))

    assert_equal [ @after_cutoff ], combined.to_a
  end

  test "raw SQL using VISIBLE_SQL matches model reads" do
    @user.apply_poison!(@cutoff)

    ids = Heartbeat.connection.select_values(
      "SELECT id FROM heartbeats WHERE deleted_at IS NULL AND #{HeartbeatExclusion::VISIBLE_SQL} AND user_id = #{@user.id}"
    )

    assert_equal [ @after_cutoff.id ], ids
  end

  test "a DateTime cutoff keeps its time of day" do
    @user.apply_poison!(DateTime.new(2026, 3, 1, 12, 0, 0))

    assert_equal Time.utc(2026, 3, 1, 12), poisoned_until
  end

  test "a Date cutoff still covers the whole day" do
    @user.apply_poison!(Date.new(2026, 3, 1))

    assert_equal Time.utc(2026, 3, 2), poisoned_until
  end

  test "a date-only cutoff covers the whole named day in the user's own timezone" do
    @user.update!(timezone: "America/New_York")

    @user.apply_poison!("2026-03-01")

    assert_equal Time.utc(2026, 3, 2, 5), poisoned_until
  end

  test "heartbeats logged on the ban date itself are poisoned" do
    morning = build_heartbeat(Time.utc(2026, 3, 1, 0, 1), "ban-day-morning")
    night = build_heartbeat(Time.utc(2026, 3, 1, 23, 59), "ban-day-night")
    next_day = build_heartbeat(Time.utc(2026, 3, 2, 0, 1), "day-after")

    @user.apply_poison!("2026-03-01")

    assert_not_includes Heartbeat.all, morning
    assert_not_includes Heartbeat.all, night
    assert_includes Heartbeat.all, next_day
  end

  test "a timestamp cutoff with an explicit offset is treated as an absolute instant" do
    @user.update!(timezone: "America/New_York")

    @user.apply_poison!("2026-03-01T12:00:00Z")

    assert_equal Time.utc(2026, 3, 1, 12), poisoned_until
  end

  test "a naive timestamp resolves in the user's zone regardless of the ambient zone" do
    @user.update!(timezone: "America/New_York")

    Time.use_zone("Asia/Tokyo") { @user.apply_poison!("2026-03-01T12:00:00") }
    from_tokyo = poisoned_until
    Time.use_zone("UTC") { @user.apply_poison!("2026-03-01T12:00:00") }

    assert_equal Time.utc(2026, 3, 1, 17), from_tokyo
    assert_equal from_tokyo, poisoned_until
  end

  test "today is an allowed ban date even though it ends at tomorrow's midnight" do
    @user.apply_poison!(Date.current.to_s)

    assert @user.reload.poisoned?
    assert_equal Date.current + 1, @user.active_poison.ends_at.in_time_zone(@user.timezone).to_date
  end

  test "a future ban date or timestamp is rejected" do
    assert_raises(ArgumentError) { @user.apply_poison!((Date.current + 1).to_s) }
    assert_raises(ArgumentError) { @user.apply_poison!(Date.current + 30) }
    assert_raises(ArgumentError) { @user.apply_poison!((Time.current + 2.hours).iso8601) }

    assert_not @user.reload.poisoned?
  end

  test "a future date is rejected relative to the user's own timezone" do
    @user.update!(timezone: "Pacific/Kiritimati")

    assert_raises(ArgumentError) { @user.apply_poison!((Date.current + 2).to_s) }
  end

  test "a missing or unparseable cutoff raises rather than hiding everything" do
    [ nil, "", "not-a-date", "2026-02-30" ].each do |raw|
      assert_raises(ArgumentError) { @user.apply_poison!(raw) }
    end

    assert_not @user.reload.poisoned?
  end

  test "poisoning removes the user's stale current leaderboard entries only" do
    board = Leaderboard.create!(start_date: Date.current, period_type: :daily)
    mine = LeaderboardEntry.create!(leaderboard: board, user: @user, total_seconds: 1140)
    other = LeaderboardEntry.create!(leaderboard: board, user: create(:user, timezone: "UTC"), total_seconds: 1140)
    old_board = Leaderboard.create!(start_date: Date.current - 90, period_type: :daily)
    historical = LeaderboardEntry.create!(leaderboard: old_board, user: @user, total_seconds: 900)

    @user.apply_poison!(@cutoff)
    @user.remove_poison!

    assert_nil LeaderboardEntry.find_by(id: mine.id)
    assert_not_nil LeaderboardEntry.find_by(id: other.id)
    assert_not_nil LeaderboardEntry.find_by(id: historical.id)
  end

  test "poison changes enqueue leaderboard rebuilds and a rollup refresh" do
    @user.apply_poison!(@cutoff)

    Leaderboard::REBUILDABLE_PERIODS.each do |period|
      assert_enqueued_with job: LeaderboardUpdateJob,
        args: [ period, LeaderboardDateRange.normalize_date(Date.current, period), { force_update: true } ]
    end
    assert_enqueued_with job: DashboardRollupRefreshJob, args: [ @user.id ]

    clear_enqueued_jobs
    Rails.cache.clear
    @user.remove_poison!

    assert_enqueued_jobs Leaderboard::REBUILDABLE_PERIODS.size, only: LeaderboardUpdateJob
    assert_enqueued_with job: DashboardRollupRefreshJob, args: [ @user.id ]
  end
end

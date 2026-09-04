require "test_helper"

class HeartbeatPoisoningTest < ActiveSupport::TestCase
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

  def build_heartbeat(time, project)
    create(:heartbeat, user: @user, entity: "src/main.rb", type: "file",
      category: "coding", time: time.to_f, project: project, source_type: :test_entry)
  end

  test "poisoning hides heartbeats before the cutoff but keeps the rows" do
    assert_includes Heartbeat.all, @before_cutoff

    @user.apply_poison!(@cutoff)

    assert_not_includes Heartbeat.all, @before_cutoff
    assert_includes Heartbeat.all, @after_cutoff

    assert Heartbeat.unscoped.exists?(@before_cutoff.id)
  end

  test "poisoning applies to the banned user's own association reads" do
    @user.apply_poison!(@cutoff)

    assert_not_includes @user.heartbeats.reload, @before_cutoff
    assert_includes @user.heartbeats.reload, @after_cutoff
  end

  test "poisoned time is excluded from durations and project grouping" do
    @user.apply_poison!(@cutoff)

    projects = @user.heartbeats.group(:project).duration_seconds

    assert_not_includes projects.keys, "old-project"
  end

  test "including_poison reveals hidden heartbeats only inside the block" do
    @user.apply_poison!(@cutoff)

    Heartbeat.including_poison do
      assert_includes Heartbeat.all, @before_cutoff
    end

    assert_not_includes Heartbeat.all, @before_cutoff
  end

  test "including_poison restores the previous state even when the block raises" do
    @user.apply_poison!(@cutoff)

    assert_raises(RuntimeError) do
      Heartbeat.including_poison { raise "boom" }
    end

    assert_not_includes Heartbeat.all, @before_cutoff
  end

  test "a DateTime cutoff keeps its time of day" do
    @user.apply_poison!(DateTime.new(2026, 3, 1, 12, 0, 0))

    assert_equal Time.utc(2026, 3, 1, 12), @user.poisoned_until.utc
  end

  test "a Date cutoff still covers the whole day" do
    @user.apply_poison!(Date.new(2026, 3, 1))

    assert_equal Time.utc(2026, 3, 2), @user.poisoned_until.utc
  end

  test "resubmitting a poisoned heartbeat is a duplicate, not a failure" do
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

  test "removing the poison restores the hidden heartbeats" do
    @user.apply_poison!(@cutoff)
    assert_not_includes Heartbeat.all, @before_cutoff

    @user.remove_poison!

    assert_includes Heartbeat.all, @before_cutoff
    assert_not @user.reload.poisoned?
  end

  test "the default scope applies the poison filter exactly once" do
    @user.apply_poison!(@cutoff)

    assert_equal 1, Heartbeat.all.to_sql.scan(/EXISTS/).length
    assert_equal 0, Heartbeat.including_poison { Heartbeat.all.to_sql.scan(/EXISTS/).length }
  end

  test "scopes remain composable without tripping the default scope" do
    @user.apply_poison!(@cutoff)

    assert_nothing_raised do
      Heartbeat.where(project: "new-project").excluding_poisoned.count
      Heartbeat.only_poisoned.count
      Heartbeat.coding_only.excluding_poisoned.duration_seconds
    end
  end

  test "only_poisoned returns exactly the hidden heartbeats" do
    @user.apply_poison!(@cutoff)

    poisoned = Heartbeat.only_poisoned.where(user_id: @user.id)

    assert_includes poisoned, @before_cutoff
    assert_not_includes poisoned, @after_cutoff
  end

  test "poisoning one user does not hide another user's heartbeats" do
    other = create(:user, timezone: "UTC")
    other_old = create(:heartbeat, user: other, entity: "a.rb", type: "file",
      category: "coding", time: (@cutoff - 5.days).to_f, project: "other", source_type: :test_entry)

    @user.apply_poison!(@cutoff)

    assert_includes Heartbeat.all, other_old
  end

  test "soft deleted heartbeats stay hidden regardless of poison state" do
    @after_cutoff.soft_delete
    @user.apply_poison!(@cutoff)

    Heartbeat.including_poison do
      assert_not_includes Heartbeat.all, @after_cutoff
    end
  end

  test "a date-only cutoff covers the whole named day in the user's own timezone" do
    @user.update!(timezone: "America/New_York")

    @user.apply_poison!("2026-03-01")

    assert_equal Time.utc(2026, 3, 2, 5), @user.poisoned_until.utc
  end

  test "heartbeats logged on the ban date itself are poisoned" do
    ban_date = Date.new(2026, 3, 1)
    morning = build_heartbeat(Time.utc(2026, 3, 1, 0, 1), "ban-day-morning")
    night = build_heartbeat(Time.utc(2026, 3, 1, 23, 59), "ban-day-night")
    next_day = build_heartbeat(Time.utc(2026, 3, 2, 0, 1), "day-after")

    @user.apply_poison!(ban_date.to_s)

    assert_not_includes Heartbeat.all, morning
    assert_not_includes Heartbeat.all, night
    assert_includes Heartbeat.all, next_day
  end

  test "a timestamp cutoff with an explicit offset is treated as an absolute instant" do
    @user.update!(timezone: "America/New_York")

    @user.apply_poison!("2026-03-01T12:00:00Z")

    assert_equal Time.utc(2026, 3, 1, 12), @user.poisoned_until.utc
  end
  test "a naive timestamp resolves in the user's zone regardless of the ambient zone" do
    @user.update!(timezone: "America/New_York")

    Time.use_zone("Asia/Tokyo") { @user.apply_poison!("2026-03-01T12:00:00") }
    from_tokyo = @user.poisoned_until.utc

    @user.remove_poison!
    Time.use_zone("UTC") { @user.apply_poison!("2026-03-01T12:00:00") }
    from_utc = @user.poisoned_until.utc

    assert_equal Time.utc(2026, 3, 1, 17), from_tokyo
    assert_equal from_tokyo, from_utc
  end

  test "poisoning schedules a dashboard rollup refresh so derived totals recompute" do
    clear_enqueued_jobs

    @user.apply_poison!(@cutoff)

    assert_enqueued_with job: DashboardRollupRefreshJob, args: [ @user.id ]
  end

  test "removing the poison schedules a dashboard rollup refresh" do
    @user.apply_poison!(@cutoff)
    clear_enqueued_jobs

    @user.remove_poison!

    assert_enqueued_with job: DashboardRollupRefreshJob, args: [ @user.id ]
  end

  test "today is an allowed ban date even though it ends at tomorrow's midnight" do
    @user.apply_poison!(Date.current.to_s)

    assert @user.reload.poisoned?
    assert_equal Date.current + 1, @user.poisoned_until.in_time_zone(@user.timezone).to_date
  end

  test "a future ban date is rejected" do
    assert_raises(ArgumentError) { @user.apply_poison!((Date.current + 1).to_s) }
    assert_raises(ArgumentError) { @user.apply_poison!(Date.current + 30) }

    assert_not @user.reload.poisoned?
  end

  test "a future timestamp is rejected" do
    assert_raises(ArgumentError) { @user.apply_poison!((Time.current + 2.hours).iso8601) }

    assert_not @user.reload.poisoned?
  end

  test "a future date is rejected relative to the user's own timezone" do
    @user.update!(timezone: "Pacific/Kiritimati")

    assert_raises(ArgumentError) { @user.apply_poison!((Date.current + 2).to_s) }
  end

  test "applying poison without a cutoff raises rather than hiding everything" do
    assert_raises(ArgumentError) { @user.apply_poison!(nil) }
    assert_raises(ArgumentError) { @user.apply_poison!("") }

    assert_not @user.reload.poisoned?
  end
end

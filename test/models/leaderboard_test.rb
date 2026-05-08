require "test_helper"

class LeaderboardTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  setup do
    Rails.cache.clear
    # `perform_later` enqueues onto the GoodJob backend, which we don't
    # want firing in unit tests; capture into ActiveJob's TestAdapter.
    # Save the original adapter so we restore it in teardown — without
    # this, the :test adapter leaks into other test files that depend
    # on the real GoodJob backend (e.g. HeartbeatExportJobTest).
    @original_queue_adapter = ActiveJob::Base.queue_adapter
    ActiveJob::Base.queue_adapter = :test
  end

  teardown do
    Rails.cache.clear
    ActiveJob::Base.queue_adapter = @original_queue_adapter
  end

  # --- normalize_date -------------------------------------------------------

  test "normalize_date returns today when blank" do
    travel_to Time.zone.local(2024, 3, 20, 12) do
      assert_equal Date.new(2024, 3, 20), Leaderboard.normalize_date(nil)
      assert_equal Date.new(2024, 3, 20), Leaderboard.normalize_date("")
    end
  end

  test "normalize_date parses string dates" do
    assert_equal Date.new(2024, 3, 20), Leaderboard.normalize_date("2024-03-20")
  end

  test "normalize_date passes through Date objects" do
    d = Date.new(2024, 3, 20)
    assert_equal d, Leaderboard.normalize_date(d)
  end

  # --- range ---------------------------------------------------------------

  test "range for daily is rolling 24h ending now" do
    travel_to Time.zone.local(2024, 3, 20, 15, 30) do
      board = Leaderboard.new(start_date: Date.current, period_type: :daily)
      r = board.range
      assert_in_delta 24.hours.ago.to_f, r.first.to_f, 1
      assert_in_delta Time.current.to_f, r.last.to_f, 1
    end
  end

  test "range for last_7_days is anchored on start_date" do
    board = Leaderboard.new(start_date: Date.new(2024, 3, 20), period_type: :last_7_days)
    r = board.range
    assert_equal Date.new(2024, 3, 14).beginning_of_day, r.first
    assert_equal Date.new(2024, 3, 20).end_of_day.to_i, r.last.to_i
  end

  # --- fetch ---------------------------------------------------------------

  test "fetch returns nil and enqueues regeneration when no finished board exists" do
    assert_enqueued_with(job: LeaderboardUpdateJob, args: [ :daily, Date.current ]) do
      assert_nil Leaderboard.fetch(period: :daily, date: Date.current)
    end
  end

  test "fetch returns the persisted finished board" do
    board = Leaderboard.create!(
      start_date: Date.current,
      period_type: :daily,
      finished_generating_at: Time.current
    )

    fetched = Leaderboard.fetch(period: :daily, date: Date.current)
    assert_equal board.id, fetched.id
  end

  test "fetch ignores in-progress (unfinished) boards and enqueues regeneration" do
    Leaderboard.create!(start_date: Date.current, period_type: :daily, finished_generating_at: nil)

    assert_enqueued_with(job: LeaderboardUpdateJob) do
      assert_nil Leaderboard.fetch(period: :daily, date: Date.current)
    end
  end

  test "fetch ignores soft-deleted boards" do
    Leaderboard.create!(
      start_date: Date.current,
      period_type: :daily,
      finished_generating_at: Time.current,
      deleted_at: Time.current
    )

    assert_enqueued_with(job: LeaderboardUpdateJob) do
      assert_nil Leaderboard.fetch(period: :daily, date: Date.current)
    end
  end

  test "fetch caches subsequent lookups, avoiding repeated DB hits" do
    board = Leaderboard.create!(
      start_date: Date.current,
      period_type: :daily,
      finished_generating_at: Time.current
    )

    with_memory_cache do
      Leaderboard.fetch(period: :daily, date: Date.current)
      Leaderboard.where(id: board.id).delete_all
      cached = Leaderboard.fetch(period: :daily, date: Date.current)
      assert_equal board.id, cached.id
    end
  end

  test "fetch accepts string period and date" do
    Leaderboard.create!(
      start_date: Date.new(2024, 3, 20),
      period_type: :last_7_days,
      finished_generating_at: Time.current
    )

    fetched = Leaderboard.fetch(period: "last_7_days", date: "2024-03-20")
    refute_nil fetched
    assert_equal "last_7_days", fetched.period_type
  end

  test "regenerate creates a board when none exists" do
    travel_to Time.zone.local(2024, 3, 20, 12) do
      board = Leaderboard.regenerate(period: :daily, date: Date.current, force: true)
      assert board.persisted?
      assert board.finished_generating?
      assert_equal "daily", board.period_type
    end
  end

  test "regenerate is a no-op for an already-finished board unless forced" do
    board = Leaderboard.create!(
      start_date: Date.current,
      period_type: :daily,
      finished_generating_at: 1.hour.ago
    )
    finished_at = board.finished_generating_at

    Leaderboard.regenerate(period: :daily, date: Date.current)
    assert_equal finished_at.to_i, board.reload.finished_generating_at.to_i
  end

  private

  def with_memory_cache
    original = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new
    yield
  ensure
    Rails.cache = original
  end
end

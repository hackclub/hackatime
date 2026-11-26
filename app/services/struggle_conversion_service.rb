# Atomically converts a user's unconverted Struggle Windows (SP) into verified Struggle Hours
# using Option A (Per-Window Exact Cap: credited_seconds <= convertible_seconds <= raw_seconds).
#
# Uses PostgreSQL row-level locking (`FOR UPDATE`) so each window can only ever be converted once.
# Accounts for existing heartbeat intervals before marking points as spent so converted
# `"struggle point time"` heartbeats never collide with or lose credit to existing activity.
class StruggleConversionService
  STRUGGLE_HEARTBEAT_CATEGORY = "struggle point time".freeze
  HEARTBEAT_STEP_SECONDS = 60
  WINDOW_DURATION_SECONDS = 300.0
  BOUNDARY_EPSILON = 0.001

  Result = Data.define(:conversion, :converted_count, :error) do
    def success? = error.nil?
  end

  def self.call(user:, project_hash: nil, window_ids: nil)
    new(user: user, project_hash: project_hash, window_ids: window_ids).call
  end

  def initialize(user:, project_hash: nil, window_ids: nil)
    @user = user
    @project_hash = project_hash.presence
    @window_ids = Array(window_ids).map(&:to_i).select(&:positive?).presence
  end

  def call
    conversion = nil
    count = 0
    credited_heartbeats = false

    ActiveRecord::Base.transaction do
      scope = @user.struggle_windows.unconverted.lock("FOR UPDATE")
      scope = scope.where(project_hash: @project_hash) if @project_hash
      scope = scope.where(id: @window_ids) if @window_ids

      windows = scope.order(:window_start).to_a
      if windows.empty?
        return Result.new(conversion: nil, converted_count: 0, error: "No unconverted Struggle Points found.")
      end

      now = Time.current
      timeout = Heartbeat.heartbeat_timeout_duration.to_i
      allocations = plan_window_allocations(windows: windows, timeout: timeout)

      total_sp = windows.sum { |w| w.struggle_points.to_d }
      total_raw = windows.sum(&:raw_seconds)
      total_credited = allocations.sum { |a| a[:credited_seconds] }
      distinct_hashes = windows.map(&:project_hash).uniq
      single_hash = distinct_hashes.size == 1 ? distinct_hashes.first : nil
      single_name = single_hash ? windows.find { |w| w.project_name.present? }&.project_name : "All Projects"

      conversion = @user.struggle_conversions.create!(
        project_hash: single_hash,
        project_name: single_name,
        windows_count: windows.size,
        total_sp_converted: total_sp,
        total_raw_seconds: total_raw,
        total_credited_seconds: total_credited,
        converted_at: now
      )

      allocations.each do |alloc|
        alloc[:window].update!(
          credited_seconds: alloc[:credited_seconds],
          converted_at: now,
          struggle_conversion_id: conversion.id
        )
      end

      credited_heartbeats = insert_allocated_heartbeats!(
        conversion: conversion,
        allocations: allocations,
        now: now
      )
      count = windows.size
    end

    refresh_dashboard_immediately! if credited_heartbeats

    Result.new(conversion: conversion, converted_count: count, error: nil)
  end

  private

  def plan_window_allocations(windows:, timeout:)
    timeline = existing_timeline_for(windows)

    windows.map do |window|
      desired = window.convertible_seconds.to_i
      if desired <= 0
        { window: window, credited_seconds: 0, timestamps: [] }
      else
        w_start = window.window_start.to_f
        w_end = w_start + WINDOW_DURATION_SECONDS
        allocated = allocate_window_timestamps(
          window_start: w_start,
          window_end: w_end,
          desired: desired,
          timeline: timeline,
          timeout: timeout
        )
        unless allocated[:timestamps].empty?
          timeline.concat(allocated[:timestamps])
          timeline.sort!
        end
        allocated.merge(window: window)
      end
    end
  end

  def existing_timeline_for(windows)
    min_start = windows.first.window_start.to_f
    max_end = windows.last.window_start.to_f + WINDOW_DURATION_SECONDS
    base = @user.heartbeats.with_valid_timestamps

    in_range = base.where(time: min_start..max_end).order(time: :asc).pluck(:time).map(&:to_f)
    before_min = base.where("time < ?", min_start).maximum(:time)&.to_f
    after_max = base.where("time > ?", max_end).minimum(:time)&.to_f

    timeline = []
    timeline << before_min if before_min
    timeline.concat(in_range)
    timeline << after_max if after_max
    timeline.sort!
    timeline
  end

  # Computes exact non-overlapping heartbeat timestamps within [window_start, window_end]
  # so every credited second increases both total duration and "struggle point time"
  # without altering any existing heartbeat's LAG duration or category attribution.
  def allocate_window_timestamps(window_start:, window_end:, desired:, timeline:, timeout:)
    left_hb = nil
    right_hb = nil
    interior = []

    timeline.each do |ts|
      if ts <= window_start
        left_hb = ts
      elsif ts < window_end
        interior << ts
      else
        right_hb = ts
        break
      end
    end

    points = [ left_hb, *interior, right_hb ]
    remaining = desired
    timestamps = []

    (0...(points.size - 1)).each do |idx|
      break if remaining <= 0

      a = points[idx]
      b = points[idx + 1]
      gap_ts, gained = allocate_in_gap(
        a: a,
        b: b,
        window_start: window_start,
        window_end: window_end,
        remaining: remaining,
        timeout: timeout
      )
      next if gained <= 0 || gap_ts.empty?

      timestamps.concat(gap_ts)
      remaining -= gained
    end

    {
      timestamps: timestamps,
      credited_seconds: desired - remaining
    }
  end

  def allocate_in_gap(a:, b:, window_start:, window_end:, remaining:, timeout:)
    if a.nil? && b.nil?
      cap = (window_end - window_start).floor
      take = [ remaining, cap ].min
      return [ [], 0 ] if take <= 0

      [ step_chain(window_start, window_start + take, include_start: true), take ]
    elsif a.nil?
      # No prior heartbeat exists; right-align before b when b falls inside the window
      # so b does not gain unintended leading gap credit.
      upper = [ window_end, b - BOUNDARY_EPSILON ].min
      cap = ([ window_end, b ].min - window_start).floor
      take = [ remaining, cap ].min
      return [ [], 0 ] if take <= 0

      if b <= window_end
        s_end = b - BOUNDARY_EPSILON
        s_start = [ window_start, s_end - take ].max
        [ step_chain(s_start, s_end, include_start: true), take ]
      else
        s_end = [ window_start + take, upper ].min
        [ step_chain(window_start, s_end, include_start: true), take ]
      end
    elsif b.nil?
      allocate_after_anchor(a: a, hi: window_end, window_start: window_start, remaining: remaining, timeout: timeout)
    else
      # Gap (a, b) already credits min(b - a, timeout) to b. Keep last inserted timestamp
      # at least `timeout` before b so b's existing duration and category stay untouched.
      return [ [], 0 ] if (b - a) <= timeout

      hi = [ window_end, b - timeout.to_f ].min
      return [ [], 0 ] if hi <= a

      allocate_after_anchor(a: a, hi: hi, window_start: window_start, remaining: remaining, timeout: timeout)
    end
  end

  def allocate_after_anchor(a:, hi:, window_start:, remaining:, timeout:)
    if a < window_start
      return [ [], 0 ] if hi < window_start

      entry = [ window_start - a, timeout.to_f ].min
      if remaining < entry
        candidate = a + remaining
        return [ [ candidate ], remaining ] if candidate <= hi
        return [ [], 0 ]
      end

      max_cap = (entry + (hi - window_start)).floor
      take = [ remaining, max_cap ].min
      return [ [], 0 ] if take < entry.floor

      after_entry = [ take - entry, 0.0 ].max
      s_end = [ window_start + after_entry, hi ].min
      [ step_chain(window_start, s_end, include_start: true), take ]
    else
      cap = (hi - a).floor
      take = [ remaining, cap ].min
      return [ [], 0 ] if take <= 0

      [ step_chain(a, a + take, include_start: false), take ]
    end
  end

  def step_chain(start_ts, end_ts, include_start:)
    timestamps = include_start ? [ start_ts ] : []
    cursor = start_ts
    while cursor < end_ts
      cursor = [ cursor + HEARTBEAT_STEP_SECONDS, end_ts ].min
      timestamps << cursor
    end
    timestamps
  end

  def insert_allocated_heartbeats!(conversion:, allocations:, now:)
    last_os = @user.heartbeats.where.not(operating_system: [ nil, "" ]).order(time: :desc).limit(1).pick(:operating_system)
    source_type_val = Heartbeat.source_types.fetch("direct_entry")
    rows = []

    allocations.each do |alloc|
      next if alloc[:timestamps].empty?

      w = alloc[:window]
      project_name = w.project_name.presence || "project-#{w.project_hash.first(8)}"
      language = w.primary_language.presence || "Unknown"
      editor = w.ai_harness.presence || "hackatime-ai"
      entity = "struggle://#{project_name}/conversion-#{conversion.id}/window-#{w.id}"

      alloc[:timestamps].each do |ts|
        attrs = {
          "user_id" => @user.id,
          "branch" => nil,
          "category" => STRUGGLE_HEARTBEAT_CATEGORY,
          "dependencies" => [],
          "editor" => editor,
          "entity" => entity,
          "language" => language,
          "machine" => nil,
          "operating_system" => last_os,
          "project" => project_name,
          "type" => "app",
          "user_agent" => "hackatime-ai/0.1.0 struggle-conversion",
          "line_additions" => nil,
          "line_deletions" => nil,
          "lineno" => nil,
          "lines" => nil,
          "cursorpos" => nil,
          "project_root_count" => nil,
          "time" => ts.to_f,
          "is_write" => true
        }
        rows << attrs.merge(
          "source_type" => source_type_val,
          "fields_hash" => Heartbeat.generate_fields_hash(attrs),
          "created_at" => now,
          "updated_at" => now
        )
      end
    end

    return false if rows.empty?

    Heartbeat.insert_all!(rows)
    true
  end

  def refresh_dashboard_immediately!
    @user.touch
    DashboardRollupRefreshService.new(user: @user).call
  rescue StandardError => e
    Rails.logger.warn("StruggleConversionService rollup refresh fallback for user #{@user.id}: #{e.class}: #{e.message}")
    DashboardRollupRefreshJob.schedule_for(@user.id, wait: 0.seconds)
  end
end

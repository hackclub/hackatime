# Atomically converts a user's unconverted Struggle Windows (SP) into verified Struggle Hours
# using Option A (Per-Window Exact Cap: credited_seconds <= convertible_seconds <= raw_seconds).
#
# Uses PostgreSQL row-level locking (`FOR UPDATE`) so each window can only ever be converted once.
# Accounts for existing heartbeat intervals before marking points as spent, splits windows across
# local midnight without losing credit, and starts each converted segment with a `struggle_start`
# boundary heartbeat so preceding idle or overnight gaps never inflate totals.
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
    tz = ActiveSupport::TimeZone[@user.timezone] || Time.zone
    timeline = existing_timeline_for(windows)

    windows.map do |window|
      desired = window.convertible_seconds.to_i
      if desired <= 0
        { window: window, credited_seconds: 0, ticks: [] }
      else
        w_start = window.window_start.to_f
        w_end = w_start + WINDOW_DURATION_SECONDS
        remaining = desired
        ticks = []

        day_segments(w_start, w_end, tz: tz).each do |seg_start, seg_limit, emit_max|
          break if remaining <= 0

          allocated = allocate_segment_ticks(
            seg_start: seg_start,
            seg_limit: seg_limit,
            emit_max: emit_max,
            desired: remaining,
            timeline: timeline,
            timeout: timeout
          )
          next if allocated[:credited_seconds] <= 0 || allocated[:ticks].empty?

          ticks.concat(allocated[:ticks])
          timeline.concat(allocated[:ticks])
          timeline.sort_by! { |entry| entry[:time] }
          remaining -= allocated[:credited_seconds]
        end

        {
          window: window,
          credited_seconds: desired - remaining,
          ticks: ticks
        }
      end
    end
  end

  # Splits [w_start, w_end] at local midnight (including windows ending right at 00:00)
  # so every tick lands on the intended local day without losing credit in daily queries.
  def day_segments(w_start, w_end, tz:)
    segments = []
    cursor = w_start
    while cursor < w_end
      local_day = tz.at(cursor).to_date
      next_day_start = (local_day + 1).in_time_zone(tz).beginning_of_day.to_f
      if w_end >= next_day_start
        segments << [ cursor, next_day_start, next_day_start - BOUNDARY_EPSILON ]
        break if w_end == next_day_start

        cursor = next_day_start
      else
        segments << [ cursor, w_end, w_end ]
        break
      end
    end
    segments
  end

  def existing_timeline_for(windows)
    min_start = windows.first.window_start.to_f
    max_end = windows.last.window_start.to_f + WINDOW_DURATION_SECONDS
    base = @user.heartbeats.with_valid_timestamps

    in_range = base.where(time: min_start..max_end).order(time: :asc, id: :asc).pluck(:time, :type)
    before_min = base.where("time < ?", min_start).order(time: :desc, id: :desc).limit(1).pick(:time, :type)
    after_max = base.where("time > ?", max_end).order(time: :asc, id: :asc).limit(1).pick(:time, :type)

    timeline = []
    timeline << { time: before_min[0].to_f, type: before_min[1] } if before_min
    in_range.each { |ts, hb_type| timeline << { time: ts.to_f, type: hb_type } }
    timeline << { time: after_max[0].to_f, type: after_max[1] } if after_max
    timeline.sort_by! { |entry| entry[:time] }
    timeline
  end

  # Computes non-overlapping ticks within [seg_start, seg_limit] where each allocated span
  # begins with a `struggle_start` boundary heartbeat (0s leading gap) so neither prior
  # same-day gaps nor overnight gaps inflate totals, while preserving every existing heartbeat's gap.
  def allocate_segment_ticks(seg_start:, seg_limit:, emit_max:, desired:, timeline:, timeout:)
    left_hb = nil
    right_hb = nil
    interior = []

    timeline.each do |entry|
      ts = entry[:time]
      if ts <= seg_start
        left_hb = entry
      elsif ts < seg_limit
        interior << entry
      else
        right_hb = entry
        break
      end
    end

    points = [ left_hb, *interior, right_hb ]
    remaining = desired
    ticks = []

    (0...(points.size - 1)).each do |idx|
      break if remaining <= 0

      a = points[idx]
      b = points[idx + 1]
      gap_ticks, gained = allocate_in_gap(
        a: a,
        b: b,
        seg_start: seg_start,
        seg_limit: seg_limit,
        emit_max: emit_max,
        remaining: remaining,
        timeout: timeout
      )
      next if gained <= 0 || gap_ticks.empty?

      ticks.concat(gap_ticks)
      remaining -= gained
    end

    {
      ticks: ticks,
      credited_seconds: desired - remaining
    }
  end

  def allocate_in_gap(a:, b:, seg_start:, seg_limit:, emit_max:, remaining:, timeout:)
    a_time = a&.[](:time)
    b_time = b&.[](:time)
    b_is_start = b.present? && b[:type] == Heartbeat::STRUGGLE_START_TYPE

    if a_time.nil? && b_time.nil?
      cap = (seg_limit - seg_start).floor
      take = [ remaining, cap ].min
      return [ [], 0 ] if take <= 0

      s_end = [ seg_start + take, emit_max ].min
      [ build_segment_ticks(seg_start, s_end), take ]
    elsif a_time.nil?
      hi_limit = [ seg_limit, b_time ].min
      cap = (hi_limit - seg_start).floor
      take = [ remaining, cap ].min
      return [ [], 0 ] if take <= 0

      if !b_is_start && b_time <= seg_limit
        # Right-align before an existing ordinary heartbeat inside this segment
        # so it does not gain unintended leading gap credit.
        s_end = [ b_time - BOUNDARY_EPSILON, emit_max ].min
        s_start = [ seg_start, s_end - take ].max
        [ build_segment_ticks(s_start, s_end), take ]
      else
        s_end = [ seg_start + take, emit_max, b_time - BOUNDARY_EPSILON ].min
        [ build_segment_ticks(seg_start, s_end), take ]
      end
    elsif b_time.nil?
      lo_limit = [ seg_start, a_time ].max
      cap = (seg_limit - lo_limit).floor
      take = [ remaining, cap ].min
      return [ [], 0 ] if take <= 0

      s_start = a_time >= seg_start ? a_time + BOUNDARY_EPSILON : seg_start
      s_end = [ lo_limit + take, emit_max ].min
      [ build_segment_ticks(s_start, s_end), take ]
    elsif b_is_start
      # A following `struggle_start` receives 0 incoming seconds, so no timeout
      # buffer needs to be reserved before it when converting an earlier window.
      lo_limit = [ seg_start, a_time ].max
      hi_limit = [ seg_limit, b_time ].min
      cap = (hi_limit - lo_limit).floor
      take = [ remaining, cap ].min
      return [ [], 0 ] if take <= 0

      s_start = a_time >= seg_start ? a_time + BOUNDARY_EPSILON : seg_start
      s_end = [ lo_limit + take, emit_max, b_time - BOUNDARY_EPSILON ].min
      [ build_segment_ticks(s_start, s_end), take ]
    else
      # Gap (a, b) already credits min(b - a, timeout) to ordinary heartbeat b. Keep the last
      # inserted tick at least `timeout` before b so b's existing duration and category stay untouched.
      return [ [], 0 ] if (b_time - a_time) <= timeout

      lo_limit = [ seg_start, a_time ].max
      hi_limit = [ seg_limit, b_time - timeout.to_f ].min
      cap = (hi_limit - lo_limit).floor
      take = [ remaining, cap ].min
      return [ [], 0 ] if take <= 0

      s_start = a_time >= seg_start ? a_time + BOUNDARY_EPSILON : seg_start
      s_end = [ lo_limit + take, hi_limit, emit_max ].min
      [ build_segment_ticks(s_start, s_end), take ]
    end
  end

  def build_segment_ticks(start_ts, end_ts)
    return [] if end_ts <= start_ts

    ticks = [ { time: start_ts, type: Heartbeat::STRUGGLE_START_TYPE } ]
    cursor = start_ts
    while cursor < end_ts
      cursor = [ cursor + HEARTBEAT_STEP_SECONDS, end_ts ].min
      ticks << { time: cursor, type: "app" }
    end
    ticks
  end

  def insert_allocated_heartbeats!(conversion:, allocations:, now:)
    last_os = @user.heartbeats.where.not(operating_system: [ nil, "" ]).order(time: :desc).limit(1).pick(:operating_system)
    source_type_val = Heartbeat.source_types.fetch("direct_entry")
    rows = []

    allocations.each do |alloc|
      next if alloc[:ticks].empty?

      w = alloc[:window]
      project_name = w.project_name.presence || "project-#{w.project_hash.first(8)}"
      language = w.primary_language.presence || "Unknown"
      editor = w.ai_harness.presence || "hackatime-ai"
      entity = "struggle://#{project_name}/conversion-#{conversion.id}/window-#{w.id}"

      alloc[:ticks].each do |tick|
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
          "type" => tick[:type],
          "user_agent" => "hackatime-ai/0.1.0 struggle-conversion",
          "line_additions" => nil,
          "line_deletions" => nil,
          "lineno" => nil,
          "lines" => nil,
          "cursorpos" => nil,
          "project_root_count" => nil,
          "time" => tick[:time].to_f,
          "is_write" => tick[:type] != Heartbeat::STRUGGLE_START_TYPE
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

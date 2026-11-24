# Atomically converts a user's unconverted Struggle Windows (SP) into verified Struggle Hours
# using Option A (Per-Window Exact Cap: credited_seconds = convertible_seconds <= raw_seconds).
#
# Uses PostgreSQL row-level locking (`FOR UPDATE`) so each window can only ever be converted once.
# Credits the verified duration directly into the user's main Hackatime timeline (`heartbeats`)
# under the `"struggle point time"` category and refreshes their dashboard rollups immediately.
class StruggleConversionService
  STRUGGLE_HEARTBEAT_CATEGORY = "struggle point time".freeze
  HEARTBEAT_STEP_SECONDS = 60

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
      total_sp = windows.sum { |w| w.struggle_points.to_d }
      total_raw = windows.sum(&:raw_seconds)
      total_credited = windows.sum(&:convertible_seconds)
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

      # Atomically lock & credit each window with its exact per-window capped convertible_seconds
      @user.struggle_windows
        .where(id: windows.map(&:id), converted_at: nil)
        .update_all(
          [
            "credited_seconds = convertible_seconds, converted_at = ?, struggle_conversion_id = ?, updated_at = ?",
            now,
            conversion.id,
            now
          ]
        )

      credited_heartbeats = credit_dashboard_heartbeats!(conversion: conversion, windows: windows, now: now)
      count = windows.size
    end

    refresh_dashboard_immediately! if credited_heartbeats

    Result.new(conversion: conversion, converted_count: count, error: nil)
  end

  private

  def credit_dashboard_heartbeats!(conversion:, windows:, now:)
    creditable = windows.select { |w| w.convertible_seconds.to_i.positive? }
    return false if creditable.empty?

    tz = ActiveSupport::TimeZone[@user.timezone] || Time.zone
    last_os = @user.heartbeats.where.not(operating_system: [ nil, "" ]).order(time: :desc).limit(1).pick(:operating_system)
    source_type_val = Heartbeat.source_types.fetch("direct_entry")
    timeout = Heartbeat.heartbeat_timeout_duration.to_i
    inserted_any = false

    grouped = creditable.group_by do |w|
      proj = w.project_name.presence || "project-#{w.project_hash.first(8)}"
      local_date = tz.at(w.window_start.to_f).to_date
      [ proj, local_date ]
    end

    grouped.sort_by { |(_, _), group| group.first.window_start.to_f }.each do |(project_name, _local_date), group|
      credited_seconds = group.sum { |w| w.convertible_seconds.to_i }
      next if credited_seconds <= 0

      language = dominant_field(group, :primary_language, fallback: "Unknown")
      editor = dominant_field(group, :ai_harness, fallback: "hackatime-ai")
      entity = "struggle://#{project_name}/conversion-#{conversion.id}"

      first_start = group.first.window_start.to_f
      day_start = tz.at(first_start).beginning_of_day.to_f
      anchor = [ first_start, now.to_f - credited_seconds ].min
      anchor = [ anchor, day_start ].max

      prev_same_day = @user.heartbeats.where("time >= ? AND time <= ?", day_start, anchor).maximum(:time)
      timestamps = build_exact_timestamps(
        anchor: anchor,
        credited_seconds: credited_seconds,
        prev_same_day: prev_same_day,
        timeout: timeout
      )
      next if timestamps.empty?

      rows = timestamps.map do |ts|
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
        attrs.merge(
          "source_type" => source_type_val,
          "fields_hash" => Heartbeat.generate_fields_hash(attrs),
          "created_at" => now,
          "updated_at" => now
        )
      end

      Heartbeat.insert_all!(rows)
      inserted_any = true
    end

    inserted_any
  end

  def build_exact_timestamps(anchor:, credited_seconds:, prev_same_day:, timeout:)
    if prev_same_day
      entry_credit = [ anchor - prev_same_day, timeout.to_f ].min.round
      if credited_seconds <= entry_credit
        next_after_prev = @user.heartbeats.where("time > ?", prev_same_day).minimum(:time)
        candidate = prev_same_day + credited_seconds
        return [ candidate ] if next_after_prev.nil? || candidate < next_after_prev
        return [ anchor ]
      end
      remaining = credited_seconds - entry_credit
    else
      remaining = credited_seconds
    end

    timestamps = [ anchor ]
    cursor = anchor
    target_end = anchor + remaining
    while cursor < target_end
      cursor = [ cursor + HEARTBEAT_STEP_SECONDS, target_end ].min
      timestamps << cursor
    end
    timestamps
  end

  def dominant_field(group, attr, fallback:)
    totals = Hash.new(0)
    group.each do |w|
      val = w.public_send(attr).presence
      totals[val] += w.convertible_seconds.to_i if val
    end
    totals.max_by { |_, secs| secs }&.first || fallback
  end

  def refresh_dashboard_immediately!
    @user.touch
    DashboardRollupRefreshService.new(user: @user).call
  rescue StandardError => e
    Rails.logger.warn("StruggleConversionService rollup refresh fallback for user #{@user.id}: #{e.class}: #{e.message}")
    DashboardRollupRefreshJob.schedule_for(@user.id, wait: 0.seconds)
  end
end

# Atomically converts a user's unconverted Struggle Windows (SP) into verified Struggle Hours
# using Option A (Per-Window Exact Cap: credited_seconds = convertible_seconds <= raw_seconds).
#
# Uses PostgreSQL row-level locking (`FOR UPDATE`) so each window can only ever be converted once.
class StruggleConversionService
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

      count = windows.size
    end

    Result.new(conversion: conversion, converted_count: count, error: nil)
  end
end

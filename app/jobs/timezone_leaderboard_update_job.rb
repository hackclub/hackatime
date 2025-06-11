class TimezoneLeaderboardUpdateJob < ApplicationJob
  queue_as :latency_10s

  include GoodJob::ActiveJobExtensions::Concurrency

  # Limits concurrency to 1 job per date
  good_job_control_concurrency_with(
    key: -> { "timezone_daily_#{arguments[0] || Date.current.to_s}" },
    total: 1,
    drop: true
  )

  def perform(date = Date.current)
    parsed_date = date.is_a?(Date) ? date : Date.parse(date.to_s)

    leaderboard = Leaderboard.create!(
      start_date: parsed_date,
      period_type: :daily_timezone_normalized
    )

    Rails.logger.info "Starting timezone-normalized leaderboard generation for #{parsed_date}"

    ActiveRecord::Base.transaction do
      # Get all unique timezones
      timezones = User.where.not(timezone: nil).distinct.pluck(:timezone)
      entries_data = []

      timezones.each do |timezone|
        # Calculate the date range for this timezone
        timezone_date_range = Time.use_zone(timezone) do
          parsed_date.in_time_zone(timezone).all_day
        end

        # Get all heartbeats for users in this timezone during their local day
        timezone_heartbeats = Heartbeat.joins(:user)
                                      .where(users: { timezone: timezone })
                                      .where(time: timezone_date_range)
                                      .coding_only
                                      .with_valid_timestamps
                                      .where.not(users: { github_uid: nil })

        # Group by user and calculate totals
        user_totals = timezone_heartbeats.group(:user_id).duration_seconds
        user_totals = user_totals.filter { |_, total_seconds| total_seconds > 60 }

        # Get streaks for all users at once
        user_ids = user_totals.keys
        streaks = Heartbeat.daily_streaks_for_users(user_ids) if user_ids.any?

        # Build entries data
        user_totals.each do |user_id, total_seconds|
          entries_data << {
            leaderboard_id: leaderboard.id,
            user_id: user_id,
            total_seconds: total_seconds,
            streak_count: streaks[user_id] || 0
          }
        end
      end

      LeaderboardEntry.insert_all!(entries_data) if entries_data.any?
    end

    leaderboard.finished_generating_at = Time.current
    leaderboard.save!

    # Clean up old timezone-normalized leaderboards for this date
    Leaderboard.where.not(id: leaderboard.id)
               .where(start_date: parsed_date, period_type: :daily_timezone_normalized)
               .where(deleted_at: nil)
               .update_all(deleted_at: Time.current)

    leaderboard
  rescue => e
    Rails.logger.error "Failed to update timezone-normalized leaderboard: #{e.message}"
    raise
  rescue Date::Error
    raise ArgumentError, "Invalid date format provided"
  end
end

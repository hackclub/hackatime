class LeaderboardUpdateJob < ApplicationJob
  queue_as :default
  BATCH_SIZE = 100

  include GoodJob::ActiveJobExtensions::Concurrency

  # Limits concurrency to 1 job per date
  good_job_control_concurrency_with(
    key: -> { "#{arguments[0] || Date.current.to_s}_#{arguments[1] || 'daily'}" },
    total: 1,
    drop: true
  )

  def perform(date = Date.current, period_type = :daily)
    parsed_date = date.is_a?(Date) ? date : Date.parse(date.to_s)
    period_type = period_type.to_sym

    if period_type == :weekly
      parsed_date = parsed_date.beginning_of_week
    end

    leaderboard = Leaderboard.create!(
      start_date: parsed_date,
      period_type: period_type
    )

    # Get list of valid user IDs from our database
    valid_user_ids = User.pluck(:id)
    return if valid_user_ids.empty?

    date_range = if period_type == :weekly
      (parsed_date.beginning_of_day...(parsed_date + 7.days).beginning_of_day)
    else
      parsed_date.all_day
    end

    ActiveRecord::Base.transaction do
      valid_user_ids.each_slice(BATCH_SIZE) do |batch_user_ids|
        entries_data = Heartbeat.where(user_id: batch_user_ids)
                                .where(time: date_range)
                                .group(:user_id)
                                .duration_seconds

        entries_data = entries_data.filter { |_, total_seconds| total_seconds > 60 }

        entries_data = entries_data.map do |user_id, total_seconds|
          {
            leaderboard_id: leaderboard.id,
            user_id: user_id,
            total_seconds: total_seconds
          }
        end

        # Batch insert new entries for this batch
        LeaderboardEntry.insert_all!(entries_data) if entries_data.any?
      end
    end

    # Set finished_generating_at after successful completion
    leaderboard.finished_generating_at = Time.current
    leaderboard.save!

    Leaderboard.where.not(id: leaderboard.id)
               .where(start_date: parsed_date, period_type: period_type)
               .where(deleted_at: nil)
               .update_all(deleted_at: Time.current)
  rescue => e
    Rails.logger.error "Failed to update current leaderboard: #{e.message}"
    raise
  rescue Date::Error
    raise ArgumentError, "Invalid date format provided"
  end
end

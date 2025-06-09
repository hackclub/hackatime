class CheckStreakPhysicalMailJob < ApplicationJob
  queue_as :literally_whenever

  include GoodJob::ActiveJobExtensions::Concurrency

  good_job_control_concurrency_with(
    total_limit: 1,
    key: -> { "check_streak_physical_mail_job" },
    drop: true
  )

  def perform
    streaks = Heartbeat.daily_streaks_for_users(users_with_recent_heartbeats)

    over_7_day_streaks = streaks.select { |_, streak| streak > 7 }.keys

    over_7_day_streaks.each do |user_id|
      next if PhysicalMail.going_out.exists?(user_id: user_id, mission_type: :first_time_7_streak)

      user = User.find(user_id)

      # Create the physical mail record
      PhysicalMail.create!(
        user: user,
        mission_type: :first_time_7_streak,
        status: :pending
      )
    end
  end

  private

  def users_with_recent_heartbeats
    Heartbeat.where(time: 1.hour.ago..Time.current)
             .distinct
             .pluck(:user_id)
  end
end

class Cache::SetupSocialProofJob < Cache::ActivityJob
  queue_as :latency_10s

  private

  def calculate
    # Only run queries as needed, starting with the smallest time range
    check_social_proof(5.minutes, 1, "in the last 5 minutes") ||
      check_social_proof(1.hour, 3, "in the last hour") ||
      check_social_proof(1.day, 5, "today") ||
      check_social_proof(1.week, 5, "in the past week") ||
      check_social_proof(1.month, 5, "in the past month") ||
      check_social_proof(1.year, 5, "in the past year")
  end

  def check_social_proof(time_period, threshold, humanized_time_period)
    user_ids = Heartbeat.where("time > ?", time_period.ago.to_f)
                        .where("time < ?", Time.current.to_f)
                        .with_valid_timestamps
                        .where(source_type: :test_entry)
                        .distinct
                        .pluck(:user_id)

    user_count = user_ids.size
    return nil if user_count < threshold

    recent_setup_users = User.where(id: user_ids).limit(5).map do |user|
      {
        id: user.id,
        avatar_url: user.avatar_url,
        display_name: user.display_name || "Hack Clubber"
      }
    end

    message = "#{user_count.to_s + ' Hack Clubber'.pluralize(user_count)} set up Hackatime #{humanized_time_period}"

    {
      message: message,
      users_size: user_count,
      users_recent: recent_setup_users
    }
  end
end

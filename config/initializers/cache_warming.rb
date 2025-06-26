# Schedule mini leaderboard cache warming
# This will run every 5 minutes to keep the cache warm
Rails.application.config.after_initialize do
  if defined?(Sidekiq::Cron::Job)
    Sidekiq::Cron::Job.create(
      name: "Warm Mini Leaderboard Cache",
      cron: "*/5 * * * *",
      class: "WarmMiniLeaderboardCacheJob"
    )
  end
end

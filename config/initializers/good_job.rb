Rails.application.configure do
  config.good_job.preserve_job_records = true
  config.good_job.cleanup_preserved_jobs_before_seconds_ago = 60 * 60 * 24 * 7
  config.good_job.cleanup_interval_jobs = 1000
  config.good_job.cleanup_interval_seconds = 3600

  if Rails.env.development?
    config.good_job.enable_listening = false
    config.good_job.poll_interval = -1 # Disable polling
    config.good_job.execution_mode = :inline # Run jobs inline in development
  else
    config.good_job.execution_mode = :external # Use external execution mode in production and staging
  end

  config.good_job.enable_cron = Rails.env.production?

  # https://github.com/bensheldon/good_job#configuring-your-queues
  # 12 threads total
  config.good_job.queues = "latency_10s:4; latency_5m,latency_10s:3; literally_whenever,*,latency_5m,latency_10s:5"

  #  https://github.com/bensheldon/good_job#pgbouncer-compatibility
  GoodJob.active_record_parent_class = "ApplicationDirectRecord"

  config.good_job.cron = {
    # update_slack_status: {
    #   cron: "*/5 * * * *",
    #   class: "UserSlackStatusUpdateJob"
    # },
    daily_leaderboard_update: {
      cron: "* * * * *",
      class: "LeaderboardUpdateJob",
      args: [ :daily ],
      kwargs: { force_update: true }
    },
    weekly_leaderboard_update: {
      cron: "*/2 * * * *",
      class: "LeaderboardUpdateJob",
      args: [ :weekly ],
      kwargs: { force_update: true }
    },
    slack_activity_digest_scheduler: {
      cron: "15 * * * *",
      class: "SlackActivityDigestSchedulerJob"
    },
    last_7_days_leaderboard_update: {
      cron: "*/7 * * * *",
      class: "LeaderboardUpdateJob",
      args: [ :last_7_days ],
      kwargs: { force_update: true }
    },
    # sailors_log_poll: {
    #   cron: "*/2 * * * *",
    #   class: "SailorsLogPollForChangesJob"
    # },
    # update_slack_channel_cache: {
    #   cron: "0 11 * * *",
    #   class: "SlackCommand::UpdateSlackChannelCacheJob"
    # },
    # update_slack_neighborhood_channels: {
    #   cron: "0 12 * * *",
    #   class: "UpdateSlackNeighborhoodChannelsJob"
    # },
    # slack_username_update: {
    #   cron: "0 0 * * *",
    #   class: "SlackUsernameUpdateJob"
    # },
    # scan_github_repos: {
    #   cron: "0 10 * * *",
    #   class: "ScanGithubReposJob"
    # },
    # sync_all_user_repo_events: {
    #   cron: "0 */6 * * *", # Every 6 hours (at minute 0 of 0, 6, 12, 18 hours)
    #   class: "SyncAllUserRepoEventsJob",
    #   description: "Periodically syncs repository events for all eligible users."
    # },
    # scan_repo_events_for_commits: {
    #   cron: "0 */3 * * *", # Every 3 hours at minute 0
    #   class: "ScanRepoEventsForCommitsJob",
    #   description: "Scans repository host events (PushEvents) and enqueues jobs to process new commits."
    # },
    # cleanup_expired_email_verification_requests: {
    #   cron: "* * * * *",
    #   class: "CleanupExpiredEmailVerificationRequestsJob"
    # },
    # update_airtable_user_data: {
    #   cron: "0 13 * * *",
    #   class: "UpdateAirtableUserDataJob"
    # },
    cache_active_user_graph_data_job: {
      cron: "*/10 * * * *",
      class: "Cache::ActiveUsersGraphDataJob",
      kwargs: { force_reload: true }
    },
    cache_currently_hacking: {
      cron: "* * * * *",
      class: "Cache::CurrentlyHackingJob",
      kwargs: { force_reload: true }
    },
    cache_home_stats: {
      cron: "*/10 * * * *",
      class: "Cache::HomeStatsJob",
      kwargs: { force_reload: true }
    },
    cache_active_projects: {
      cron: "* * * * *",
      class: "Cache::ActiveProjectsJob",
      kwargs: { force_reload: true }
    },
    cache_usage_social_proof: {
      cron: "* * * * *",
      class: "Cache::UsageSocialProofJob",
      kwargs: { force_reload: true }
    },
    cache_setup_social_proof: {
      cron: "* * * * *",
      class: "Cache::SetupSocialProofJob",
      kwargs: { force_reload: true }
    },
    cache_minutes_logged: {
      cron: "* * * * *",
      class: "Cache::MinutesLoggedJob",
      kwargs: { force_reload: true }
    },
    cache_heartbeat_counts: {
      cron: "* * * * *",
      class: "Cache::HeartbeatCountsJob",
      kwargs: { force_reload: true }
    },
    check_streak_physical_mail: {
      cron: "0 * * * *", # Run before AttemptToDeliverPhysicalMailJob
      class: "CheckStreakPhysicalMailJob"
    },
    attempt_to_deliver_physical_mail: {
      cron: "5 * * * *", # Run after physical mail is created
      class: "AttemptToDeliverPhysicalMailJob"
    },
    # geocode_users_without_country: {
    #   cron: "7 * * * *",
    #   class: "GeocodeUsersWithoutCountryJob"
    # },
    cleanup_successful_jobs: {
      cron: "0 0 * * *",
      class: "CleanupSuccessfulJobsJob"
    }
    # sync_stale_repo_metadata: {
    #   cron: "0 4 * * *", # Daily at 4 AM
    #   class: "SyncStaleRepoMetadataJob",
    #   description: "Refreshes repository metadata (stars, commit counts, etc.) for repositories with stale data."
    # },
    # cleanup_old_leaderboards: {
    #   cron: "0 3 * * *", # daily at 3
    #   class: "CleanupOldLeaderboardsJob",
    #   description: "Remove leaderboards older than 2 days"
    # }
  }
end

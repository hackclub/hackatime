class SailorsLogPollForChangesJob < ApplicationJob
  queue_as :latency_10s

  include GoodJob::ActiveJobExtensions::Concurrency

  good_job_control_concurrency_with(
    total_limit: 1,
    key: -> { "sailors_log_poll_for_changes_job" },
    drop: true
  )

  def perform
    users_who_coded = Heartbeat.with_valid_timestamps
                               .where(time: 10.minutes.ago..)
                               .distinct.pluck(:user_id)

    slack_uids = User.where(id: users_who_coded).pluck(:slack_uid)

    new_notifs = SailorsLog.includes(:user, :notification_preferences)
                           .where(notification_preferences: { enabled: true })
                           .where(slack_uid: slack_uids)
                           .map { |sl| update_sailors_log(sl) }.flatten

    notifs_to_send = SailorsLogSlackNotification.insert_all(new_notifs)
    notif_ids = notifs_to_send.result.to_a.map { |r| r["id"] }

    SailorsLogSlackNotification.where(id: notif_ids).map(&:notify_user!)
  end

  private

  def update_sailors_log(sailors_log)
    # Skip if there's an active migration job for this user
    return [] if sailors_log.user.in_progress_migration_jobs?

    project_updates = []
    project_durations = Heartbeat.where(user_id: sailors_log.user.id)
                                 .group(:project).duration_seconds
    project_durations.each do |k, v|
      old_duration = sailors_log.projects_summary[k] || 0
      new_duration = v
      if old_duration / 3600 < new_duration / 3600
        sailors_log.projects_summary[k] = new_duration
        project_updates << { project: k, duration: new_duration }
      end
    end

    notifications_to_create = []
    if sailors_log.changed?
      sailors_log.notification_preferences.each do |np|
        project_updates.each do |pu|
          next if pu[:project].blank?
          notifications_to_create << {
            slack_uid: sailors_log.user.slack_uid,
            slack_channel_id: np.slack_channel_id,
            project_name: pu[:project],
            project_duration: pu[:duration]
          }
        end
      end

      sailors_log.save!
    end

    notifications_to_create
  end
end

# optimizations?
# - index heartbeats on user_id + project so we can call duration_seconds grouping by both
# - investigate lookup by slack_uid, maybe index or computed field?

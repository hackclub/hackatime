class SailorsLogPollForChangesJob < ApplicationJob
  queue_as :latency_10s

  include GoodJob::ActiveJobExtensions::Concurrency

  good_job_control_concurrency_with(
    total_limit: 1, key: -> { "sailors_log_poll_for_changes_job" }
  )

  IGNORED_PROJECTS = [ "<<LAST_PROJECT>>", "Unknown" ].freeze

  def perform
    users_who_coded = Clickhouse::Heartbeat.with_valid_timestamps
                                           .where(time: 10.minutes.ago.to_f..)
                                           .distinct.pluck(:user_id)
    slack_uids = User.where(id: users_who_coded).pluck(:slack_uid)

    sailors_logs = SailorsLog.includes(:user, :notification_preferences)
                             .where(notification_preferences: { enabled: true })
                             .where(slack_uid: slack_uids)
                             .to_a
    durations_by_user = Clickhouse::Heartbeat.project_durations_for_users(sailors_logs.map { |sl| sl.user.id })

    new_notifs = sailors_logs.flat_map { |sl| update_sailors_log(sl, durations_by_user[sl.user.id] || {}) }

    notifs_to_send = SailorsLogSlackNotification.insert_all(new_notifs)
    notif_ids = notifs_to_send.result.to_a.map { |r| r["id"] }
    SailorsLogSlackNotification.where(id: notif_ids).map(&:notify_user!)
  end

  private

  def update_sailors_log(sailors_log, project_durations)
    return [] if sailors_log.user.active_remote_heartbeat_import_run?

    project_updates = []
    project_durations.each do |k, v|
      next if ignored_project?(k)
      old_duration = sailors_log.projects_summary[k] || 0
      next unless old_duration / 3600 < v / 3600
      sailors_log.projects_summary[k] = v
      project_updates << { project: k, duration: v }
    end

    notifications = []
    if sailors_log.changed?
      sailors_log.notification_preferences.each do |np|
        project_updates.each do |pu|
          next if ignored_project?(pu[:project])
          notifications << {
            slack_uid: sailors_log.user.slack_uid, slack_channel_id: np.slack_channel_id,
            project_name: pu[:project], project_duration: pu[:duration]
          }
        end
      end
      sailors_log.save!
    end

    notifications
  end

  def ignored_project?(project) = project.blank? || IGNORED_PROJECTS.include?(project)
end

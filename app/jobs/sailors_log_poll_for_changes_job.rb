class SailorsLogPollForChangesJob < ApplicationJob
  queue_as :latency_10s

  include GoodJob::ActiveJobExtensions::Concurrency

  good_job_control_concurrency_with(
    total_limit: 1, key: -> { "sailors_log_poll_for_changes_job" }
  )

  IGNORED_PROJECTS = [ "<<LAST_PROJECT>>", "Unknown" ].freeze

  def perform
    users_who_coded = Heartbeat.with_valid_timestamps.where(time: 10.minutes.ago..).distinct.pluck(:user_id)
    slack_uids = User.where(id: users_who_coded).pluck(:slack_uid)

    sailors_logs = SailorsLog.includes(:user, :notification_preferences)
      .where(notification_preferences: { enabled: true })
      .where(slack_uid: slack_uids).to_a
      .reject { |sailors_log| sailors_log.user.active_remote_heartbeat_import_run? }
    project_durations = project_durations_for(sailors_logs)
    new_notifs = sailors_logs.flat_map do |sailors_log|
      update_sailors_log(sailors_log, project_durations: project_durations[sailors_log.user.id])
    end

    notifs_to_send = SailorsLogSlackNotification.insert_all(new_notifs)
    notif_ids = notifs_to_send.result.to_a.map { |r| r["id"] }
    SailorsLogSlackNotification.where(id: notif_ids).map(&:notify_user!)
  end

  private

  def update_sailors_log(sailors_log, project_durations: nil)
    project_durations ||= begin
      DashboardRollup
        .where(user_id: sailors_log.user.id, dimension: "project", bucket_value_present: true)
        .pluck(:bucket_value, :total_seconds).to_h
    end

    if project_durations.empty?
      DashboardRollupRefreshJob.schedule_for(sailors_log.user.id, wait: 0.seconds)
      return []
    end

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

  def project_durations_for(sailors_logs)
    return {} unless HeartbeatRepository.clickhouse?

    user_ids = sailors_logs.map { |sailors_log| sailors_log.user.id }
    cache_keys = user_ids.index_with { |user_id| "sailors_log_project_durations:v1:#{user_id}" }
    cached = Rails.cache.read_multi(*cache_keys.values)
    uncached_ids = user_ids.reject { |user_id| cached.key?(cache_keys.fetch(user_id)) }
    fresh = uncached_ids.empty? ? {} : HeartbeatRepository.current.project_durations_by_user(uncached_ids)
    uncached_ids.each do |user_id|
      Rails.cache.write(cache_keys.fetch(user_id), fresh.fetch(user_id, {}), expires_in: 5.minutes)
    end
    durations = user_ids.to_h do |user_id|
      [ user_id, cached.fetch(cache_keys.fetch(user_id), fresh.fetch(user_id, {})) ]
    end
    archived = ProjectRepoMapping.archived.where(user_id: user_ids)
      .pluck(:user_id, :project_name).group_by(&:first)
    user_ids.index_with do |user_id|
      durations.fetch(user_id, {}).except(*archived.fetch(user_id, []).map(&:last))
    end
  end

  def ignored_project?(project) = project.blank? || IGNORED_PROJECTS.include?(project)
end

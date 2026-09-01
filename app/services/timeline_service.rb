class TimelineService
  MAX_TIMELINE_USERS = 20
  LEADERBOARD_USERS_LIMIT = 25
  SEARCH_USERS_LIMIT = 20
  LEADERBOARD_USER_SELECT_FIELDS = %i[id username slack_username github_username slack_avatar_url github_avatar_url display_name_override].freeze
  TIMEOUT_DURATION = 10.minutes.to_i

  attr_reader :date, :selected_user_ids

  class << self
    def for_selection(date:, current_user:, user_ids:, slack_uids:)
      requested_user_ids = user_ids.to_s.split(",").map(&:to_i).uniq.first(MAX_TIMELINE_USERS)
      requested_slack_uids = slack_uids.to_s.split(",").uniq.first(MAX_TIMELINE_USERS)
      user_ids_by_slack_uid = User.where(slack_uid: requested_slack_uids).pluck(:slack_uid, :id).to_h
      requested_user_ids.concat(requested_slack_uids.filter_map { |slack_uid| user_ids_by_slack_uid[slack_uid] })

      new(date: date, selected_user_ids: [ current_user.id, *requested_user_ids ])
    end

    def search_users(query)
      User.fuzzy_ranked_search(query, limit: SEARCH_USERS_LIMIT)
    end

    def leaderboard_users(current_user:, period:)
      leaderboard = Leaderboard.where.not(finished_generating_at: nil)
                               .find_by(start_date: Date.current,
                                        period_type: period == "last_7_days" ? :last_7_days : :daily,
                                        deleted_at: nil)
      leaderboard_user_ids = leaderboard ? leaderboard.entries.order(total_seconds: :desc).limit(LEADERBOARD_USERS_LIMIT).pluck(:user_id) : []
      ordered_user_ids = [ current_user.id, *leaderboard_user_ids ].uniq.first(LEADERBOARD_USERS_LIMIT)
      users_by_id = User.where(id: ordered_user_ids).select(*LEADERBOARD_USER_SELECT_FIELDS).preload(:email_addresses).index_by(&:id)

      ordered_user_ids.filter_map { |user_id| users_by_id[user_id] }
    end
  end

  def initialize(date:, selected_user_ids:)
    @date = date
    @selected_user_ids = selected_user_ids.uniq.first(MAX_TIMELINE_USERS)
  end

  def users
    @users ||= selected_user_ids.filter_map { |user_id| users_by_id[user_id] }
  end

  def users_by_id
    @users_by_id ||= User.where(id: selected_user_ids).preload(:email_addresses).index_by(&:id)
  end

  def timeline_data
    duration_cap = Heartbeat.heartbeat_timeout_duration.to_i
    users.map do |user|
      user_tz = user.timezone || "UTC"
      day_start = date.in_time_zone(user_tz).beginning_of_day.to_f
      day_end = date.in_time_zone(user_tz).end_of_day.to_f

      hbs = (heartbeats_by_user_id[user.id] || []).select { |hb| hb.time >= day_start && hb.time <= day_end }
      total_coded_time_seconds = hbs.each_cons(2).sum { |a, b| [ b.time - a.time, duration_cap ].min }.to_i

      { user: user, spans: calculate_spans(user, hbs), total_coded_time: total_coded_time_seconds }
    end
  end

  def commit_markers
    # Fetch a widened window, then filter to each user's local calendar day so
    # markers line up with the timezone the rest of the page is rendered in.
    window = (date.beginning_of_day - 24.hours)..(date.end_of_day + 24.hours)
    Commit.where(user_id: selected_user_ids, created_at: window).filter_map do |commit|
      raw = commit.github_raw || {}
      next if raw["html_url"].blank?

      commit_time = raw.dig("commit", "committer", "date") ? Time.zone.parse(raw["commit"]["committer"]["date"]) : commit.created_at
      user_tz = users_by_id[commit.user_id]&.timezone.presence || "UTC"
      next unless date.in_time_zone(user_tz).all_day.cover?(commit_time)

      {
        user_id: commit.user_id,
        timestamp: commit_time.to_f,
        additions: (raw["stats"] && raw["stats"]["additions"]) || raw.dig("files", 0, "additions"),
        deletions: (raw["stats"] && raw["stats"]["deletions"]) || raw.dig("files", 0, "deletions"),
        github_url: raw["html_url"]
      }
    end
  end

  private

  def mappings_by_user_project
    @mappings_by_user_project ||= ProjectRepoMapping.where(user_id: users_by_id.keys)
                                                    .group_by(&:user_id)
                                                    .transform_values { |mappings| mappings.index_by(&:project_name) }
  end

  def heartbeats_by_user_id
    @heartbeats_by_user_id ||= Heartbeat
      .where(user_id: users_by_id.keys, deleted_at: nil)
      .where("time >= ? AND time <= ?", date.beginning_of_day.to_f - 24.hours.to_i, date.end_of_day.to_f + 24.hours.to_i)
      .select(:id, :user_id, :time, :entity, :project, :editor, :language)
      .order(:user_id, :time).to_a.group_by(&:user_id)
  end

  def calculate_spans(user, heartbeats)
    return [] if heartbeats.empty?

    spans = []
    current = []

    heartbeats.each_with_index do |heartbeat, index|
      current << heartbeat
      is_last = (index == heartbeats.length - 1)
      time_to_next = is_last ? Float::INFINITY : (heartbeats[index + 1].time - heartbeat.time)

      next unless time_to_next > TIMEOUT_DURATION || is_last
      next if current.empty?

      start_time = current.first.time
      end_time = current.last.time

      projects_edited_details = current.map(&:project).compact.reject(&:blank?).uniq.map do |p_name|
        { name: p_name, repo_url: mappings_by_user_project.dig(user.id, p_name)&.repo_url }
      end

      spans << {
        start_time: start_time,
        end_time: end_time,
        duration: [ end_time - start_time, 0 ].max,
        files_edited: current.map { |h| h.entity&.split("/")&.last }.compact.uniq,
        projects_edited_details: projects_edited_details,
        editors: current.map(&:editor).compact.uniq,
        languages: current.map(&:language).compact.uniq
      }
      current = []
    end

    spans
  end
end

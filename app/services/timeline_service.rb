class TimelineService
  TIMEOUT_DURATION = 10.minutes.to_i

  attr_reader :date, :selected_user_ids

  def initialize(date:, selected_user_ids:)
    @date = date
    @selected_user_ids = selected_user_ids.uniq
  end

  def users_by_id
    @users_by_id ||= User.where(id: selected_user_ids).index_by(&:id)
  end

  def valid_user_ids
    @valid_user_ids ||= users_by_id.keys
  end

  def timeline_data
    users_to_process = valid_user_ids.map { |id| users_by_id[id] }.compact

    users_to_process.map do |user|
      user_tz = user.timezone || "UTC"
      user_start_of_day = date.in_time_zone(user_tz).beginning_of_day.to_f
      user_end_of_day = date.in_time_zone(user_tz).end_of_day.to_f

      total_coded_time_seconds = Heartbeat.where(user_id: user.id, deleted_at: nil)
                                          .where("time >= ? AND time <= ?", user_start_of_day, user_end_of_day)
                                          .duration_seconds

      user_heartbeats_for_spans = (heartbeats_by_user_id[user.id] || [])
        .select { |hb| hb.time >= user_start_of_day && hb.time <= user_end_of_day }

      spans = calculate_spans(user, user_heartbeats_for_spans)

      {
        user: user,
        spans: spans,
        total_coded_time: total_coded_time_seconds
      }
    end
  end

  def commit_markers
    commits = Commit.where(
      user_id: selected_user_ids,
      created_at: date.beginning_of_day..date.end_of_day
    )

    commits.map do |commit|
      raw = commit.github_raw || {}
      commit_time = if raw.dig("commit", "committer", "date")
        Time.parse(raw["commit"]["committer"]["date"])
      else
        commit.created_at
      end
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
    @mappings_by_user_project ||= ProjectRepoMapping.where(user_id: valid_user_ids)
                                                    .group_by(&:user_id)
                                                    .transform_values { |mappings| mappings.index_by(&:project_name) }
  end

  def heartbeats_by_user_id
    @heartbeats_by_user_id ||= begin
      server_start_of_day = date.beginning_of_day.to_f
      server_end_of_day = date.end_of_day.to_f
      expanded_start = server_start_of_day - 24.hours.to_i
      expanded_end = server_end_of_day + 24.hours.to_i

      Heartbeat
        .where(user_id: valid_user_ids, deleted_at: nil)
        .where("time >= ? AND time <= ?", expanded_start, expanded_end)
        .select(:id, :user_id, :time, :entity, :project, :editor, :language)
        .order(:user_id, :time)
        .to_a
        .group_by(&:user_id)
    end
  end

  def calculate_spans(user, heartbeats)
    return [] if heartbeats.empty?

    spans = []
    current_span_heartbeats = []

    heartbeats.each_with_index do |heartbeat, index|
      current_span_heartbeats << heartbeat
      is_last = (index == heartbeats.length - 1)
      time_to_next = is_last ? Float::INFINITY : (heartbeats[index + 1].time - heartbeat.time)

      if time_to_next > TIMEOUT_DURATION || is_last
        next unless current_span_heartbeats.any?

        start_time_numeric = current_span_heartbeats.first.time
        last_hb_time_numeric = current_span_heartbeats.last.time
        span_duration = [ last_hb_time_numeric - start_time_numeric, 0 ].max

        files = current_span_heartbeats.map { |h| h.entity&.split("/")&.last }.compact.uniq
        unique_projects = current_span_heartbeats.map(&:project).compact.reject(&:blank?).uniq

        projects_edited_details = unique_projects.map do |p_name|
          repo_mapping = mappings_by_user_project.dig(user.id, p_name)
          { name: p_name, repo_url: repo_mapping&.repo_url }
        end

        spans << {
          start_time: start_time_numeric,
          end_time: last_hb_time_numeric,
          duration: span_duration,
          files_edited: files,
          projects_edited_details: projects_edited_details,
          editors: current_span_heartbeats.map(&:editor).compact.uniq,
          languages: current_span_heartbeats.map(&:language).compact.uniq
        }
        current_span_heartbeats = []
      end
    end

    spans
  end
end

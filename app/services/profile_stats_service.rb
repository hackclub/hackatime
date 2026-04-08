class ProfileStatsService
  CACHE_TTL = 5.minutes

  attr_reader :user

  def initialize(user)
    @user = user
  end

  def stats
    Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) do
      compute_stats
    end
  end

  private

  def cache_key
    latest_heartbeat_time = user.heartbeats.maximum(:time) || 0
    "profile_stats:v2:user:#{user.id}:latest:#{latest_heartbeat_time}"
  end

  def compute_stats
    Time.use_zone(user.timezone) do
      timeout = Heartbeat.heartbeat_timeout_duration.to_i

      today_start = Time.current.beginning_of_day.to_i
      today_end = Time.current.end_of_day.to_i
      week_start = Time.current.beginning_of_week.to_i
      week_end = Time.current.end_of_week.to_i
      month_ago = 1.month.ago.to_f

      base_result = compute_totals_and_breakdowns(timeout, today_start, today_end, week_start, week_end, month_ago)

      {
        total_time_today: base_result[:today_seconds],
        total_time_week: base_result[:week_seconds],
        total_time_all: base_result[:all_seconds],
        top_languages: base_result[:top_languages],
        top_projects: base_result[:top_projects],
        top_projects_month: base_result[:top_projects_month],
        top_editors: base_result[:top_editors]
      }
    end
  end

  def compute_totals_and_breakdowns(timeout, today_start, today_end, week_start, week_end, month_ago)
    conn = Heartbeat.connection
    user_id = conn.quote(user.id)
    timeout_quoted = conn.quote(timeout)
    today_start_quoted = conn.quote(today_start)
    today_end_quoted = conn.quote(today_end)
    week_start_quoted = conn.quote(week_start)
    week_end_quoted = conn.quote(week_end)
    month_ago_quoted = conn.quote(month_ago)

    results = conn.select_one(<<~SQL)
      WITH heartbeat_diffs AS (
        SELECT
          time,
          project,
          language,
          editor,
          CASE
            WHEN LAG(time) OVER (ORDER BY time) IS NULL THEN 0
            ELSE LEAST(time - LAG(time) OVER (ORDER BY time), #{timeout_quoted})
          END AS diff
        FROM heartbeats
        WHERE user_id = #{user_id}
          AND deleted_at IS NULL
          AND time IS NOT NULL
          AND time >= 0 AND time <= 253402300799
      ),
      top_languages AS (
        SELECT language, COALESCE(SUM(diff), 0)::integer AS duration
        FROM heartbeat_diffs
        WHERE language IS NOT NULL AND language != ''
        GROUP BY language
        ORDER BY duration DESC
        LIMIT 5
      ),
      top_projects AS (
        SELECT project, COALESCE(SUM(diff), 0)::integer AS duration
        FROM heartbeat_diffs
        WHERE project IS NOT NULL AND project != ''
        GROUP BY project
        ORDER BY duration DESC
        LIMIT 5
      ),
      top_projects_month AS (
        SELECT project, COALESCE(SUM(diff), 0)::integer AS duration
        FROM heartbeat_diffs
        WHERE time >= #{month_ago_quoted}
          AND project IS NOT NULL AND project != ''
        GROUP BY project
        ORDER BY duration DESC
        LIMIT 6
      ),
      top_editors AS (
        SELECT editor, COALESCE(SUM(diff), 0)::integer AS duration
        FROM heartbeat_diffs
        WHERE editor IS NOT NULL AND editor != ''
        GROUP BY editor
        ORDER BY duration DESC
      )
      SELECT
        COALESCE(SUM(diff) FILTER (WHERE time >= #{today_start_quoted} AND time <= #{today_end_quoted}), 0)::integer AS today_seconds,
        COALESCE(SUM(diff) FILTER (WHERE time >= #{week_start_quoted} AND time <= #{week_end_quoted}), 0)::integer AS week_seconds,
        COALESCE(SUM(diff), 0)::integer AS all_seconds,
        COALESCE((SELECT jsonb_agg(jsonb_build_array(language, duration) ORDER BY duration DESC) FROM top_languages), '[]'::jsonb) AS top_languages,
        COALESCE((SELECT jsonb_agg(jsonb_build_array(project, duration) ORDER BY duration DESC) FROM top_projects), '[]'::jsonb) AS top_projects,
        COALESCE((SELECT jsonb_agg(jsonb_build_object('project', project, 'duration', duration) ORDER BY duration DESC) FROM top_projects_month), '[]'::jsonb) AS top_projects_month,
        COALESCE((SELECT jsonb_agg(jsonb_build_array(editor, duration) ORDER BY duration DESC) FROM top_editors), '[]'::jsonb) AS top_editors
      FROM heartbeat_diffs
    SQL

    top_languages = decode_duration_pairs(results["top_languages"])
    top_projects_all = decode_duration_pairs(results["top_projects"])
    top_editors = normalize_top_editors(decode_duration_pairs(results["top_editors"]))

    project_repo_mappings = user.project_repo_mappings.active.index_by(&:project_name)
    top_projects_month = decode_json(results["top_projects_month"]).map do |row|
      project = row["project"]
      mapping = project_repo_mappings[project]
      { project: project, duration: row["duration"].to_i, repo_url: mapping&.repo_url }
    end

    {
      today_seconds: results["today_seconds"].to_i,
      week_seconds: results["week_seconds"].to_i,
      all_seconds: results["all_seconds"].to_i,
      top_languages: top_languages,
      top_projects: top_projects_all,
      top_projects_month: top_projects_month,
      top_editors: top_editors
    }
  end

  def decode_json(value)
    parsed = value.is_a?(String) ? ActiveSupport::JSON.decode(value) : value
    parsed || []
  end

  def decode_duration_pairs(value)
    decode_json(value).each_with_object({}) do |(name, duration), result|
      result[name] = duration.to_i
    end
  end

  def normalize_top_editors(editor_durations)
    editor_durations.each_with_object(Hash.new(0)) do |(editor, duration), result|
      normalized = ApplicationController.helpers.display_editor_name(editor)
      result[normalized] += duration.to_i
    end.sort_by { |_, duration| -duration }.first(3).to_h
  end
end

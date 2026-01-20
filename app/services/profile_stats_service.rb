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

    base_sql = <<~SQL
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
      )
    SQL

    totals_sql = <<~SQL
      #{base_sql}
      SELECT
        COALESCE(SUM(diff) FILTER (WHERE time >= #{today_start_quoted} AND time <= #{today_end_quoted}), 0)::integer AS today_seconds,
        COALESCE(SUM(diff) FILTER (WHERE time >= #{week_start_quoted} AND time <= #{week_end_quoted}), 0)::integer AS week_seconds,
        COALESCE(SUM(diff), 0)::integer AS all_seconds
      FROM heartbeat_diffs
    SQL

    totals = conn.select_one(totals_sql)

    top_languages = fetch_top_grouped(conn, base_sql, "language", nil, 5)
    top_projects_all = fetch_top_grouped(conn, base_sql, "project", nil, 5)
    top_projects_month = fetch_top_grouped_with_repo(conn, base_sql, month_ago_quoted, 6)
    top_editors = fetch_top_editors_normalized(conn, base_sql, 3)

    {
      today_seconds: totals["today_seconds"].to_i,
      week_seconds: totals["week_seconds"].to_i,
      all_seconds: totals["all_seconds"].to_i,
      top_languages: top_languages,
      top_projects: top_projects_all,
      top_projects_month: top_projects_month,
      top_editors: top_editors
    }
  end

  def fetch_top_grouped(conn, base_sql, column, time_filter, limit)
    time_clause = time_filter ? "AND time >= #{time_filter}" : ""
    sql = <<~SQL
      #{base_sql}
      SELECT #{column}, COALESCE(SUM(diff), 0)::integer AS duration
      FROM heartbeat_diffs
      WHERE #{column} IS NOT NULL AND #{column} != ''
      #{time_clause}
      GROUP BY #{column}
      ORDER BY duration DESC
      LIMIT #{limit}
    SQL

    conn.select_all(sql).each_with_object({}) do |row, hash|
      hash[row[column]] = row["duration"].to_i
    end
  end

  def fetch_top_grouped_with_repo(conn, base_sql, month_ago, limit)
    sql = <<~SQL
      #{base_sql}
      SELECT project, COALESCE(SUM(diff), 0)::integer AS duration
      FROM heartbeat_diffs
      WHERE time >= #{month_ago}
        AND project IS NOT NULL AND project != ''
      GROUP BY project
      ORDER BY duration DESC
      LIMIT #{limit}
    SQL

    project_repo_mappings = user.project_repo_mappings.active.index_by(&:project_name)

    conn.select_all(sql).map do |row|
      project = row["project"]
      mapping = project_repo_mappings[project]
      { project: project, duration: row["duration"].to_i, repo_url: mapping&.repo_url }
    end
  end

  def fetch_top_editors_normalized(conn, base_sql, limit)
    sql = <<~SQL
      #{base_sql}
      SELECT editor, COALESCE(SUM(diff), 0)::integer AS duration
      FROM heartbeat_diffs
      WHERE editor IS NOT NULL AND editor != ''
      GROUP BY editor
      ORDER BY duration DESC
    SQL

    conn.select_all(sql).each_with_object(Hash.new(0)) do |row, acc|
      normalized = ApplicationController.helpers.display_editor_name(row["editor"])
      acc[normalized] += row["duration"].to_i
    end.sort_by { |_, v| -v }.first(limit).to_h
  end
end

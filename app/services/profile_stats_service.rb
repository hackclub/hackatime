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
    result = StatsClient.profile_stats(user_id: user.id, timezone: user.timezone)

    {
      total_time_today: result["today_seconds"].to_i,
      total_time_week: result["week_seconds"].to_i,
      total_time_all: result["all_seconds"].to_i,
      top_languages: result["top_languages"].to_h.transform_values(&:to_i),
      top_projects: result["top_projects"].to_h.transform_values(&:to_i),
      top_projects_month: attach_repo_urls(result["top_projects_month"] || []),
      top_editors: normalize_editors(result["top_editors"] || {})
    }
  end

  def attach_repo_urls(projects)
    project_repo_mappings = user.project_repo_mappings.active.index_by(&:project_name)

    Array(projects).map do |row|
      project = row["project"] || row[:project]
      duration = row["duration"] || row[:duration]
      mapping = project_repo_mappings[project]

      { project: project, duration: duration.to_i, repo_url: mapping&.repo_url }
    end
  end

  def normalize_editors(editors)
    editors.each_with_object(Hash.new(0)) do |(editor, duration), acc|
      normalized = ApplicationController.helpers.display_editor_name(editor)
      acc[normalized] += duration.to_i
    end.sort_by { |_, duration| -duration }.first(3).to_h
  end
end

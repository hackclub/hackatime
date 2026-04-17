class ProgrammingGoalsProgressService
  def initialize(user:, goals: nil, rollup_rows: nil)
    @user = user
    @goals = goals || user.goals.order(:created_at)
    @rollup_rows = rollup_rows
  end

  def call
    return [] if goals.blank?

    Time.use_zone(user.timezone.presence || "UTC") do
      now = Time.zone.now
      goals.map { |goal| build_progress(goal, now: now) }
    end
  end

  private

  attr_reader :user, :goals, :rollup_rows

  def build_progress(goal, now:)
    tracked_seconds = tracked_seconds_for_goal(goal, now: now)
    completion_percent = [ ((tracked_seconds.to_f / goal.target_seconds) * 100).round, 100 ].min
    time_window = time_window_for(goal.period, now: now)

    {
      id: goal.id.to_s,
      period: goal.period,
      target_seconds: goal.target_seconds,
      tracked_seconds: tracked_seconds,
      completion_percent: completion_percent,
      complete: tracked_seconds >= goal.target_seconds,
      languages: goal.languages,
      projects: goal.projects,
      period_end: time_window.end.iso8601
    }
  end

  def tracked_seconds_for_goal(goal, now:)
    rollup_tracked_seconds = tracked_seconds_from_rollup(goal)
    return rollup_tracked_seconds unless rollup_tracked_seconds.nil?

    time_window = time_window_for(goal.period, now: now)
    scope = user.heartbeats.where(time: time_window.begin.to_i..time_window.end.to_i)
    scope = scope.where(project: goal.projects) if goal.projects.any?

    if goal.languages.any?
      grouped_languages = languages_grouped_by_category(scope.distinct.pluck(:language))
      matching_languages = goal.languages.flat_map { |language| grouped_languages[language] }.compact_blank.uniq

      return 0 if matching_languages.empty?

      scope = scope.where(language: matching_languages)
    end

    scope.duration_seconds.to_i
  end

  def tracked_seconds_from_rollup(goal)
    return if rollup_rows.blank?
    return unless rollup_rows.any? { |row| row.dimension == DashboardRollupRefreshService::GOALS_PERIOD_TOTAL_DIMENSION }

    period_data = rollup_goals_data.fetch(goal.period, nil)
    return if period_data.nil?

    projects = goal.projects.compact_blank
    languages = goal.languages.compact_blank

    if projects.empty? && languages.empty?
      period_data.fetch(:total, 0)
    elsif projects.any? && languages.empty?
      projects.sum { |project| period_data.fetch(:project, {}).fetch(project, 0) }
    elsif languages.any? && projects.empty?
      languages.sum { |language| period_data.fetch(:language, {}).fetch(language, 0) }
    end
  end

  def rollup_goals_data
    return @rollup_goals_data if defined?(@rollup_goals_data)

    grouped = rollup_rows.group_by(&:dimension)
    totals = grouped.fetch(DashboardRollupRefreshService::GOALS_PERIOD_TOTAL_DIMENSION, [])
      .index_by(&:bucket)
      .transform_values { |row| row.total_seconds.to_i }

    project = grouped.fetch(DashboardRollupRefreshService::GOALS_PERIOD_PROJECT_DIMENSION, [])
      .each_with_object(Hash.new { |hash, key| hash[key] = {} }) do |row, acc|
        period, project_name = parse_rollup_bucket_pair(row.bucket_value)
        next if period.blank?

        acc[period][project_name] = row.total_seconds.to_i
      end

    language = grouped.fetch(DashboardRollupRefreshService::GOALS_PERIOD_LANGUAGE_DIMENSION, [])
      .each_with_object(Hash.new { |hash, key| hash[key] = {} }) do |row, acc|
        period, language_name = parse_rollup_bucket_pair(row.bucket_value)
        next if period.blank?

        acc[period][language_name] = row.total_seconds.to_i
      end

    @rollup_goals_data = DashboardRollupRefreshService::GOALS_PERIODS.each_with_object({}) do |period, data|
      data[period] = {
        total: totals.fetch(period, 0),
        project: project.fetch(period, {}),
        language: language.fetch(period, {})
      }
    end
  end

  def parse_rollup_bucket_pair(bucket)
    parsed = JSON.parse(bucket)
    return [ nil, nil ] unless parsed.is_a?(Array) && parsed.size == 2

    parsed
  rescue JSON::ParserError
    [ nil, nil ]
  end

  def languages_grouped_by_category(languages)
    languages.each_with_object(Hash.new { |hash, key| hash[key] = [] }) do |language, grouped|
      next if language.blank?

      categorized_language = language.categorize_language
      next if categorized_language.blank?

      grouped[categorized_language] << language
    end
  end

  def time_window_for(period, now:)
    case period
    when "day"
      now.beginning_of_day..now.end_of_day
    when "week"
      now.beginning_of_week(:monday)..now.end_of_week(:monday)
    when "month"
      now.beginning_of_month..now.end_of_month
    else
      now.beginning_of_day..now.end_of_day
    end
  end
end

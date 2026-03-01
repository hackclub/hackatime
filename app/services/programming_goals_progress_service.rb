class ProgrammingGoalsProgressService
  def initialize(user:, goals: nil)
    @user = user
    @goals = goals || user.goals.order(:created_at)
  end

  def call
    return [] if goals.blank?

    Time.use_zone(user.timezone.presence || "UTC") do
      now = Time.zone.now
      goals.map { |goal| build_progress(goal, now: now) }
    end
  end

  private

  attr_reader :user, :goals

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
    time_window = time_window_for(goal.period, now: now)
    scope = user.heartbeats.coding_only.where(time: time_window.begin.to_i..time_window.end.to_i)
    scope = scope.where(project: goal.projects) if goal.projects.any?

    if goal.languages.any?
      grouped_languages = languages_grouped_by_category(scope.distinct.pluck(:language))
      matching_languages = goal.languages.flat_map { |language| grouped_languages[language] }.compact_blank.uniq

      return 0 if matching_languages.empty?

      scope = scope.where(language: matching_languages)
    end

    scope.duration_seconds.to_i
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

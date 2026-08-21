class Goal < ApplicationRecord
  PERIODS = %w[day week month].freeze
  PERIOD_ADJECTIVES = { "day" => "daily", "week" => "weekly", "month" => "monthly" }.freeze
  PRESET_TARGET_SECONDS = [
    30.minutes.to_i,
    1.hour.to_i,
    2.hours.to_i,
    4.hours.to_i
  ].freeze
  MAX_TARGET_SECONDS_BY_PERIOD = {
    "day" => 24.hours.to_i,
    "week" => 7.days.to_i,
    "month" => 31.days.to_i
  }.freeze
  MAX_GOALS = 5

  # Fraction of the period that must elapse before an incomplete goal is
  # considered "about to miss" and the user gets warned.
  MISSED_WARNING_ELAPSED_FRACTION = 0.8

  scope :notifications_enabled, -> { where(notify_slack: true).or(where(notify_email: true)) }

  belongs_to :user

  before_validation :normalize_fields

  validates :period, inclusion: { in: PERIODS }
  validates :target_seconds, numericality: { only_integer: true, greater_than: 0 }
  validate :string_array_fields_valid
  validate :target_must_fit_within_period
  validate :max_goals_per_user
  validate :no_duplicate_goal_for_user

  def as_programming_goal_payload
    {
      id: id.to_s,
      period: period,
      target_seconds: target_seconds,
      languages: languages,
      projects: projects,
      notify_slack: notify_slack,
      notify_email: notify_email
    }
  end

  # The calendar window this goal's current period covers, in the user's timezone.
  def time_window(now: Time.current)
    self.class.time_window_for(period, now: now)
  end

  def notifications_enabled? = notify_slack? || notify_email?

  def period_adjective = PERIOD_ADJECTIVES.fetch(period, period)

  # Describes what the goal covers, e.g. "Rust coding goal for hackatime".
  def scope_description
    description = languages.any? ? "#{languages.join(", ")} coding goal" : "coding goal"
    description += " for #{projects.join(", ")}" if projects.any?
    description
  end

  # True when enough of the period has elapsed that the goal can no longer be
  # comfortably reached and tracked time is still short of the target.
  def about_to_miss?(now:, tracked_seconds:)
    return false if tracked_seconds >= target_seconds

    window = time_window(now: now)
    elapsed_fraction = ((now - window.begin).to_f / (window.end - window.begin)).clamp(0, 1)
    elapsed_fraction >= MISSED_WARNING_ELAPSED_FRACTION
  end

  def self.time_window_for(period, now:)
    case period
    when "week"
      now.beginning_of_week(:monday)..now.end_of_week(:monday)
    when "month"
      now.beginning_of_month..now.end_of_month
    else
      now.beginning_of_day..now.end_of_day
    end
  end

  private

  def normalize_fields
    self.period = period.to_s
    self.languages = Array(languages).map(&:to_s).compact_blank.uniq.sort
    self.projects = Array(projects).map(&:to_s).compact_blank.uniq.sort
  end

  def string_array_fields_valid
    { languages: languages, projects: projects }.each do |field, value|
      next if value.is_a?(Array) && value.all? { |v| v.is_a?(String) }

      errors.add(field, "must be an array of strings")
    end
  end

  def target_must_fit_within_period
    max_seconds = MAX_TARGET_SECONDS_BY_PERIOD[period]
    return if max_seconds.blank?
    return if target_seconds.to_i <= max_seconds

    errors.add(:target_seconds, "cannot exceed #{max_seconds / 3600} hours for a #{period} goal")
  end

  def max_goals_per_user
    return if user.blank?

    current_goal_count = user.goals.where.not(id: id).count
    return if current_goal_count < MAX_GOALS

    errors.add(:base, "cannot have more than #{MAX_GOALS} goals")
  end

  def no_duplicate_goal_for_user
    return if user.blank?

    duplicate_exists = user.goals
      .where.not(id: id)
      .exists?(period: period, target_seconds: target_seconds, languages: languages, projects: projects)

    return unless duplicate_exists

    errors.add(:base, "duplicate goal")
  end
end

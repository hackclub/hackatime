class Goal < ApplicationRecord
  PERIODS = %w[day week month].freeze
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

  belongs_to :user

  before_validation :normalize_fields

  validates :period, inclusion: { in: PERIODS }
  validates :target_seconds, numericality: { only_integer: true, greater_than: 0 }
  validate :languages_must_be_string_array
  validate :projects_must_be_string_array
  validate :target_must_fit_within_period
  validate :max_goals_per_user
  validate :no_duplicate_goal_for_user

  def as_programming_goal_payload
    {
      id: id.to_s,
      period: period,
      target_seconds: target_seconds,
      languages: languages,
      projects: projects
    }
  end

  private

  def normalize_fields
    self.period = period.to_s
    self.languages = Array(languages).map(&:to_s).compact_blank.uniq
    self.projects = Array(projects).map(&:to_s).compact_blank.uniq
  end

  def languages_must_be_string_array
    return if languages.is_a?(Array) && languages.all? { |language| language.is_a?(String) }

    errors.add(:languages, "must be an array of strings")
  end

  def projects_must_be_string_array
    return if projects.is_a?(Array) && projects.all? { |project| project.is_a?(String) }

    errors.add(:projects, "must be an array of strings")
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

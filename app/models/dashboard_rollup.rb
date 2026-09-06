class DashboardRollup < ApplicationRecord
  DIMENSIONS = %w[total project project_details language editor operating_system category weekly_project activity_graph today_stats filter_options coding_rhythm].freeze
  TOTAL_DIMENSION = "total".freeze
  PROJECT_DETAILS_DIMENSION = "project_details".freeze
  ACTIVITY_GRAPH_DIMENSION = "activity_graph".freeze
  TODAY_STATS_DIMENSION = "today_stats".freeze
  FILTER_OPTIONS_DIMENSION = "filter_options".freeze
  CODING_RHYTHM_DIMENSION = "coding_rhythm".freeze

  belongs_to :user

  validates :dimension, presence: true, inclusion: { in: DIMENSIONS }
  validates :total_seconds, numericality: { greater_than_or_equal_to: 0 }
  validates :bucket_value_present, inclusion: { in: [ true, false ] }
  validates :source_heartbeats_count, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true

  scope :for_dimension, ->(dimension) { where(dimension: dimension.to_s) }

  def total_dimension? = dimension == TOTAL_DIMENSION
  def bucket = bucket_value_present ? bucket_value : nil

  def self.generation(user_id) = User.where(id: user_id).pick(:dashboard_rollup_generation)

  def self.mark_dirty(user_id)
    User.where(id: user_id).update_all("dashboard_rollup_generation = dashboard_rollup_generation + 1")
  end

  def self.dirty?(user_id)
    current_generation = generation(user_id)
    return false unless current_generation

    payload = find_by(user_id: user_id, dimension: TOTAL_DIMENSION)&.payload
    payload&.fetch("source_generation", nil) != current_generation
  end
end

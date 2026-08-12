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

  def self.mark_dirty(user_id)
    User.where(id: user_id).update_all(
      "dashboard_rollup_generation = dashboard_rollup_generation + 1"
    ).positive?
  end

  def self.clear_dirty(user_id)
    User.where(id: user_id).update_all(
      "dashboard_rollup_refreshed_generation = dashboard_rollup_generation"
    )
  end

  def self.dirty?(user_id)
    User.where(id: user_id)
      .where("dashboard_rollup_generation > dashboard_rollup_refreshed_generation")
      .exists?
  end

  def self.generation(user_id)
    User.where(id: user_id).pick(:dashboard_rollup_generation)
  end

  def self.mark_refreshed(user_id, generation)
    User.where(id: user_id, dashboard_rollup_generation: generation)
      .update_all(dashboard_rollup_refreshed_generation: generation)
  end
end

class DashboardRollup < ApplicationRecord
  DIMENSIONS = %w[
    total
    project
    language
    editor
    operating_system
    category
    weekly_project
    daily_duration
    today_context
    today_total_duration
    today_language_count
    today_editor_count
    goals_period_total
    goals_period_project
    goals_period_language
  ].freeze
  TOTAL_DIMENSION = "total".freeze
  DIRTY_CACHE_KEY_PREFIX = "dashboard_rollup_dirty".freeze

  belongs_to :user

  validates :dimension, presence: true, inclusion: { in: DIMENSIONS }
  validates :total_seconds, numericality: { greater_than_or_equal_to: 0 }
  validates :bucket_value_present, inclusion: { in: [ true, false ] }
  validates :source_heartbeats_count, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true

  scope :for_dimension, ->(dimension) { where(dimension: dimension.to_s) }

  def total_dimension?
    dimension == TOTAL_DIMENSION
  end

  def bucket
    bucket_value_present ? bucket_value : nil
  end

  def self.dirty_cache_key(user_id)
    "#{DIRTY_CACHE_KEY_PREFIX}_#{user_id}"
  end

  def self.mark_dirty(user_id)
    Rails.cache.write(dirty_cache_key(user_id), true, expires_in: 1.day, unless_exist: true)
  end

  def self.clear_dirty(user_id)
    Rails.cache.delete(dirty_cache_key(user_id))
  end

  def self.dirty?(user_id)
    Rails.cache.exist?(dirty_cache_key(user_id))
  end
end

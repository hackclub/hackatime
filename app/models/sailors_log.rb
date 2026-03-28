class SailorsLog < ApplicationRecord
  validates :slack_uid, presence: true, uniqueness: true

  before_validation :initialize_projects_summary
  after_create :ensure_notification_preference_for_debug_channel

  belongs_to :user, foreign_key: :slack_uid, primary_key: :slack_uid

  has_many :notification_preferences,
           class_name: "SailorsLogNotificationPreference",
           foreign_key: :slack_uid,
           primary_key: :slack_uid

  has_many :notifications,
           class_name: "SailorsLogSlackNotification",
           foreign_key: :slack_uid,
           primary_key: :slack_uid

  DEFAULT_CHANNELS = %w[C0835AZP9GB]

  private

  def initialize_projects_summary
    return if projects_summary.present?
    self.projects_summary = StatsClient.duration_grouped(group_by: "project", user_id: user.id)["groups"] || {}
    self.projects_summary ||= {}
  end

  def ensure_notification_preference_for_debug_channel
    return if notification_preferences.any? { |np| SailorsLog::DEFAULT_CHANNELS.include?(np.slack_channel_id) && np.enabled }
    SailorsLog::DEFAULT_CHANNELS.each do |channel_id|
      notification_preferences.create!(slack_channel_id: channel_id, enabled: true)
    end
  end
end

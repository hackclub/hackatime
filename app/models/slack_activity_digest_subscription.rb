class SlackActivityDigestSubscription < ApplicationRecord
  TIMEZONE_NAMES = ActiveSupport::TimeZone.all.map(&:name).freeze

  belongs_to :created_by_user, class_name: "User", optional: true

  validates :slack_channel_id, presence: true, uniqueness: true
  validates :timezone, presence: true, inclusion: { in: TIMEZONE_NAMES }
  validates :delivery_hour, presence: true, inclusion: { in: 0..23 }

  scope :enabled, -> { where(enabled: true) }

  def due_for_delivery?(reference_time = Time.current)
    return false unless enabled?

    tz = active_time_zone
    local_reference = reference_time.in_time_zone(tz)

    return local_reference.hour >= delivery_hour if last_delivered_at.blank?

    last_local = last_delivered_at.in_time_zone(tz)
    return false if last_local.to_date == local_reference.to_date

    local_reference.hour >= delivery_hour
  end

  def mark_delivered!(delivered_at = Time.current)
    update!(last_delivered_at: delivered_at)
  end

  def channel_mention
    "<##{slack_channel_id}>"
  end

  def active_time_zone
    ActiveSupport::TimeZone[timezone] || ActiveSupport::TimeZone["UTC"]
  end
end

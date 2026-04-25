class GeocodeUsersWithoutCountryJob < ApplicationJob
  queue_as :literally_whenever

  include HasEnqueueControl
  include ApplicationHelper

  enqueue_limit 1

  def perform
    rows = ActiveRecord::Base.connection.select_rows(<<~SQL.squish)
      SELECT u.id AS user_id, h.ip_address
      FROM (
        SELECT id FROM users WHERE country_code IS NULL
      ) AS u(id)
      CROSS JOIN LATERAL (
        SELECT ip_address
        FROM heartbeats
        WHERE heartbeats.user_id = u.id
          AND heartbeats.ip_address IS NOT NULL
          AND heartbeats.deleted_at IS NULL
        ORDER BY heartbeats.id DESC
        LIMIT 1
      ) AS h
    SQL

    return if rows.empty?

    ids_by_ip = rows.group_by(&:last).transform_values { |pairs| pairs.map(&:first) }

    # Try IP-based geocoding first
    ids_by_ip.each do |ip, user_ids|
      country_code = geo(ip)
      next unless country_code.present?

      User.where(id: user_ids).update_all(country_code: country_code)
    end

    # Fallback to timezone-based detection for anyone we couldn't geocode by IP
    all_user_ids = rows.map(&:first)
    User.where(id: all_user_ids, country_code: nil).find_each do |user|
      code = tz_to_cc(user.timezone)
      user.update_column(:country_code, code) if code.present?
    end
  end

  private

  def geo(ip)
    result = Geocoder.search(ip).first
    return nil unless result&.country_code.present?

    result.country_code.upcase
  rescue => e
    report_error(e, message: "geocode fail on #{ip}")
    nil
  end

  def tz_to_cc(timezone)
    return nil if timezone.blank? || timezone == "UTC"

    tz = ActiveSupport::TimeZone[timezone]
    return nil unless tz&.tzinfo&.respond_to?(:country_code)

    tz.tzinfo.country_code&.upcase
  rescue => e
    report_error(e, message: "timezone geocode fail for #{timezone}")
    nil
  end
end

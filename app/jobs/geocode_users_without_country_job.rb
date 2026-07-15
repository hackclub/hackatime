class GeocodeUsersWithoutCountryJob < ApplicationJob
  queue_as :literally_whenever

  include HasEnqueueControl
  include ApplicationHelper

  enqueue_limit 1

  def perform
    user_ids = User.where(country_code: nil).pluck(:id)
    return if user_ids.empty?

    # Latest (by insertion id) non-null IP per user, matching the old LATERAL ... LIMIT 1.
    rows = Clickhouse::Heartbeat
      .where(user_id: user_ids).where.not(ip_address: nil)
      .group(:user_id)
      .pluck(Arel.sql("user_id, argMax(ip_address, id)"))

    return if rows.empty?

    ids_by_ip = rows.group_by(&:last).transform_values { |pairs| pairs.map(&:first) }

    # Try IP-based geocoding first
    ids_by_ip.each do |ip, user_ids|
      country_code = geo(ip)
      next if country_code.blank?

      # Each user has only one IP because the lateral heartbeat query uses LIMIT 1
      # (but if we change this later, I think (?) we need to update this too)
      User.where(id: user_ids).update_all(country_code: country_code)
    end

    # Fallback to timezone-based detection for anyone we couldn't geocode by IP
    all_user_ids = rows.map(&:first)
    users_by_timezone = User.where(id: all_user_ids, country_code: nil)
      .where.not(timezone: [ nil, "", "UTC" ])
      .pluck(:timezone, :id)
      .group_by(&:first)

    users_by_timezone.each do |timezone, pairs|
      country_code = tz_to_cc(timezone)
      next if country_code.blank?

      User.where(id: pairs.map(&:last)).update_all(country_code: country_code)
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

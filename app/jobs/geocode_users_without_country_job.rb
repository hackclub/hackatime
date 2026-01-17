class GeocodeUsersWithoutCountryJob < ApplicationJob
  queue_as :literally_whenever

  include HasEnqueueControl
  include ApplicationHelper

  enqueue_limit 1

  BATCH_SIZE = 500 # moving this higher can make stuff shaky, do it at your own risk!

  def perform
    heartbeats_with_ip = Heartbeat.where.not(ip_address: nil)
                                  .where("heartbeats.user_id = users.id")

    scope = User.where(country_code: nil)
                .where(heartbeats_with_ip.arel.exists)

    scope.in_batches(of: BATCH_SIZE) do |relation|
      User.transaction do
        ActiveRecord::Base.connection.execute("SET LOCAL lock_timeout = '1s'")
        ActiveRecord::Base.connection.execute("SET LOCAL statement_timeout = '30s'")
        users = relation.select(:id, :timezone).to_a
        x(users)
      end
    end
  rescue ActiveRecord::LockWaitTimeout, ActiveRecord::QueryAborted => e
    Rails.logger.warn "GeocodeUsersWithoutCountryJob backing off due to lock contention: #{e.message}"
    self.class.set(wait: 5.minutes).perform_later
  end

  private

  def x(users)
    return if users.empty?

    ips_by_user = find(users.map(&:id))
    updates = {}

    users.each do |user|
      ips = ips_by_user[user.id] || []
      country_code = find_country_code(user, ips)
      updates[user.id] = country_code if country_code.present?
    end

    return if updates.empty?

    User.upsert_all(
      updates.map { |id, code| { id: id, country_code: code } },
      unique_by: :id,
      update_only: [ :country_code ]
    )
  end

  def find(user_ids)
    return {} if user_ids.empty?

    ranked = Heartbeat
      .where(user_id: user_ids)
      .where.not(ip_address: nil)
      .select(<<~SQL.squish)
        user_id,
        ip_address,
        row_number() OVER (PARTITION BY user_id ORDER BY id DESC) AS rn
      SQL

    Heartbeat
      .from(ranked, :ranked_heartbeats)
      .where("rn <= 10")
      .pluck(:user_id, :ip_address)
      .group_by(&:first)
      .transform_values { |pairs| pairs.map(&:last).uniq }
  end

  def find_country_code(user, ips)
    ips.each do |ip_address|
      country_code = geo(ip_address)
      return country_code if country_code.present?
    end

    tz_to_cc(user.timezone)
  end

  def geo(ip)
    result = Geocoder.search(ip).first
    return nil unless result&.country_code.present?
    result.country_code.upcase
  rescue => e
    Rails.logger.error "geocode fail on #{ip}: #{e.message}"
    Sentry.capture_exception(e)
    nil
  end

  def tz_to_cc(timezone)
    return nil if timezone.blank? || timezone == "UTC"

    tz = ActiveSupport::TimeZone[timezone]
    return nil unless tz&.tzinfo&.respond_to?(:country_code)
    tz.tzinfo.country_code&.upcase
  rescue => e
    Rails.logger.error "timezone geocode fail for #{timezone}: #{e.message}"
    Sentry.capture_exception(e)
    nil
  end
end

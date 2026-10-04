# Fails tests that query heartbeats without respecting heartbeat exclusions.
# See HeartbeatExclusion.unguarded_heartbeat_sql?.
if Rails.env.test?
  ActiveSupport::Notifications.subscribe("sql.active_record") do |_name, _start, _finish, _id, payload|
    next if payload[:name] == "SCHEMA"
    next unless HeartbeatExclusion.unguarded_heartbeat_sql?(payload[:sql])

    raise "Heartbeat SQL ignores heartbeat exclusions. Use the Heartbeat default scope, " \
          "HeartbeatExclusion.visible_sql / hidden_sql or Heartbeat.with_excluded, or embed " \
          "HeartbeatExclusion::INCLUDE_HIDDEN_COMMENT when hidden rows are intended:\n#{payload[:sql]}"
  end
end

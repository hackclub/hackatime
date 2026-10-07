namespace :clickhouse do
  namespace :rollups do
    desc "Queue a dashboard rollup rebuild for every user with heartbeats, most recently active first"
    task rebuild: :environment do
      user_ids = Heartbeat.group(:user_id).order(Arel.sql("max(time) DESC")).pluck(:user_id)
      user_ids.each { |user_id| DashboardRollupRefreshJob.schedule_for(user_id, wait: 0.seconds) }
      puts "Queued rollup rebuilds for #{user_ids.size} users"
    end
  end
end

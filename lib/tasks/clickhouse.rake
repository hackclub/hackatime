namespace :clickhouse do
  namespace :rollups do
    desc "Queue a dashboard rollup rebuild for every user with heartbeats, most recently active first"
    task rebuild: :environment do
      user_ids = Heartbeat.group(:user_id).order(Arel.sql("max(time) DESC")).pluck(:user_id)
      user_ids.each { |user_id| DashboardRollupRefreshJob.schedule_for(user_id, wait: 0.seconds) }
      puts "Queued rollup rebuilds for #{user_ids.size} users"
    end
  end

  namespace :schema do
    desc "Create any missing ClickHouse tables from db/clickhouse/*.sql"
    task load: :environment do
      ClickhouseSchema.load!
    end
  end
end

# Deploys and bin/setup run db:prepare and CI runs db:schema:load; keep
# ClickHouse's tables in step with both.
%w[db:prepare db:schema:load].each do |task|
  Rake::Task[task].enhance([ "clickhouse:schema:load" ]) if Rake::Task.task_defined?(task)
end

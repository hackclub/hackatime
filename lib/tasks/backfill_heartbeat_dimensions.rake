namespace :heartbeats do
  desc "Backfill heartbeat dimension foreign keys (run after enabling heartbeat_dimension_dual_write)"
  task backfill_dimensions: :environment do
    dimensions = HeartbeatDimensionResolver::DIMENSIONS.keys

    puts "Enqueueing backfill jobs for #{dimensions.count} dimensions..."

    dimensions.each do |dimension|
      BackfillHeartbeatDimensionsJob.perform_later(dimension.to_s)
      puts "  - Enqueued #{dimension}"
    end

    puts "Done. Monitor GoodJob dashboard for progress."
  end

  desc "Check backfill progress for heartbeat dimensions"
  task backfill_progress: :environment do
    puts "Heartbeat dimension backfill progress:"
    puts "=" * 50

    total = Heartbeat.with_deleted.count

    HeartbeatDimensionResolver::DIMENSIONS.each do |key, spec|
      string_col = spec[:value_attr]
      fk_col = spec[:fk]

      with_string = Heartbeat.with_deleted.where.not(string_col => nil).count
      with_fk = Heartbeat.with_deleted.where.not(fk_col => nil).count
      missing = Heartbeat.with_deleted.where(fk_col => nil).where.not(string_col => nil).count

      pct = with_string > 0 ? ((with_fk.to_f / with_string) * 100).round(1) : 100.0
      puts "#{key.to_s.ljust(20)} #{pct}% (#{with_fk}/#{with_string}, #{missing} missing)"
    end

    puts "=" * 50
    puts "Total heartbeats: #{total}"
  end
end

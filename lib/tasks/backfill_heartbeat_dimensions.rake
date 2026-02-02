namespace :heartbeats do
  desc "Backfill heartbeat dimension foreign keys (run after enabling heartbeat_dimension_dual_write)"
  task backfill_dimensions: :environment do
    dimensions = %w[language category editor operating_system user_agent project branch machine]

    puts "Enqueueing backfill jobs for #{dimensions.count} dimensions..."

    dimensions.each do |dimension|
      BackfillHeartbeatDimensionsJob.perform_later(dimension)
      puts "  - Enqueued #{dimension}"
    end

    puts "Done. Monitor GoodJob dashboard for progress."
  end

  desc "Check backfill progress for heartbeat dimensions"
  task backfill_progress: :environment do
    puts "Heartbeat dimension backfill progress:"
    puts "=" * 50

    total = Heartbeat.with_deleted.count

    dimensions = {
      language: :language_id,
      category: :category_id,
      editor: :editor_id,
      operating_system: :operating_system_id,
      user_agent: :user_agent_id,
      project: :project_id,
      branch: :branch_id,
      machine: :machine_id
    }

    dimensions.each do |string_col, fk_col|
      with_string = Heartbeat.with_deleted.where.not(string_col => nil).count
      with_fk = Heartbeat.with_deleted.where.not(fk_col => nil).count
      missing = Heartbeat.with_deleted.where(fk_col => nil).where.not(string_col => nil).count

      pct = with_string > 0 ? ((with_fk.to_f / with_string) * 100).round(1) : 100.0
      puts "#{string_col.to_s.ljust(20)} #{pct}% (#{with_fk}/#{with_string}, #{missing} missing)"
    end

    puts "=" * 50
    puts "Total heartbeats: #{total}"
  end
end

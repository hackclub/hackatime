namespace :cache do
  desc "Warm up all caches for deployment and healthchecks"
  task warmup: :environment do
    puts "Starting cache warmup for deployment..."

    cache_jobs = [
      Cache::CurrentlyHackingJob,
      Cache::ActiveUsersGraphDataJob,
      Cache::HomeStatsJob,
      Cache::HeartbeatCountsJob,
      Cache::ActiveProjectsJob,
      Cache::MinutesLoggedJob,
      Cache::SetupSocialProofJob,
      Cache::UsageSocialProofJob
    ]

    cache_jobs.each do |job_class|
      puts "Running #{job_class.name}..."
      begin
        job_class.perform_now
        puts "✓ #{job_class.name} completed"
      rescue => e
        puts "✗ #{job_class.name} failed: #{e.message}"
        Rails.logger.error("Cache warmup failed for #{job_class.name}: #{e.class.name} #{e.message}")
      end
    end

    puts "Cache warmup completed!"
  end

  desc "Clear all application caches"
  task clear: :environment do
    puts "Clearing all application caches..."
    Rails.cache.clear
    puts "✓ All caches cleared"
  end
end

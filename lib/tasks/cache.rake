namespace :cache do
  desc "Clear all application caches"
  task clear: :environment do
    puts "Clearing all application caches..."
    Rails.cache.clear
    puts "✓ All caches cleared"
  end
end

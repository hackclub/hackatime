namespace :event_participation do
  desc "Backfill users.event_participation from historical heartbeats"
  task backfill: :environment do
    count = EventParticipationBackfill.call
    puts "Backfilled event participation for #{count} users"
  end
end

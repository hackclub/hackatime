# frozen_string_literal: true

# Quickly populate the leaderboard tables (and cache) with placeholder data
# so the UI can be tested without waiting on heartbeats / aggregation jobs.
#
#   bin/rails seed:dummy_leaderboard            # creates 500 entries each for daily and last_7_days
#   bin/rails seed:dummy_leaderboard COUNT=200  # custom size
#   bin/rails seed:remove_dummy_leaderboard     # tears down placeholder users + entries
namespace :seed do
  DUMMY_LEADERBOARD_PREFIX = "dummy_lb_"

  task dummy_leaderboard: :environment do
    count = ENV.fetch("COUNT", 500).to_i
    today = Date.current

    # Reuse any existing placeholders, then top up to `count`.
    existing_users = User.where("github_uid LIKE ?", "#{DUMMY_LEADERBOARD_PREFIX}%").to_a
    needed = count - existing_users.size
    countries = ISO3166::Country.codes.sample(40)

    if needed > 0
      puts "Creating #{needed} placeholder users..."
      needed.times do |i|
        suffix = SecureRandom.hex(4)
        animal = Faker::Creature::Animal.name.delete(' ').downcase[0, 12]
        username = "lb_#{animal}_#{suffix}"[0, 21]
        existing_users << User.create!(
          username: username,
          github_uid: "#{DUMMY_LEADERBOARD_PREFIX}#{suffix}",
          country_code: countries.sample
        )
        print "." if (i + 1) % 25 == 0
      end
      puts
    else
      puts "Reusing #{existing_users.size} existing placeholder users."
    end

    users = existing_users.first(count)

    %i[daily last_7_days].each do |period|
      board = ::Leaderboard.find_or_initialize_by(
        start_date: today,
        period_type: period,
        timezone_utc_offset: nil,
        deleted_at: nil
      )
      board.finished_generating_at ||= Time.current
      board.generation_duration_seconds ||= rand(2..10)
      board.save!

      LeaderboardEntry.where(leaderboard_id: board.id).delete_all

      rows = users.each_with_index.map do |u, i|
        # Sort the seconds high-to-low so the leaderboard already looks ranked.
        seconds = ((count - i) * 60) + rand(0..59)
        {
          leaderboard_id: board.id,
          user_id: u.id,
          total_seconds: seconds,
          streak_count: rand(0..45),
          rank: i + 1,
          created_at: Time.current,
          updated_at: Time.current
        }
      end
      LeaderboardEntry.insert_all(rows)

      puts "Seeded #{rows.size} entries on #{period} leaderboard ##{board.id}"
    end

    Rails.cache.delete(LeaderboardCache.global_key(:daily, today))
    Rails.cache.delete(LeaderboardCache.global_key(:last_7_days, today))
    # Page-cache keys are versioned by the leaderboard's updated_at, so they're
    # automatically invalidated when we save above. Nothing else to clear.
    puts "Cache cleared. Visit /leaderboards to see them."
  end

  task remove_dummy_leaderboard: :environment do
    user_ids = User.where("github_uid LIKE ?", "#{DUMMY_LEADERBOARD_PREFIX}%").ids
    if user_ids.empty?
      puts "No placeholder leaderboard users found."
      next
    end

    LeaderboardEntry.where(user_id: user_ids).delete_all
    User.where(id: user_ids).delete_all

    today = Date.current
    Rails.cache.delete(LeaderboardCache.global_key(:daily, today))
    Rails.cache.delete(LeaderboardCache.global_key(:last_7_days, today))

    puts "Removed #{user_ids.size} placeholder users and their leaderboard entries."
  end
end

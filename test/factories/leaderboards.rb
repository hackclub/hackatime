FactoryBot.define do
  factory :leaderboard do
    start_date { Date.current }
    period_type { :daily }
  end

  factory :leaderboard_entry do
    leaderboard
    user
    total_seconds { 0 }
  end
end

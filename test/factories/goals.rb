FactoryBot.define do
  factory :goal do
    user
    period { "day" }
    target_seconds { 30.minutes.to_i }
    languages { [] }
    projects { [] }
  end
end

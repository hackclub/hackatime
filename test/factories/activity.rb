FactoryBot.define do
  sequence(:commit_sha) { |number| number.to_s(16).rjust(40, "0") }
  sequence(:ja4_fingerprint) { |number| "test-ja4-fingerprint-#{number}" }

  factory :heartbeat do
    user
    time { Time.current.to_f }
    source_type { :test_entry }
  end

  factory :commit do
    sha { generate(:commit_sha) }
    user
  end

  factory :dashboard_rollup do
    user
    dimension { DashboardRollup::TOTAL_DIMENSION }
  end

  factory :ja4 do
    fingerprint { generate(:ja4_fingerprint) }
  end
end

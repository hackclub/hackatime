FactoryBot.define do
  sequence(:user_email) { |number| "user-#{number}@example.com" }
  sequence(:user_slack_uid) { |number| "U#{number.to_s.rjust(10, "0")}" }
  sequence(:user_hca_id) { |number| "ident!factory#{number}" }

  factory :user do
    timezone { "UTC" }
    hca_id { generate(:user_hca_id) }

    trait :unlinked do
      hca_id { nil }
    end

    User.admin_levels.except("default").each_key do |level|
      trait(level) { admin_level { level } }
    end

    trait :with_email do
      transient do
        email { generate(:user_email) }
      end

      after(:create) do |user, context|
        create(:email_address, user: user, email: context.email)
      end
    end

    trait :with_slack do
      slack_uid { generate(:user_slack_uid) }
    end
  end
end

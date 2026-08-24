FactoryBot.define do
  sequence(:instance_import_endpoint) { |number| "https://import-#{number}.example.com" }

  factory :heartbeat_import_run do
    user
    source_kind { :dev_upload }
    state { :queued }
  end

  factory :sailors_log do
    association :user, :with_slack
    slack_uid { user.slack_uid }
  end

  factory :instance_import_source do
    user
    endpoint_url { generate(:instance_import_endpoint) }
    encrypted_api_key { "encrypted-api-key" }
  end
end

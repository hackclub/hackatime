FactoryBot.define do
  factory :deletion_request do
    user
    requested_at { Time.current }
    status { :pending }
  end
end

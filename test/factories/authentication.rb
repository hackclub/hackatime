FactoryBot.define do
  sequence(:email_address_email) { |number| "email-#{number}@example.com" }
  sequence(:email_verification_email) { |number| "pending-email-#{number}@example.com" }
  sequence(:api_key_name) { |number| "API key #{number}" }
  sequence(:admin_api_key_name) { |number| "Admin API key #{number}" }
  sequence(:oauth_application_name) { |number| "OAuth application #{number}" }

  factory :email_address do
    user
    email { generate(:email_address_email) }
    source { :signing_in }
  end

  factory :email_verification_request do
    user
    email { generate(:email_verification_email) }
  end

  factory :api_key do
    user
    name { generate(:api_key_name) }
  end

  factory :admin_api_key do
    association :user, :admin
    name { generate(:admin_api_key_name) }
  end

  factory :sign_in_token do
    user
    auth_type { :email }
  end

  factory :oauth_application do
    association :owner, factory: :user
    name { generate(:oauth_application_name) }
    redirect_uri { "https://example.com/callback" }
    scopes { Doorkeeper.configuration.default_scopes.to_a.join(" ") }
    confidential { true }
  end

  factory :oauth_access_token, class: "Doorkeeper::AccessToken" do
    association :application, factory: :oauth_application
    resource_owner_id { create(:user).id }
    scopes { "profile" }
    expires_in { 16.years.to_i }
  end

  factory :oauth_access_grant, class: "Doorkeeper::AccessGrant" do
    association :application, factory: :oauth_application
    resource_owner_id { create(:user).id }
    redirect_uri { application.redirect_uri }
    scopes { "profile" }
    expires_in { 10.minutes.to_i }
  end
end

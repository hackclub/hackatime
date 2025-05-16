# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).

# Only seed test data in development environment
if Rails.env.development?
  # Creating test user
  test_user = User.find_or_create_by(slack_uid: 'TEST123456') do |user|
    user.username = 'testuser'
    user.is_admin = true
  end

  # Add email address
  email = test_user.email_addresses.find_or_create_by(email: 'test@example.com')

  # Create API key
  api_key = test_user.api_keys.find_or_create_by(name: 'Development API Key') do |key|
    key.token = 'dev-api-key-12345'
  end

  # Create a sign-in token that doesn't expire
  token = test_user.sign_in_tokens.find_or_create_by(token: 'testing-token') do |t|
    t.expires_at = 1.year.from_now
    t.auth_type = :email
  end

  puts "Created test user:"
  puts "  Username: #{test_user.username}"
  puts "  Email: #{email.email}"
  puts "  API Key: #{api_key.token}"
  puts "  Sign-in Token: #{token.token}"

  # Create sample heartbeats
  if test_user.heartbeats.count == 0
    5.times do |i|
      test_user.heartbeats.create!(
        time: (Time.current - i.hours).to_f,
        entity: "test/file_#{i}.rb",
        project: "test-project",
        language: "ruby",
        source_type: :direct_entry
      )
    end
    puts "Created 5 sample heartbeats for the test user"
  else
    puts "Sample heartbeats already exist for the test user"
  end
elsif Rails.env.staging?
  require_relative 'seeds/staging'
else
  puts "Skipping development seed data in #{Rails.env} environment"
end

# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).

# Seed local/test records only; production runs leave application data untouched.
test_user = nil
if Rails.env.development? || Rails.env.test?
  test_user = User.find_or_create_by(slack_uid: 'TEST123456') do |user|
    user.username = 'testuser'
    user.slack_username = 'testuser'

    user.admin_level = :ultraadmin
    # Ensure timezone is set to avoid nil timezone issues
    user.timezone = 'America/New_York'
  end

  email = test_user.email_addresses.find_or_create_by(email: 'test@example.com')
  email.update(source: :slack) if email.source.nil?

  api_key = test_user.api_keys.find_or_create_by(name: 'Development API Key') do |key|
    key.token = 'dev-api-key-12345'
  end

  admin_api_key = AdminApiKey.find_or_create_by(name: 'Development Admin Key') do |key|
    key.user = test_user
    key.token = 'dev-admin-api-key-12345'
  end

  token = test_user.sign_in_tokens.find_or_create_by(token: 'testing-token') do |t|
    t.expires_at = 1.year.from_now
    t.auth_type = :email
  end

  puts "Created test user:"
  puts "  Username: #{test_user.display_name}"
  puts "  Email: #{email.email}"
  puts "  API Key: #{api_key.token}"
  puts "  Admin API Key: #{admin_api_key.token}"
  puts "  Sign-in Token: #{token.token}"

  if Clickhouse::Heartbeat.for_user(test_user).count < 50
    test_user.update!(timezone: 'America/New_York') unless test_user.timezone.present?

    editors = [ 'Zed', 'Neovim', 'VSCode', 'Emacs' ]
    languages = [ 'Ruby', 'JavaScript', 'TypeScript', 'Python', 'Go', 'HTML', 'CSS', 'Markdown' ]
    projects = [ 'panorama', 'harbor', 'zera', 'tern', 'smokie' ]
    operating_systems = [ 'Linux', 'macOS', 'Windows' ]
    machines = [ 'dev-machine', 'laptop', 'desktop' ]

    # Clear existing heartbeats to ensure consistent test data
    Clickhouse::Heartbeat.connection.execute(
      "DELETE FROM heartbeats WHERE user_id = #{test_user.id.to_i}"
    )

    rows = []

    7.downto(0) do |day|
      heartbeat_count = rand(5..20)
      heartbeat_count.times do |i|
        hour = rand(9..20)
        minute = rand(0..59)
        second = rand(0..59)

        timestamp = (Time.current - day.days).beginning_of_day + hour.hours + minute.minutes + second.seconds

        rows << {
          user_id: test_user.id,
          time: timestamp.to_i,
          entity: "test/file_#{rand(1..30)}.#{[ 'rb', 'js', 'ts', 'py', 'go' ].sample}",
          project: projects.sample,
          language: languages.sample,
          editor: editors.sample,
          operating_system: operating_systems.sample,
          machine: machines.sample,
          category: "coding",
          source_type: :direct_entry
        }
      end
    end

    # Create a few sequential heartbeats to properly test duration calculation
    base_time = Time.current - 2.days
    10.times do |i|
      rows << {
        user_id: test_user.id,
        time: (base_time + i.minutes).to_i,
        entity: "test/sequential_file.rb",
        project: "harbor",
        language: "Ruby",
        editor: "Zed",
        operating_system: "Linux",
        machine: "dev-machine",
        category: "coding",
        source_type: :direct_entry
      }
    end

    Clickhouse::HeartbeatWriter.insert_rows(rows)

    puts "Created comprehensive heartbeat data over the last 7 days for the test user"
  else
    puts "Sample heartbeats already exist for the test user"
  end
else
  puts "Skipping development seed data in #{Rails.env} environment"
end

# Use the test user if we have one, otherwise fall back to User ID 1 (for other envs or if test user logic changes)
app_owner = test_user || User.find_by(id: 1)

OauthApplication.find_or_create_by(
  name: "Hackatime Desktop",
  owner: app_owner,
  redirect_uri: "hackatime://auth/callback",
  uid: "BPr5VekIV-xuQ2ZhmxbGaahJ3XVd7gM83pql-HYGYxQ",
  scopes: [ "profile" ],
  confidential: false,
)

if test_user && defined?(Doorkeeper)
  app = OauthApplication.find_by(name: "Hackatime Desktop")

  existing_token = Doorkeeper::AccessToken.find_by(token: 'dev-api-key-12345')

  if existing_token
    existing_token.update_columns(
      application_id: app.id,
      resource_owner_id: test_user.id,
      expires_in: nil,
      scopes: 'profile'
    )
  else
    token = Doorkeeper::AccessToken.find_or_create_by(
      application_id: app.id,
      resource_owner_id: test_user.id
    ) do |t|
      t.expires_in = nil
      t.scopes = 'profile'
    end

    token.update_column(:token, 'dev-api-key-12345')
  end
end

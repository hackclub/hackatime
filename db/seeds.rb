# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).

Doorkeeper::Application.find_or_create_by(
  name: "Hackatime Desktop",
  owner: User.find_by(id: '1'),
  redirect_uri: "hackatime://auth/callback",
  uid: "BPr5VekIV-xuQ2ZhmxbGaahJ3XVd7gM83pql-HYGYxQ",
  scopes: [ "profile" ],
  confidential: false,
)

# Only seed test data in development environment
if Rails.env.development?
  # Creating test user
  test_user = User.find_or_create_by(slack_uid: 'TEST123456') do |user|
    user.username = 'testuser'
    user.slack_username = 'testuser'

    # Before you had user.is_admin = true, does not work, changed it to that, looks like it works but idk how to use the admin pages so pls check this, i just guess coded this, the cmd to seed the db works without errors
    user.set_admin_level(:superadmin)
    # Ensure timezone is set to avoid nil timezone issues
    user.timezone = 'America/New_York'
  end

  # Add email address with slack as the source
  email = test_user.email_addresses.find_or_create_by(email: 'test@example.com')
  email.update(source: :slack) if email.source.nil?

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
  puts "  Username: #{test_user.display_name}"
  puts "  Email: #{email.email}"
  puts "  API Key: #{api_key.token}"
  puts "  Sign-in Token: #{token.token}"

  # Create sample heartbeats for last 7 days with variety of data
  if test_user.heartbeats.count < 50
    # Ensure timezone is set
    test_user.update!(timezone: 'America/New_York') unless test_user.timezone.present?

    # Create diverse test data over the last 7 days
    editors = [ 'Zed', 'Neovim', 'VSCode', 'Emacs' ]
    languages = [ 'Ruby', 'JavaScript', 'TypeScript', 'Python', 'Go', 'HTML', 'CSS', 'Markdown' ]
    projects = [ 'panorama', 'harbor', 'zera', 'tern', 'smokie' ]
    operating_systems = [ 'Linux', 'macOS', 'Windows' ]
    machines = [ 'dev-machine', 'laptop', 'desktop' ]

    # Clear existing heartbeats to ensure consistent test data
    test_user.heartbeats.destroy_all

    # Create heartbeats for the last 7 days
    7.downto(0) do |day|
      # Add 5-20 heartbeats per day
      heartbeat_count = rand(5..20)
      heartbeat_count.times do |i|
        # Distribute throughout the day
        hour = rand(9..20)  # Between 9 AM and 8 PM
        minute = rand(0..59)
        second = rand(0..59)

        # Create timestamp for this heartbeat
        timestamp = (Time.current - day.days).beginning_of_day + hour.hours + minute.minutes + second.seconds

        # Create the heartbeat with varied data
        test_user.heartbeats.create!(
          time: timestamp.to_i,
          entity: "test/file_#{rand(1..30)}.#{[ 'rb', 'js', 'ts', 'py', 'go' ].sample}",
          project: projects.sample,
          language: languages.sample,
          editor: editors.sample,
          operating_system: operating_systems.sample,
          machine: machines.sample,
          category: "coding",
          source_type: :direct_entry
        )
      end
    end

    # Create a few sequential heartbeats to properly test duration calculation
    base_time = Time.current - 2.days
    10.times do |i|
      test_user.heartbeats.create!(
        time: (base_time + i.minutes).to_i,
        entity: "test/sequential_file.rb",
        project: "harbor",
        language: "Ruby",
        editor: "Zed",
        operating_system: "Linux",
        machine: "dev-machine",
        category: "coding",
        source_type: :direct_entry
      )
    end

    puts "Created comprehensive heartbeat data over the last 7 days for the test user"
  else
    puts "Sample heartbeats already exist for the test user"
  end
else
  puts "Skipping development seed data in #{Rails.env} environment"
end

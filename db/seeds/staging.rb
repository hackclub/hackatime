if Rails.env.staging?
  puts "Seeding staging environment..."

  # Create multiple users with various configurations
  puts "Creating users..."

  # Admin user with all features enabled
  admin_user = User.find_or_create_by(slack_uid: 'ADMIN123456') do |user|
    user.username = 'admin'
    user.slack_username = 'admin'
    user.slack_avatar_url = 'https://via.placeholder.com/300'
    user.is_admin = true
    user.uses_slack_status = true
    user.timezone = 'America/New_York'
    user.hackatime_extension_text_type = :simple_text
  end

  # Regular user with GitHub integration
  github_user = User.find_or_create_by(slack_uid: 'GITHUB123456') do |user|
    user.username = 'github_user'
    user.slack_username = 'github_user'
    user.github_uid = 'github123'
    user.github_username = 'github_user'
    user.github_avatar_url = 'https://github.githubassets.com/images/modules/logos_page/GitHub-Mark.png'
    user.timezone = 'America/Los_Angeles'
  end

  # Regular user without GitHub
  regular_user = User.find_or_create_by(slack_uid: 'USER123456') do |user|
    user.username = 'regular_user'
    user.slack_username = 'regular_user'
    user.slack_avatar_url = 'https://via.placeholder.com/300'
    user.timezone = 'Europe/London'
  end

  # Create email addresses for each user
  puts "Creating email addresses..."
  admin_user.email_addresses.find_or_create_by(email: 'admin@example.com')
  github_user.email_addresses.find_or_create_by(email: 'github_user@example.com')
  regular_user.email_addresses.find_or_create_by(email: 'regular_user@example.com')

  # Create API keys for each user
  puts "Creating API keys..."
  admin_user.api_keys.find_or_create_by(name: 'Admin API Key') do |key|
    key.token = 'admin-api-key-12345'
  end

  github_user.api_keys.find_or_create_by(name: 'GitHub User API Key') do |key|
    key.token = 'github-api-key-12345'
  end

  regular_user.api_keys.find_or_create_by(name: 'Regular User API Key') do |key|
    key.token = 'regular-api-key-12345'
  end


  # Create sign-in tokens for testing
  puts "Creating sign-in tokens..."
  admin_user.sign_in_tokens.find_or_create_by(token: 'admin-token') do |t|
    t.expires_at = 1.year.from_now
    t.auth_type = :email
  end

  github_user.sign_in_tokens.find_or_create_by(token: 'github-token') do |t|
    t.expires_at = 1.year.from_now
    t.auth_type = :email
  end

  regular_user.sign_in_tokens.find_or_create_by(token: 'regular-token') do |t|
    t.expires_at = 1.year.from_now
    t.auth_type = :email
  end

  # Sample projects, languages, and editors for heartbeats
  projects = [ 'rails-app', 'react-frontend', 'data-analysis', 'mobile-app', 'api-service', 'cli-tool', 'documentation', 'hackatime' ]
  languages = [ 'ruby', 'javascript', 'typescript', 'python', 'go', 'rust', 'html', 'css', 'markdown' ]
  editors = [ 'vs-code', 'vim', 'emacs', 'atom', 'sublime', 'intellij', 'xcode', 'android-studio' ]
  operating_systems = [ 'macos', 'windows', 'linux', 'ubuntu', 'debian', 'fedora', 'arch' ]

  # Create heartbeats for each user
  puts "Creating heartbeats..."

  users = [ admin_user, github_user, regular_user ]

  # Helper to create a unique heartbeat using fields_hash
  def create_unique_heartbeat(user, attrs)
    # Skip if it would be a duplicate
    fields_hash = Heartbeat.generate_fields_hash(attrs)
    return if Heartbeat.where(fields_hash: fields_hash).exists?

    heartbeat = user.heartbeats.new(attrs)
    heartbeat.fields_hash = fields_hash
    heartbeat.save!
  rescue ActiveRecord::RecordNotUnique
    # Skip if there's a race condition
  end

  # Transaction to speed up database operations
  ActiveRecord::Base.transaction do
    users.each do |user|
      # Skip if user already has heartbeats
      next if user.heartbeats.count > 0

      puts "Creating heartbeats for #{user.username}..."

      # Create heartbeats for the last 30 days
      (0..30).each do |days_ago|
        date = Date.current - days_ago.days

        # Pick 2-3 projects for this day
        day_projects = projects.sample(rand(2..3))

        day_projects.each do |project|
          language = languages.sample
          editor = editors.sample
          os = operating_systems.sample

          # Create 4-8 heartbeats throughout the day
          (1..24).to_a.sample(rand(4..8)).each do |hour|
            time = date.to_time + hour.hours + rand(0..59).minutes

            attrs = {
              time: time.to_f,
              entity: "#{project}/file_#{rand(1..10)}.#{language.split('-').first}",
              project: project,
              language: language,
              editor: editor,
              operating_system: os,
              source_type: :direct_entry,
              is_write: [ true, false ].sample,
              category: 'coding',
              type: 'file',
              line_additions: rand(1..50),
              line_deletions: rand(0..10),
              lineno: rand(1..100),
              lines: rand(100..1000),
              cursorpos: rand(1..500)
            }

            create_unique_heartbeat(user, attrs)
          end
        end
      end
    end
  end

  # Create project repo mappings for GitHub user
  puts "Creating project repo mappings..."
  projects.sample(3).each do |project|
    github_user.project_repo_mappings.find_or_create_by(project_name: project) do |mapping|
      mapping.repo_url = "https://github.com/#{github_user.github_username}/#{project}"
    end
  end

  # Create leaderboards
  puts "Creating leaderboards..."

  # Daily leaderboard for today
  daily_leaderboard = Leaderboard.find_or_create_by(
    start_date: Date.current,
    period_type: :daily
  ) do |leaderboard|
    leaderboard.finished_generating_at = Time.current
  end

  # Weekly leaderboard for this week
  weekly_leaderboard = Leaderboard.find_or_create_by(
    start_date: Date.current.beginning_of_week,
    period_type: :weekly
  ) do |leaderboard|
    leaderboard.finished_generating_at = Time.current
  end

  # Create leaderboard entries
  puts "Creating leaderboard entries..."

  users.each do |user|
    # Daily leaderboard entry
    daily_seconds = user.heartbeats.today.duration_seconds

    if daily_seconds > 0
      LeaderboardEntry.find_or_create_by(
        leaderboard: daily_leaderboard,
        user: user
      ) do |entry|
        entry.total_seconds = daily_seconds
      end
    end

    # Weekly leaderboard entry
    week_start = Time.current.beginning_of_week.to_i
    week_end = Time.current.end_of_week.to_i
    weekly_seconds = user.heartbeats.where("time >= ? AND time <= ?", week_start, week_end).duration_seconds

    if weekly_seconds > 0
      LeaderboardEntry.find_or_create_by(
        leaderboard: weekly_leaderboard,
        user: user
      ) do |entry|
        entry.total_seconds = weekly_seconds
      end
    end
  end

  puts "Staging seed data created successfully!"
else
  puts "Skipping staging seed data in #{Rails.env} environment"
end

# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).

# Only seed test data in development environment
if Rails.env.development?
  puts "=== Seeding development database ==="

  # Reference data for generating realistic heartbeats
  LANGUAGES = {
    "ruby" => [ ".rb" ],
    "javascript" => [ ".js", ".jsx", ".mjs" ],
    "typescript" => [ ".ts", ".tsx" ],
    "python" => [ ".py" ],
    "go" => [ ".go" ],
    "java" => [ ".java" ],
    "c++" => [ ".cpp", ".hpp", ".cc", ".h" ],
    "c#" => [ ".cs" ],
    "html" => [ ".html", ".htm" ],
    "css" => [ ".css", ".scss", ".sass" ],
    "php" => [ ".php" ],
    "rust" => [ ".rs" ],
    "swift" => [ ".swift" ],
    "kotlin" => [ ".kt" ],
    "markdown" => [ ".md", ".markdown" ]
  }

  EDITORS = [ "VS Code", "Vim", "Emacs", "Sublime Text", "IntelliJ IDEA", "PyCharm", "RubyMine", "Atom", "Notepad++", "Eclipse" ]

  OPERATING_SYSTEMS = [ "Mac OS X", "Windows 10", "Linux Ubuntu", "Linux Fedora", "Linux Arch", "Linux Debian" ]

  PROJECTS = [
    { name: "personal-website", description: "Personal portfolio site" },
    { name: "todo-app", description: "Task management application" },
    { name: "chat-bot", description: "AI-powered messaging bot" },
    { name: "data-visualization", description: "D3.js dashboard" },
    { name: "mobile-game", description: "Unity-based mobile game" },
    { name: "api-server", description: "RESTful API service" },
    { name: "ml-model", description: "Machine learning classifier" },
    { name: "cli-tools", description: "Command-line utilities" },
    { name: "hackathon-project", description: "Weekend hackathon entry" },
    { name: "school-assignment", description: "CS assignment" },
    { name: "open-source-contrib", description: "Open source contribution" }
  ]

  PROJECT_STRUCTURES = {
    "web-app" => [ "app/controllers", "app/models", "app/views", "config", "db", "lib", "public", "spec", "test" ],
    "mobile-app" => [ "src/components", "src/screens", "src/utils", "assets", "tests" ],
    "api" => [ "app/controllers", "app/models", "config", "db", "lib", "spec" ],
    "cli-tool" => [ "src", "bin", "lib", "test" ],
    "game" => [ "src/engine", "src/levels", "src/characters", "assets", "scripts" ],
    "data-science" => [ "notebooks", "data", "models", "scripts", "visualizations" ]
  }

  puts "Creating test users..."

  test_user = User.find_or_create_by(slack_uid: 'TEST123456') do |user|
    user.username = 'testuser'
    user.slack_username = 'testuser'
    user.slack_avatar_url = 'https://i.pravatar.cc/300'
    user.is_admin = true
    user.uses_slack_status = false
    user.timezone = "UTC"
    user.hackatime_extension_text_type = :simple_text
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

  admin_user = User.find_or_create_by(slack_uid: 'ADMIN123456') do |user|
    user.username = 'admin'
    user.slack_username = 'admin'
    user.slack_avatar_url = 'https://i.pravatar.cc/300'
    user.is_admin = true
    user.uses_slack_status = true
    user.timezone = 'America/New_York'
    user.hackatime_extension_text_type = :simple_text
  end

  github_user = User.find_or_create_by(slack_uid: 'GITHUB123456') do |user|
    user.username = 'github_user'
    user.slack_username = 'github_user'
    user.github_uid = 'github123'
    user.github_username = 'github_user'
    user.github_avatar_url = 'https://github.githubassets.com/images/modules/logos_page/GitHub-Mark.png'
    user.timezone = 'America/Los_Angeles'
    user.uses_slack_status = false
    user.hackatime_extension_text_type = :clock_emoji
  end

  # Regular user
  emoji_user = User.find_or_create_by(slack_uid: 'EMOJI123456') do |user|
    user.username = 'emoji_user'
    user.slack_username = 'emoji_user'
    user.slack_avatar_url = 'https://i.pravatar.cc/300'
    user.timezone = 'Europe/London'
    user.uses_slack_status = true
    user.hackatime_extension_text_type = :clock_emoji
  end

  # Regular user
  compliment_user = User.find_or_create_by(slack_uid: 'COMPLIMENT123456') do |user|
    user.username = 'compliment_user'
    user.slack_username = 'compliment_user'
    user.slack_avatar_url = 'https://i.pravatar.cc/300'
    user.timezone = 'Asia/Tokyo'
    user.uses_slack_status = false
    user.hackatime_extension_text_type = :compliment_text
  end

  # Create email addresses for each user
  puts "Creating email addresses..."
  admin_user.email_addresses.find_or_create_by(email: 'admin@example.com')
  github_user.email_addresses.find_or_create_by(email: 'github_user@example.com')
  emoji_user.email_addresses.find_or_create_by(email: 'emoji_user@example.com')
  compliment_user.email_addresses.find_or_create_by(email: 'compliment_user@example.com')

  # Create API keys for each user
  puts "Creating API keys..."
  admin_user.api_keys.find_or_create_by(name: 'Admin API Key') do |key|
    key.token = 'admin-api-key-12345'
  end

  github_user.api_keys.find_or_create_by(name: 'GitHub User API Key') do |key|
    key.token = 'github-api-key-12345'
  end

  emoji_user.api_keys.find_or_create_by(name: 'Emoji User API Key') do |key|
    key.token = 'emoji-api-key-12345'
  end

  compliment_user.api_keys.find_or_create_by(name: 'Compliment User API Key') do |key|
    key.token = 'compliment-api-key-12345'
  end

  puts "Creating sign-in tokens..."
  admin_user.sign_in_tokens.find_or_create_by(token: 'admin-token') do |t|
    t.expires_at = 1.year.from_now
    t.auth_type = :email
  end

  github_user.sign_in_tokens.find_or_create_by(token: 'github-token') do |t|
    t.expires_at = 1.year.from_now
    t.auth_type = :email
  end

  emoji_user.sign_in_tokens.find_or_create_by(token: 'emoji-token') do |t|
    t.expires_at = 1.year.from_now
    t.auth_type = :email
  end

  compliment_user.sign_in_tokens.find_or_create_by(token: 'compliment-token') do |t|
    t.expires_at = 1.year.from_now
    t.auth_type = :email
  end

  users = [ test_user, admin_user, github_user, emoji_user, compliment_user ]

  if Heartbeat.count > 0
    puts "Heartbeats already exist, skipping heartbeat creation"
  else
    # Helper to create a unique heartbeat using fields_hash
    def create_unique_heartbeat(user, attrs)
      fields_hash = Heartbeat.generate_fields_hash(attrs)
      return if Heartbeat.where(fields_hash: fields_hash).exists?

      heartbeat = user.heartbeats.new(attrs)
      heartbeat.fields_hash = fields_hash
      heartbeat.save!
    rescue ActiveRecord::RecordNotUnique
      # Skip if there's a race condition
    end

    puts "Creating heartbeats..."

    # Transaction to speed up database operations
    ActiveRecord::Base.transaction do
      users.each do |user|
        puts "Creating heartbeats for #{user.username}..."

        # Select 3-5 projects for this user
        user_projects = PROJECTS.sample(rand(3..5))

        # Create project-repo mappings for GitHub users
        if user.github_username.present?
          user_projects.each do |project|
            user.project_repo_mappings.find_or_create_by(project_name: project[:name]) do |mapping|
              mapping.repo_url = "https://github.com/#{user.github_username}/#{project[:name]}"
            end
          end
        end

        # Create heartbeats for the last 30 days
        (0..30).each do |days_ago|
          date = Date.current - days_ago.days

          # Skip if date is in the future
          next if date > Date.current

          # Pick 1-3 projects for this day
          day_projects = user_projects.sample(rand(1..3))

          day_projects.each do |project|
            # Choose a structure for this project
            project_structure = PROJECT_STRUCTURES.keys.sample
            folders = PROJECT_STRUCTURES[project_structure]

            # Choose main language for this project
            language = LANGUAGES.keys.sample
            extension = LANGUAGES[language].sample

            # Choose editor and OS
            editor = EDITORS.sample
            os = OPERATING_SYSTEMS.sample

            is_active_now = (user.uses_slack_status? && days_ago == 0 && project == day_projects.first)

            heartbeat_count = is_active_now ? rand(15..25) : rand(4..12)

            (1..24).to_a.sample(heartbeat_count).sort.each do |hour|
              time = if is_active_now && hour > 20
                date.to_time + hour.hours + rand(Time.now.min).minutes
              else
                date.to_time + hour.hours + rand(0..59).minutes
              end

              folder = folders.sample
              filename = [ "main", "index", "app", "utils", "helpers", "models", "views", "components", "services" ].sample
              file_path = "#{project[:name]}/#{folder}/#{filename}#{extension}"

              attrs = {
                time: time.to_f,
                entity: file_path,
                project: project[:name],
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
  end

  # Update or create GitHub repo mappings for all users with GitHub accounts
  puts "Scanning GitHub repos..."
  users.select { |u| u.github_username.present? }.each do |user|
    ScanGithubReposJob.perform_now(user.id)
  end


  # Generate leaderboards using the application's job classes
  puts "Generating leaderboards..."

  puts "  Creating daily leaderboard..."
  daily_leaderboard = LeaderboardUpdateJob.perform_now(:daily, Date.current)

  puts "  Creating weekly leaderboard..."
  weekly_leaderboard = LeaderboardUpdateJob.perform_now(:weekly, Date.current.beginning_of_week)

  puts "Updating Slack statuses..."
  UserSlackStatusUpdateJob.perform_now

  puts "Caching home stats..."
  CacheHomeStatsJob.perform_now

  puts "=== Seed completed successfully ==="
else
  puts "Skipping development seed data in #{Rails.env} environment"
end

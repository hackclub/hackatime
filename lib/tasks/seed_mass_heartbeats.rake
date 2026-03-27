# frozen_string_literal: true

namespace :seed do
  desc "Create 5M realistic heartbeats across 100 users over 1 year"
  task mass_heartbeats: :environment do
    NUM_USERS = 100
    TOTAL_HEARTBEATS = 5_000_000
    HBS_PER_USER = TOTAL_HEARTBEATS / NUM_USERS # 50,000
    BATCH_SIZE = 5_000
    ONE_YEAR_AGO = 1.year.ago

    # Realistic data pools
    projects = [
      { name: "webapp", langs: %w[TypeScript JavaScript HTML CSS], entities_prefix: "src/components" },
      { name: "api-server", langs: %w[Ruby], entities_prefix: "app" },
      { name: "cli-tool", langs: %w[Go], entities_prefix: "cmd" },
      { name: "data-pipeline", langs: %w[Python], entities_prefix: "pipelines" },
      { name: "mobile-app", langs: %w[TypeScript JavaScript], entities_prefix: "src/screens" },
      { name: "infra", langs: %w[YAML HCL Bash], entities_prefix: "terraform" },
      { name: "docs-site", langs: %w[Markdown MDX CSS], entities_prefix: "content" },
      { name: "ml-service", langs: %w[Python], entities_prefix: "models" },
      { name: "design-system", langs: %w[TypeScript CSS], entities_prefix: "packages/ui/src" },
      { name: "game-engine", langs: %w[Rust C++], entities_prefix: "src/engine" },
    ]

    editors = %w[VS\ Code Neovim Zed Emacs IntelliJ\ IDEA WebStorm GoLand PyCharm RubyMine Cursor]
    oses = %w[Linux macOS Windows]
    machines = %w[dev-workstation laptop-home laptop-office macbook-pro desktop-ubuntu thinkpad imac]
    branches = %w[main develop feature/auth feature/dashboard fix/login refactor/api feature/search hotfix/crash feature/onboarding chore/deps]

    ext_map = {
      "TypeScript" => "ts", "JavaScript" => "js", "HTML" => "html", "CSS" => "css",
      "Ruby" => "rb", "Go" => "go", "Python" => "py", "Rust" => "rs", "C++" => "cpp",
      "YAML" => "yml", "HCL" => "tf", "Bash" => "sh", "Markdown" => "md", "MDX" => "mdx",
    }

    file_names = %w[
      index main app config utils helpers types models controllers services
      routes middleware auth database schema migration worker queue cache
      component layout page header footer sidebar nav form button input
      test spec factory fixture setup teardown benchmark profile
    ]

    user_agents = [
      "wakatime/v1.73.1 (linux-5.15.0-x86_64) go1.21.5 VS Code/1.85.0 vscode-wakatime/24.0.8",
      "wakatime/v1.73.1 (darwin-23.2.0-arm64) go1.21.5 Zed/0.118.1 zed-wakatime/0.1.0",
      "wakatime/v1.73.1 (linux-6.5.0-x86_64) go1.21.5 neovim/0.9.4 vim-wakatime/11.0.0",
      "wakatime/v1.73.1 (darwin-23.2.0-arm64) go1.21.5 emacs/29.1 emacs-wakatime/1.0.2",
      "wakatime/v1.73.1 (windows-10.0.22631-amd64) go1.21.5 IntelliJ IDEA/2023.3 jetbrains-wakatime/14.0.0",
    ]

    puts "Creating #{NUM_USERS} users with #{HBS_PER_USER} heartbeats each (#{TOTAL_HEARTBEATS} total)..."
    puts "This will take a few minutes."

    start_time = Time.current

    NUM_USERS.times do |i|
      # Create user
      user = User.create!(
        username: "seed_#{Faker::Internet.username(specifier: 5..12, separators: %w[_ -])}#{rand(100..999)}",
        github_uid: "seed_#{SecureRandom.hex(8)}",
        timezone: ActiveSupport::TimeZone.all.map(&:tzinfo).map(&:name).sample,
        slack_uid: "SEED#{SecureRandom.hex(6).upcase}",
      )

      # Each user has 2-4 "main" projects and an editor/os/machine preference
      user_projects = projects.sample(rand(2..4))
      primary_editor = editors.sample
      primary_os = oses.sample
      primary_machine = machines.sample

      # Generate all heartbeats for this user
      total_inserted = 0
      batch = []

      # Walk through the year day by day
      (0..364).each do |day_offset|
        day_start = ONE_YEAR_AGO + day_offset.days
        weekday = day_start.wday

        # Realistic daily activity: less on weekends, varies by day
        if weekday == 0 || weekday == 6
          # Weekend: 30% chance of coding, fewer heartbeats
          next if rand < 0.3
          daily_count = rand(20..80)
        else
          # Weekday: occasionally skip (sick/vacation ~5%)
          next if rand < 0.05
          daily_count = rand(80..200)
        end

        # Cap to not exceed per-user total
        remaining = HBS_PER_USER - total_inserted
        daily_count = [daily_count, remaining].min
        break if daily_count <= 0

        # Generate coding sessions (2-6 per day)
        sessions = rand(2..6)
        session_starts = sessions.times.map do
          if weekday == 0 || weekday == 6
            rand(10..22) # weekend: 10am-10pm
          else
            rand(8..21) # weekday: 8am-9pm
          end
        end.sort.uniq

        hbs_per_session = daily_count / [session_starts.size, 1].max
        session_project = user_projects.sample

        session_starts.each do |session_hour|
          count_this_session = hbs_per_session + rand(-5..5)
          count_this_session = [count_this_session, 1].max
          remaining_for_day = daily_count - (total_inserted - (HBS_PER_USER - remaining - daily_count + (total_inserted - (HBS_PER_USER - remaining))))

          # Pick project for this session (80% chance same project per session)
          proj = rand < 0.8 ? session_project : user_projects.sample
          lang = proj[:langs].sample
          ext = ext_map[lang] || "txt"
          branch_name = branches.sample

          # Use primary tools with some variation
          editor = rand < 0.85 ? primary_editor : editors.sample
          os = rand < 0.95 ? primary_os : oses.sample
          machine = rand < 0.9 ? primary_machine : machines.sample
          ua = user_agents.sample

          count_this_session.times do |j|
            break if total_inserted >= HBS_PER_USER

            # Heartbeats within a session are 30s-5min apart
            offset_seconds = session_hour * 3600 + j * rand(30..300)
            timestamp = day_start.beginning_of_day + offset_seconds.seconds

            file = "#{proj[:entities_prefix]}/#{file_names.sample}.#{ext}"
            lines_in_file = rand(20..2000)

            batch << {
              user_id: user.id,
              time: timestamp.to_f,
              entity: file,
              project: proj[:name],
              language: lang,
              editor: editor,
              operating_system: os,
              machine: machine,
              branch: branch_name,
              category: "coding",
              type: "file",
              is_write: rand < 0.6,
              lines: lines_in_file,
              lineno: rand(1..lines_in_file),
              cursorpos: rand(0..120),
              line_additions: rand < 0.4 ? rand(1..50) : 0,
              line_deletions: rand < 0.3 ? rand(1..20) : 0,
              user_agent: ua,
              source_type: 0,
              created_at: timestamp,
              updated_at: timestamp,
            }

            total_inserted += 1

            if batch.size >= BATCH_SIZE
              Heartbeat.insert_all(batch)
              batch = []
            end
          end

          # Maybe switch project between sessions
          session_project = user_projects.sample if rand < 0.4
        end
      end

      # Pad remaining heartbeats if daily walk didn't reach quota
      while total_inserted < HBS_PER_USER
        proj = user_projects.sample
        lang = proj[:langs].sample
        ext = ext_map[lang] || "txt"
        timestamp = ONE_YEAR_AGO + rand(0..364).days + rand(8..22).hours + rand(0..3599).seconds

        batch << {
          user_id: user.id,
          time: timestamp.to_f,
          entity: "#{proj[:entities_prefix]}/#{file_names.sample}.#{ext}",
          project: proj[:name],
          language: lang,
          editor: rand < 0.85 ? primary_editor : editors.sample,
          operating_system: rand < 0.95 ? primary_os : oses.sample,
          machine: rand < 0.9 ? primary_machine : machines.sample,
          branch: branches.sample,
          category: "coding",
          type: "file",
          is_write: rand < 0.6,
          lines: rand(20..2000),
          lineno: rand(1..500),
          cursorpos: rand(0..120),
          line_additions: rand < 0.4 ? rand(1..50) : 0,
          line_deletions: rand < 0.3 ? rand(1..20) : 0,
          user_agent: user_agents.sample,
          source_type: 0,
          created_at: timestamp,
          updated_at: timestamp,
        }

        total_inserted += 1

        if batch.size >= BATCH_SIZE
          Heartbeat.insert_all(batch)
          batch = []
        end
      end

      # Flush remaining
      Heartbeat.insert_all(batch) if batch.any?

      elapsed = Time.current - start_time
      rate = ((i + 1) * HBS_PER_USER) / elapsed
      eta = ((NUM_USERS - i - 1) * HBS_PER_USER) / rate
      puts "#{i + 1}/#{NUM_USERS}: #{user.username} (#{total_inserted} hbs) | #{elapsed.round(1)}s elapsed | ETA: #{eta.round(0)}s"
    end

    elapsed = Time.current - start_time
    puts "\nDone! Created #{TOTAL_HEARTBEATS} heartbeats across #{NUM_USERS} users in #{elapsed.round(1)}s"
  end

  desc "Remove seed mass heartbeat users and their data"
  task remove_mass_heartbeats: :environment do
    ids = User.where("github_uid LIKE ?", "seed_%").ids
    return puts "No seed users found." if ids.empty?

    puts "Removing #{ids.count} seed users and their heartbeats..."
    Heartbeat.unscoped.where(user_id: ids).delete_all
    LeaderboardEntry.where(user_id: ids).delete_all
    User.where(id: ids).delete_all
    puts "Done! Removed #{ids.count} seed users."
  end
end

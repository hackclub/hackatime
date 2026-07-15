# frozen_string_literal: true

namespace :seed do
  TO_COPY = %w[entity type category project project_root_count branch language dependencies
                lines line_additions line_deletions lineno cursorpos is_write editor
                operating_system machine user_agent source_type].freeze

  task dummy_users: :environment do
    # Faker is in the :development, :test group, so require it inside the task
    # body rather than at file load — otherwise any rake invocation in
    # production (e.g. migrations) would LoadError on this file.
    require "faker"

    src_user_id = ENV.fetch("FROM", 2).to_i
    # most times the second user is the dev, as first place is taken up by seed file
    # if you wanna manually pick a different user, use this:
    # bin/rails seed:dummy_users FROM=69420
    src = Clickhouse::Heartbeat.where(user_id: src_user_id).limit(500)
      .map { |h| h.attributes.slice(*TO_COPY) }
    abort "nothing to clone" if src.empty?

    puts "using the power of magic, we create 100 dummy users from #{src.count} source heartbeats..."

    100.times do |i|
      u = User.create!(username: "#{Faker::Creature::Animal.name.delete(' ')}#{rand(1000..9999)}",
                       github_uid: "dummy_#{SecureRandom.hex(8)}")

      hbs = src.sample(rand(50..200)).map do |h|
        t = rand(24.hours.ago..Time.current)
        h.merge("user_id" => u.id, "time" => t.to_f, "created_at" => t, "updated_at" => t)
      end

      Clickhouse::HeartbeatWriter.insert_rows(hbs) if hbs.any?
      puts "#{i + 1}/100: #{u.username} (#{hbs.count} hbs)"
    end
  end

  task remove_dummy_users: :environment do
    ids = User.where("github_uid LIKE ?", "dummy_%").ids
    return puts "no dummies found (except for you)" if ids.empty?

    Clickhouse::Heartbeat.connection.execute("DELETE FROM heartbeats WHERE user_id IN (#{ids.map(&:to_i).join(', ')})")
    LeaderboardEntry.where(user_id: ids).delete_all
    User.where(id: ids).delete_all
    puts "exploded #{ids.count} dummies"
  end
end

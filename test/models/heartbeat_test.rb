require "test_helper"

class HeartbeatTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  setup do
    Rails.cache.clear
    clear_enqueued_jobs
    @original_queue_adapter = ActiveJob::Base.queue_adapter
    ActiveJob::Base.queue_adapter = :test
  end

  teardown do
    Rails.cache.clear
    clear_enqueued_jobs
    ActiveJob::Base.queue_adapter = @original_queue_adapter
  end

  test "home_folder_project_root finds projects named after a home folder" do
    found = {
      [ "C:/Users/kevin/Desktop/Code/game/main.py", "kevin", 3 ] => "C:/Users/kevin",
      [ "C:\\Users\\kevin\\Desktop\\main.py", "Kevin", 3 ] => "C:/Users/kevin",
      [ "C:/Users/kevin/Desktop/main.py", "Users", 2 ] => "C:/Users",
      [ "/Users/kevin/code/app.rb", "kevin", 3 ] => "/Users/kevin",
      [ "/home/kevin/code/app.rb", "kevin", 3 ] => "/home/kevin",
      [ "/mnt/c/Users/kevin/code/app.rb", "kevin", 5 ] => "/mnt/c/Users/kevin",
      [ "/root/code/app.rb", "root", 2 ] => "/root"
    }
    found.each do |(entity, project, project_root_count), folder|
      assert_equal folder, Heartbeat.home_folder_project_root(entity:, project:, project_root_count:), entity
    end

    ignored = [
      [ "/home/kevin/code/app/app.rb", "app", 5 ],
      [ "C:/Code/game/main.py", "game", 3 ],
      [ "/home/kevin/code/app.rb", "dotfiles", 3 ],
      [ "/home/kevin/.zshrc", "kevin", 3 ],
      [ "C:/Users/kevin/AppData/Local/Temp/x.py", "kevin", 3 ],
      [ "/Users/kevin/Library/Application Support/x.json", "kevin", 3 ],
      [ "/home/kevin", "kevin", 3 ],
      [ "C:/Users/kevin/script.py", "kevin", 3 ],
      [ "C:/Users/kevin/Desktop/", "kevin", 3 ],
      [ "/home/kevin/code/app.rb", "kevin", nil ],
      [ "/home/kevin/code/app.rb", "", 3 ]
    ]
    ignored.each do |entity, project, project_root_count|
      assert_nil Heartbeat.home_folder_project_root(entity:, project:, project_root_count:), entity
    end
  end

  test "soft delete hides record from default scope and restore brings it back" do
    user = create(:user)
    heartbeat = create(:heartbeat, user: user,
      entity: "src/main.rb",
      type: "file",
      category: "coding",
      time: Time.current.to_f,
      project: "heartbeat-test",
      source_type: :test_entry
    )

    assert_includes Heartbeat.all, heartbeat

    heartbeat.soft_delete

    assert_not_includes Heartbeat.all, heartbeat
    assert_includes Heartbeat.with_deleted, heartbeat

    heartbeat.restore

    assert_includes Heartbeat.all, heartbeat
  end

  test "daily streaks only drop browser time when asked" do
    user = create(:user, username: "hb_streak_cache")
    create_heartbeat_sequence(user: user, started_at: 1.day.ago.beginning_of_day + 9.hours, editor: "firefox")

    assert_equal 1, Heartbeat.daily_streaks_for_users([ user.id ])[user.id]
    assert_equal 0, Heartbeat.daily_streaks_for_users([ user.id ], exclude_browser_time: true)[user.id]
  end

  test "daily streaks preserve each user's day boundaries" do
    travel_to Time.utc(2026, 10, 18, 2) do
      utc_user = create(:user, timezone: "UTC")
      new_york_user = create(:user, timezone: "America/New_York")
      users = [ utc_user, new_york_user ]

      users.each do |user|
        # This session qualifies on 16 October in New York, but splits into
        # two sessions shorter than 15 minutes across midnight in UTC.
        create_heartbeat_sequence(user: user, started_at: Time.utc(2026, 10, 16, 23, 50), editor: "vscode")
        create_heartbeat_sequence(user: user, started_at: Time.utc(2026, 10, 17, 12), editor: "vscode")
      end

      assert_equal({ utc_user.id => 1, new_york_user.id => 2 },
        Heartbeat.daily_streaks_for_users(users.map(&:id)))
    end
  end

  test "daily streaks count today once it reaches 15 minutes and stop at the first short day" do
    travel_to Time.utc(2026, 10, 18, 20) do
      waiting = create(:user, timezone: "UTC")
      done = create(:user, timezone: "UTC")

      [ waiting, done ].each do |user|
        create_heartbeat_sequence(user: user, started_at: Time.utc(2026, 10, 14, 9), editor: "vscode")
        create_heartbeat_sequence(user: user, started_at: Time.utc(2026, 10, 15, 9), editor: "vscode", count: 8)
        create_heartbeat_sequence(user: user, started_at: Time.utc(2026, 10, 16, 9), editor: "vscode")
        create_heartbeat_sequence(user: user, started_at: Time.utc(2026, 10, 17, 9), editor: "vscode")
      end
      # Eight heartbeats two minutes apart are 14 minutes; nine are 16.
      create_heartbeat_sequence(user: waiting, started_at: Time.utc(2026, 10, 18, 9), editor: "vscode", count: 8)
      create_heartbeat_sequence(user: done, started_at: Time.utc(2026, 10, 18, 9), editor: "vscode")

      assert_equal({ waiting.id => 2, done.id => 3 }, Heartbeat.daily_streaks_for_users([ waiting.id, done.id ]))
    end
  end

  test "daily streaks round a day's activity to the nearest second" do
    travel_to Time.utc(2026, 10, 18, 20) do
      user = create(:user, timezone: "UTC")
      # 14 minutes from eight heartbeats, then 59.6 seconds more.
      create_heartbeat_sequence(user: user, started_at: Time.utc(2026, 10, 17, 9), editor: "vscode", count: 8)
      create(:heartbeat, user: user, entity: "src/vscode.rb", type: "file", category: "coding", editor: "vscode",
        time: (Time.utc(2026, 10, 17, 9, 14) + 59.6.seconds).to_f, project: "heartbeat-test", source_type: :test_entry)

      assert_equal 1, user.streak_days
    end
  end

  test "daily streaks count every day back to the first short one" do
    travel_to Time.utc(2026, 10, 18, 20) do
      user = create(:user, timezone: "UTC")
      40.times { |days_ago| create_heartbeat_sequence(user: user, started_at: Time.utc(2026, 10, 18, 9) - days_ago.days, editor: "vscode") }

      assert_equal 40, user.streak_days
    end
  end

  test "attributed_durations_by sums to total duration when every heartbeat has the field" do
    user = create(:user)
    base = Time.current.to_i.to_f
    languages = %w[ruby ruby python python javascript]
    languages.each_with_index do |lang, i|
      create(:heartbeat, user: user,
        entity: "src/#{lang}.rb",
        type: "file",
        category: "coding",
        editor: "vscode",
        language: lang,
        time: base + (i * 60),
        project: "attribution-full",
        source_type: :test_entry
      )
    end

    scope = user.heartbeats.where(project: "attribution-full")
    buckets = Heartbeat.attributed_durations_by(scope, :language)
    total = scope.duration_seconds

    assert_equal 240, total
    assert_equal({ "ruby" => 60, "python" => 120, "javascript" => 60 }, buckets)
    assert_equal total, buckets.values.sum
    assert_not_includes buckets.keys, "Unknown"
    assert_not_includes buckets.keys, nil
    assert_not_includes buckets.keys, ""
  end

  test "attributed_durations_by excludes NULL/blank field values without inventing an Unknown bucket" do
    user = create(:user)
    base = Time.current.to_i.to_f
    rows = [
      { language: "ruby",   offset: 0   },
      { language: "ruby",   offset: 60  },
      { language: nil,      offset: 120 }, # NULL — excluded from buckets
      { language: "",       offset: 180 }, # blank — excluded from buckets
      { language: "python", offset: 240 }
    ]
    rows.each do |r|
      create(:heartbeat, user: user,
        entity: "src/file.rb",
        type: "file",
        category: "coding",
        editor: "vscode",
        language: r[:language],
        time: base + r[:offset],
        project: "attribution-nulls",
        source_type: :test_entry
      )
    end

    scope = user.heartbeats.where(project: "attribution-nulls")
    buckets = Heartbeat.attributed_durations_by(scope, :language)
    total = scope.duration_seconds

    assert_equal 240, total
    assert_equal({ "ruby" => 60, "python" => 60 }, buckets)
    assert_equal total - 120, buckets.values.sum
    assert_not_includes buckets.keys, "Unknown"
    assert_not_includes buckets.keys, nil
    assert_not_includes buckets.keys, ""
  end

  test "distinct_values lists a relation's distinct non-null values like DISTINCT" do
    user = create(:user)
    other = create(:user)
    base = Time.current.to_i.to_f
    [ [ user, "Ruby", "a" ], [ user, "ruby", "a" ], [ user, nil, "b" ], [ user, "", "b" ], [ user, "Go", "b" ],
      [ user, "Rust", "c" ], [ other, "Elixir", "a" ] ].each_with_index do |(owner, language, project), index|
      create(:heartbeat, user: owner, language:, project:, entity: "f#{index}.rb", time: base + index, source_type: :test_entry)
    end
    user.heartbeats.find_by!(language: "Rust").soft_delete
    scope = user.heartbeats.where(project: %w[a b c])

    assert_equal scope.distinct.pluck(:language).compact.sort, scope.distinct_values(:language).sort
    assert_equal [ "", "Go" ], user.heartbeats.where(project: "b").distinct_values(:language).sort
  end

  test "creating a heartbeat schedules a dashboard rollup refresh" do
    user = create(:user)

    assert_enqueued_with(job: DashboardRollupRefreshJob, args: [ user.id ]) do
      user.heartbeats.create!(
        entity: "src/main.rb",
        type: "file",
        category: "coding",
        editor: "vscode",
        time: Time.current.to_f,
        project: "heartbeat-test",
        source_type: :test_entry
      )
    end
  end

  private

  def create_heartbeat_sequence(user:, started_at:, editor:, count: 9)
    count.times do |offset|
      create(:heartbeat, user: user,
        entity: "src/#{editor}.rb",
        type: "file",
        category: "coding",
        editor: editor,
        time: (started_at + (offset * 2).minutes).to_f,
        project: "heartbeat-test",
        source_type: :test_entry
      )
    end
  end
end

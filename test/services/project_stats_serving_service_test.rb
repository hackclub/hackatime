require "test_helper"

class ProjectStatsServingServiceTest < ActiveSupport::TestCase
  test "builds project stats from serving tables" do
    user = User.create!(timezone: "UTC")
    base = Time.zone.local(2026, 7, 10, 12)

    create_heartbeat(
      user: user,
      time: base.to_f,
      project: "serving",
      language: "Ruby",
      editor: "vscode",
      operating_system: "macOS",
      category: "coding",
      entity: "app/models/user.rb",
      branch: "main",
      source_type: :test_entry
    )
    create_heartbeat(
      user: user,
      time: (base + 90.seconds).to_f,
      project: "serving",
      language: "Ruby",
      editor: "vscode",
      operating_system: "macOS",
      category: "coding",
      entity: "app/models/user.rb",
      branch: "main",
      source_type: :test_entry
    )

    queries = []
    subscriber = ActiveSupport::Notifications.subscribe("sql.clickhouse_serving") do |*, payload|
      queries << payload.fetch(:sql)
    end
    stats = ProjectStatsServingService.new(
      user: user,
      project: "serving",
      start_time: base.beginning_of_day,
      end_time: base.end_of_day
    ).call

    assert_equal 1, queries.size
    assert_equal 90, stats[:total_time]
    assert_equal 1, stats[:file_count]
    assert_equal({ "Ruby" => 90 }, stats[:language_stats])
    assert_equal({ "VSCode" => 90 }, stats[:editor_stats])
    assert_equal({ "macOS" => 90 }, stats[:os_stats])
    assert_equal({ "coding" => 90 }, stats[:category_stats])
    assert_equal([ [ "app/models/user.rb", 90 ] ], stats[:file_stats])
    assert_equal([ [ "main", 90 ] ], stats[:branch_stats])
  ensure
    ActiveSupport::Notifications.unsubscribe(subscriber) if subscriber
  end

  test "attributes project intervals to the current heartbeat dimension" do
    user = User.create!(timezone: "UTC")
    base = Time.zone.local(2026, 7, 10, 12)

    create_heartbeat(user: user, time: base.to_f, project: "mixed", language: "Ruby", category: "coding", source_type: :test_entry)
    create_heartbeat(user: user, time: (base + 60.seconds).to_f, project: "mixed", language: "Python", category: "coding", source_type: :test_entry)
    create_heartbeat(user: user, time: (base + 120.seconds).to_f, project: "mixed", language: "Ruby", category: "coding", source_type: :test_entry)

    stats = ProjectStatsServingService.new(
      user: user,
      project: "mixed",
      start_time: base.beginning_of_day,
      end_time: base.end_of_day
    ).call

    assert_equal({ "Ruby" => 60, "Python" => 60 }, stats[:language_stats])
    assert_equal 120, Clickhouse::StatsReader.new(user).total_seconds(
      start_time: base.beginning_of_day,
      end_time: base.end_of_day,
      filters: { language: "Ruby" }
    )
  end

  test "file count includes empty entities but excludes null entities" do
    user = User.create!(timezone: "UTC")
    base = Time.zone.local(2026, 7, 10, 12)

    create_heartbeat(user: user, time: base.to_f, project: "entities", entity: "app.rb", source_type: :test_entry)
    create_heartbeat(user: user, time: (base + 60.seconds).to_f, project: "entities", entity: "", source_type: :test_entry)
    create_heartbeat(user: user, time: (base + 120.seconds).to_f, project: "entities", entity: nil, source_type: :test_entry)

    raw = ProjectStatsService.new(Clickhouse::Heartbeat.for_user(user).where(project: "entities")).call
    serving = ProjectStatsServingService.new(user: user, project: "entities").call

    assert_equal 2, raw[:file_count]
    assert_equal raw, serving
  end
end

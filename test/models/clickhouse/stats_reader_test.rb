require "test_helper"

class Clickhouse::StatsReaderTest < ActiveSupport::TestCase
  test "reads user project and dimension totals from serving tables" do
    user = User.create!(timezone: "UTC")
    base = Time.zone.local(2026, 7, 10, 12)

    create_heartbeat(
      user: user,
      time: base.to_f,
      project: "reader",
      language: "Ruby",
      editor: "vscode",
      operating_system: "macOS",
      machine: "devbox",
      category: "coding",
      source_type: :test_entry
    )
    create_heartbeat(
      user: user,
      time: (base + 75.seconds).to_f,
      project: "reader",
      language: "Ruby",
      editor: "vscode",
      operating_system: "macOS",
      machine: "devbox",
      category: "coding",
      source_type: :test_entry
    )

    reader = Clickhouse::StatsReader.new(user)
    range = { start_time: base.beginning_of_day, end_time: base.end_of_day }

    assert_equal 75, reader.total_seconds(**range)
    assert_equal 75, reader.total_seconds(**range, filters: { project: "reader" })
    assert_equal 75, reader.total_seconds(**range, filters: { language: "Ruby" })
    assert_equal 75, reader.total_seconds(**range, filters: { editor: "vscode" })
    assert_equal 75, reader.total_seconds(**range, filters: { machine: "devbox" })
    assert_equal 75, reader.project_seconds("reader")
    assert_equal({ "reader" => 75 }, reader.project_durations(**range))
    assert_equal({ "Ruby" => 75 }, reader.project_dimension_durations(project: "reader", dimension: :language, **range))
    assert_equal({ "devbox" => 75 }, reader.dimension_durations(dimension: :machine, **range))
  end

  test "reads project durations for multiple users from project summaries" do
    first_user = User.create!(timezone: "UTC")
    second_user = User.create!(timezone: "UTC")
    base = Time.zone.local(2026, 7, 10, 12)

    create_heartbeat(user: first_user, time: base.to_f, project: "alpha", language: "Ruby", category: "coding", source_type: :test_entry)
    create_heartbeat(user: first_user, time: (base + 60.seconds).to_f, project: "alpha", language: "Ruby", category: "coding", source_type: :test_entry)
    create_heartbeat(user: second_user, time: base.to_f, project: "beta", language: "Ruby", category: "coding", source_type: :test_entry)
    create_heartbeat(user: second_user, time: (base + 90.seconds).to_f, project: "beta", language: "Ruby", category: "coding", source_type: :test_entry)

    assert_equal(
      {
        first_user.id => { "alpha" => 60 },
        second_user.id => { "beta" => 90 }
      },
      Clickhouse::HeartbeatProjectSummary.durations_for_users([ first_user.id, second_user.id ])
    )
  end

  test "preserves blank projects for stats Other bucket" do
    user = User.create!(timezone: "UTC")
    base = Time.zone.local(2026, 7, 10, 12)

    create_heartbeat(user:, time: base.to_f, project: "", category: "coding", source_type: :test_entry)
    create_heartbeat(user:, time: (base + 75.seconds).to_f, project: "", category: "coding", source_type: :test_entry)

    range = { start_time: base.beginning_of_day, end_time: base.end_of_day }
    reader = Clickhouse::StatsReader.new(user)
    summary = WakatimeService.new(
      user:, specific_filters: [ :projects ], allow_cache: false,
      start_date: range.fetch(:start_time), end_date: range.fetch(:end_time)
    ).generate_summary

    assert_equal({ "" => 75 }, reader.project_durations(**range))
    assert_equal [ { name: "Other", total_seconds: 75 } ],
      summary.fetch(:projects).map { |project| project.slice(:name, :total_seconds) }
  end

  test "rejects unsupported combined filters instead of silently using the wrong summary" do
    reader = Clickhouse::StatsReader.new(123)

    assert_raises(ArgumentError) do
      reader.total_seconds(filters: { project: "reader", language: "Ruby" })
    end
  end

  test "uses half open day ranges and rejects multi value totals" do
    user = User.create!(timezone: "UTC")
    first_day = Time.zone.local(2026, 7, 10, 12)
    second_day = Time.zone.local(2026, 7, 11, 12)

    create_heartbeat(user: user, time: first_day.to_f, project: "alpha", language: "Ruby", category: "coding", source_type: :test_entry)
    create_heartbeat(user: user, time: (first_day + 60.seconds).to_f, project: "alpha", language: "Ruby", category: "coding", source_type: :test_entry)
    create_heartbeat(user: user, time: second_day.to_f, project: "beta", language: "Python", category: "coding", source_type: :test_entry)
    create_heartbeat(user: user, time: (second_day + 90.seconds).to_f, project: "beta", language: "Python", category: "coding", source_type: :test_entry)

    reader = Clickhouse::StatsReader.new(user)

    assert_equal 60, reader.total_seconds(start_time: first_day.to_date, end_time: second_day.to_date)
    assert_raises(ArgumentError) do
      reader.total_seconds(start_time: first_day.to_date, end_time: (second_day + 1.day).to_date, filters: { project: %w[alpha beta] })
    end
    assert_equal 270, reader.total_seconds(start_time: first_day.to_date, end_time: (second_day + 1.day).to_date, filters: { category: [ "coding" ] })
  end

  test "bounded serving reads remove the interval entering the range" do
    user = User.create!(timezone: "UTC")
    before_range = Time.utc(2026, 7, 10, 23, 59)
    range_start = Time.utc(2026, 7, 11).beginning_of_day
    range_end = range_start + 1.day

    create_heartbeat(user: user, time: before_range.to_f, project: "boundary", language: "Ruby", category: "coding", source_type: :test_entry)
    create_heartbeat(user: user, time: (before_range + 60.seconds).to_f, project: "boundary", language: "Python", category: "coding", source_type: :test_entry)
    create_heartbeat(user: user, time: (before_range + 120.seconds).to_f, project: "boundary", language: "Ruby", category: "coding", source_type: :test_entry)

    raw = Clickhouse::Heartbeat.for_user(user).where("time >= ? AND time < ?", range_start.to_f, range_end.to_f)
    raw_project = raw.where(project: "boundary")
    reader = Clickhouse::StatsReader.new(user)

    assert_equal raw.duration_seconds, reader.total_seconds(start_time: range_start, end_time: range_end)
    assert_equal raw_project.duration_seconds, reader.total_seconds(
      start_time: range_start, end_time: range_end, filters: { project: "boundary" }
    )
    assert_equal raw.where(language: "Ruby").duration_seconds, reader.total_seconds(
      start_time: range_start, end_time: range_end, filters: { language: "Ruby" }
    )
    assert_equal Clickhouse::Heartbeat.attributed_durations_by(raw, :language), reader.dimension_durations(
      dimension: :language, start_time: range_start, end_time: range_end
    )
    assert_equal Clickhouse::Heartbeat.attributed_durations_by(raw_project, :language), reader.project_dimension_durations(
      project: "boundary", dimension: :language, start_time: range_start, end_time: range_end
    )
  end

  test "keeps null and empty dimension filter sequences distinct" do
    user = User.create!(timezone: "UTC")
    base = Time.utc(2026, 7, 10, 12)
    day_range = { start_time: base.beginning_of_day, end_time: base.end_of_day }

    [ nil, "", nil, "" ].each_with_index do |language, index|
      create_heartbeat(
        user: user, time: (base + index.minutes).to_f, project: "blank-values",
        language: language, category: "coding", source_type: :test_entry
      )
    end

    reader = Clickhouse::StatsReader.new(user)

    assert_equal({ nil => 120, "" => 120 }, reader.filter_durations(dimension: :language, **day_range))
    assert_equal({}, reader.dimension_durations(dimension: :language, **day_range))
  end
end

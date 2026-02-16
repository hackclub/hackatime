require "test_helper"

class ProjectStatsQueryTest < ActiveSupport::TestCase
  def setup
    @user = User.create!(username: "pq_#{SecureRandom.hex(4)}")
  end

  test "project details supports start and end aliases" do
    in_range_time = 3.days.ago.to_f
    out_of_range_time = 15.days.ago.to_f

    create_heartbeat(project: "alpha", language: "Ruby", time: in_range_time)
    create_heartbeat(project: "alpha", language: "Ruby", time: out_of_range_time)

    query = ProjectStatsQuery.new(
      user: @user,
      params: {
        start: 7.days.ago.iso8601,
        end: 1.day.ago.iso8601
      }
    )

    project = query.project_details(names: [ "alpha" ]).first

    assert_equal "alpha", project[:name]
    assert_equal 1, project[:total_heartbeats]
    assert_equal Time.at(in_range_time).utc.strftime("%Y-%m-%dT%H:%M:%SZ"), project[:most_recent_heartbeat]
  end

  test "project names supports since and until filters" do
    create_heartbeat(project: "old_project", time: 20.days.ago.to_f)
    create_heartbeat(project: "new_project", time: 2.days.ago.to_f)

    query = ProjectStatsQuery.new(
      user: @user,
      params: {
        since: 7.days.ago.iso8601,
        until: 1.day.ago.iso8601
      }
    )

    assert_equal [ "new_project" ], query.project_names
  end

  test "project details hides archived projects unless include_archived is true" do
    create_heartbeat(project: "archived_project", language: "Ruby", time: 2.days.ago.to_f)
    mapping = ProjectRepoMapping.create!(user: @user, project_name: "archived_project")
    mapping.archive!

    excluded = ProjectStatsQuery.new(user: @user, params: {})
    included = ProjectStatsQuery.new(user: @user, params: {}, include_archived: true)

    assert_equal [], excluded.project_details(names: [ "archived_project" ])
    assert included.project_details(names: [ "archived_project" ]).first[:archived]
  end

  test "parse_datetime returns Time objects for string datetime values" do
    query = ProjectStatsQuery.new(user: @user, params: { start: "2024-01-15T10:30:00Z" })
    parsed = query.send(:parse_datetime, "2024-01-15T10:30:00Z")

    assert_instance_of ActiveSupport::TimeWithZone, parsed
    assert_equal Time.zone.parse("2024-01-15T10:30:00Z"), parsed
  end

  test "parse_datetime converts DateTime objects to Time using in_time_zone" do
    dt = DateTime.new(2024, 1, 15, 10, 30, 0)
    query = ProjectStatsQuery.new(user: @user, params: {})
    parsed = query.send(:parse_datetime, dt)

    assert_instance_of ActiveSupport::TimeWithZone, parsed
    assert_equal dt.in_time_zone, parsed
  end

  test "parse_datetime preserves Time objects correctly using in_time_zone" do
    time = Time.zone.parse("2024-01-15T10:30:00Z")
    query = ProjectStatsQuery.new(user: @user, params: {})
    parsed = query.send(:parse_datetime, time)

    assert_instance_of ActiveSupport::TimeWithZone, parsed
    assert_equal time, parsed
  end

  test "parse_datetime returns nil for blank values" do
    query = ProjectStatsQuery.new(user: @user, params: {})

    assert_nil query.send(:parse_datetime, nil)
    assert_nil query.send(:parse_datetime, "")
    assert_nil query.send(:parse_datetime, "   ")
  end

  test "parse_datetime returns nil for invalid datetime strings" do
    query = ProjectStatsQuery.new(user: @user, params: {})

    assert_nil query.send(:parse_datetime, "invalid-date")
    assert_nil query.send(:parse_datetime, "not a date")
  end

  test "range construction with parsed datetime values works without ArgumentError" do
    # This test specifically addresses the bug that was causing 500 errors
    start_time = DateTime.new(2024, 1, 1, 0, 0, 0)
    end_time = DateTime.new(2024, 1, 31, 23, 59, 59)

    create_heartbeat(project: "test_project", time: Time.zone.parse("2024-01-15").to_f)

    query = ProjectStatsQuery.new(
      user: @user,
      params: {
        start: start_time,
        end: end_time
      }
    )

    # This should not raise ArgumentError: bad value for range
    assert_nothing_raised do
      projects = query.project_details(names: [ "test_project" ])
      assert_equal 1, projects.size
      assert_equal "test_project", projects.first[:name]
    end
  end

  private

  def create_heartbeat(project:, time:, language: nil)
    Heartbeat.create!(
      user: @user,
      source_type: :direct_entry,
      category: "coding",
      project: project,
      language: language,
      time: time
    )
  end
end

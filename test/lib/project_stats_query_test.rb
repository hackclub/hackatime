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

  test "parse_datetime handles string datetime values" do
    query = ProjectStatsQuery.new(user: @user, params: {})
    
    # Test ISO 8601 string
    result = query.send(:parse_datetime, "2024-01-15T10:30:00Z")
    assert_instance_of Time, result
    assert_equal Time.zone.parse("2024-01-15T10:30:00Z"), result
    
    # Test various date string formats
    result = query.send(:parse_datetime, "2024-01-15")
    assert_instance_of Time, result
    assert_equal Time.zone.parse("2024-01-15"), result
  end

  test "parse_datetime handles DateTime objects" do
    query = ProjectStatsQuery.new(user: @user, params: {})
    
    datetime_obj = DateTime.new(2024, 1, 15, 10, 30, 0)
    result = query.send(:parse_datetime, datetime_obj)
    
    assert_instance_of Time, result
    assert_equal datetime_obj.in_time_zone, result
  end

  test "parse_datetime handles Time objects" do
    query = ProjectStatsQuery.new(user: @user, params: {})
    
    time_obj = Time.zone.parse("2024-01-15T10:30:00Z")
    result = query.send(:parse_datetime, time_obj)
    
    assert_instance_of Time, result
    assert_equal time_obj, result
  end

  test "parse_datetime handles blank and nil values" do
    query = ProjectStatsQuery.new(user: @user, params: {})
    
    assert_nil query.send(:parse_datetime, nil)
    assert_nil query.send(:parse_datetime, "")
    assert_nil query.send(:parse_datetime, "   ")
  end

  test "parse_datetime handles invalid values gracefully" do
    query = ProjectStatsQuery.new(user: @user, params: {})
    
    # Test invalid date string
    assert_nil query.send(:parse_datetime, "not-a-date")
    
    # Test invalid format
    assert_nil query.send(:parse_datetime, "2024-99-99")
  end

  test "scoped_heartbeats range construction works with parsed datetime values" do
    # Create heartbeats at different times
    create_heartbeat(project: "project1", time: 5.days.ago.to_f)
    create_heartbeat(project: "project2", time: 3.days.ago.to_f)
    create_heartbeat(project: "project3", time: 15.days.ago.to_f)
    
    # Test with string datetime parameters
    query = ProjectStatsQuery.new(
      user: @user,
      params: {
        start: 7.days.ago.iso8601,
        end: 1.day.ago.iso8601
      }
    )
    
    projects = query.project_names
    assert_includes projects, "project1"
    assert_includes projects, "project2"
    assert_not_includes projects, "project3"
  end

  test "scoped_heartbeats works with DateTime objects in params" do
    # Create heartbeats
    create_heartbeat(project: "recent", time: 3.days.ago.to_f)
    create_heartbeat(project: "old", time: 15.days.ago.to_f)
    
    # Test with DateTime objects (simulating what might come from certain form inputs)
    start_datetime = DateTime.parse(7.days.ago.iso8601)
    end_datetime = DateTime.parse(1.day.ago.iso8601)
    
    query = ProjectStatsQuery.new(
      user: @user,
      params: {
        start: start_datetime,
        end: end_datetime
      }
    )
    
    projects = query.project_names
    assert_includes projects, "recent"
    assert_not_includes projects, "old"
  end

  test "scoped_heartbeats works with Time objects in params" do
    # Create heartbeats
    create_heartbeat(project: "recent", time: 3.days.ago.to_f)
    create_heartbeat(project: "old", time: 15.days.ago.to_f)
    
    # Test with Time objects
    start_time = 7.days.ago
    end_time = 1.day.ago
    
    query = ProjectStatsQuery.new(
      user: @user,
      params: {
        start: start_time,
        end: end_time
      }
    )
    
    projects = query.project_names
    assert_includes projects, "recent"
    assert_not_includes projects, "old"
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

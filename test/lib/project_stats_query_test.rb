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

  test "project names supports since filter with default end time" do
    create_heartbeat(project: "old_project", time: 20.days.ago.to_f)
    create_heartbeat(project: "new_project", time: 2.days.ago.to_f)

    query = ProjectStatsQuery.new(
      user: @user,
      params: {
        since: 7.days.ago.iso8601
      }
    )

    assert_equal [ "new_project" ], query.project_names
  end

  test "project details supports numeric default start values" do
    in_range_time = 3.days.ago.to_f
    create_heartbeat(project: "alpha", language: "Ruby", time: in_range_time)

    query = ProjectStatsQuery.new(
      user: @user,
      params: {},
      default_discovery_start: 0,
      default_stats_start: 0
    )

    project = query.project_details(names: [ "alpha" ]).first

    assert_equal "alpha", project[:name]
    assert_equal Time.at(in_range_time).utc.strftime("%Y-%m-%dT%H:%M:%SZ"), project[:most_recent_heartbeat]
  end

  test "project names excludes archived projects unless include_archived is true" do
    create_heartbeat(project: "active_project", time: 2.days.ago.to_f)
    create_heartbeat(project: "archived_project", time: 2.days.ago.to_f)

    archived_mapping = ProjectRepoMapping.create!(user: @user, project_name: "archived_project")
    archived_mapping.archive!

    excluded = ProjectStatsQuery.new(user: @user, params: {})
    included = ProjectStatsQuery.new(user: @user, params: {}, include_archived: true)

    assert_equal [ "active_project" ], excluded.project_names
    assert_equal [ "active_project", "archived_project" ], included.project_names.sort
  end

  test "project details uses projects csv params when explicit names are not provided" do
    create_heartbeat(project: "alpha", language: "Ruby", time: 2.days.ago.to_f)
    create_heartbeat(project: "beta", language: "Go", time: 2.days.ago.to_f)

    query = ProjectStatsQuery.new(
      user: @user,
      params: {
        projects: " alpha, beta,alpha, ,"
      },
      default_discovery_start: 0,
      default_stats_start: 0
    )

    project_names = query.project_details.map { |project| project[:name] }
    assert_equal [ "alpha", "beta" ], project_names.sort
  end

  test "project details normalizes explicit names list" do
    create_heartbeat(project: "alpha", language: "Ruby", time: 2.days.ago.to_f)
    create_heartbeat(project: "beta", language: "Ruby", time: 2.days.ago.to_f)

    query = ProjectStatsQuery.new(user: @user, params: {}, default_discovery_start: 0, default_stats_start: 0)

    details = query.project_details(names: [ " alpha ", "alpha", "", nil, :beta ])
    names = details.map { |project| project[:name] }

    assert_equal [ "alpha", "beta" ], names.sort
  end

  test "project details computes total_seconds and returns heartbeat metadata" do
    base = 5.days.ago.to_f
    create_heartbeat(project: "alpha", language: "Ruby", time: base)
    create_heartbeat(project: "alpha", language: "Ruby", time: base + 30)
    create_heartbeat(project: "alpha", language: "TypeScript", time: base + 90)
    create_heartbeat(project: "alpha", language: nil, time: base + 120)

    query = ProjectStatsQuery.new(user: @user, params: {}, default_discovery_start: 0, default_stats_start: 0)

    project = query.project_details(names: [ "alpha" ]).first

    assert_equal 120, project[:total_seconds]
    assert_equal 4, project[:total_heartbeats]
    assert_equal [ "Ruby", "TypeScript" ], project[:languages].sort
    assert_equal formatted_time(base), project[:first_heartbeat]
    assert_equal formatted_time(base + 120), project[:last_heartbeat]
    assert_equal project[:last_heartbeat], project[:most_recent_heartbeat]
  end

  test "project details sorts projects by total_seconds descending" do
    base = 4.days.ago.to_f
    create_heartbeat(project: "alpha", time: base)
    create_heartbeat(project: "alpha", time: base + 90)

    create_heartbeat(project: "beta", time: base)
    create_heartbeat(project: "beta", time: base + 20)

    query = ProjectStatsQuery.new(user: @user, params: {}, default_discovery_start: 0, default_stats_start: 0)

    details = query.project_details(names: [ "alpha", "beta" ])
    assert_equal [ "alpha", "beta" ], details.map { |project| project[:name] }
  end

  test "project details ignores out-of-range timestamps from with_valid_timestamps scope" do
    valid_time = 2.days.ago.to_f
    create_heartbeat(project: "alpha", language: "Ruby", time: valid_time)
    create_heartbeat(project: "alpha", language: "Ruby", time: -1)
    create_heartbeat(project: "alpha", language: "Ruby", time: 253402300800)

    query = ProjectStatsQuery.new(user: @user, params: {}, default_discovery_start: 0, default_stats_start: 0)
    project = query.project_details(names: [ "alpha" ]).first

    assert_equal 1, project[:total_heartbeats]
    assert_equal 0, project[:total_seconds]
    assert_equal formatted_time(valid_time), project[:first_heartbeat]
    assert_equal formatted_time(valid_time), project[:last_heartbeat]
  end

  test "project names supports until_date alias" do
    create_heartbeat(project: "older_project", time: 20.days.ago.to_f)
    create_heartbeat(project: "newer_project", time: 2.days.ago.to_f)

    query = ProjectStatsQuery.new(
      user: @user,
      params: {
        since: 30.days.ago.iso8601,
        until_date: 7.days.ago.iso8601
      }
    )

    assert_equal [ "older_project" ], query.project_names
  end

  test "invalid date params fall back to provided defaults for project details" do
    in_range_time = 3.days.ago.to_f
    out_of_range_time = 20.days.ago.to_f

    create_heartbeat(project: "alpha", language: "Ruby", time: in_range_time)
    create_heartbeat(project: "alpha", language: "Ruby", time: out_of_range_time)

    query = ProjectStatsQuery.new(
      user: @user,
      params: {
        start: "not-a-date",
        end: "still-not-a-date"
      },
      default_stats_start: 7.days.ago,
      default_stats_end: 1.day.ago
    )

    project = query.project_details(names: [ "alpha" ]).first
    assert_equal 1, project[:total_heartbeats]
    assert_equal formatted_time(in_range_time), project[:most_recent_heartbeat]
  end

  test "invalid date params fall back to provided defaults for project names" do
    create_heartbeat(project: "old_project", time: 20.days.ago.to_f)
    create_heartbeat(project: "new_project", time: 2.days.ago.to_f)

    query = ProjectStatsQuery.new(
      user: @user,
      params: {
        since: "not-a-date",
        until: "still-not-a-date"
      },
      default_discovery_start: 7.days.ago,
      default_discovery_end: 1.day.ago
    )

    assert_equal [ "new_project" ], query.project_names
  end

  test "project discovery uses since over start when both are provided" do
    create_heartbeat(project: "old_project", time: 10.days.ago.to_f)
    create_heartbeat(project: "new_project", time: 2.days.ago.to_f)

    query = ProjectStatsQuery.new(
      user: @user,
      params: {
        since: 3.days.ago.iso8601,
        start: 30.days.ago.iso8601
      }
    )

    assert_equal [ "new_project" ], query.project_names
  end

  test "project details supports start_date and end_date aliases" do
    in_range_time = 3.days.ago.to_f
    out_of_range_time = 15.days.ago.to_f

    create_heartbeat(project: "alpha", language: "Ruby", time: in_range_time)
    create_heartbeat(project: "alpha", language: "Ruby", time: out_of_range_time)

    query = ProjectStatsQuery.new(
      user: @user,
      params: {
        start_date: 7.days.ago.iso8601,
        end_date: 1.day.ago.iso8601
      }
    )

    project = query.project_details(names: [ "alpha" ]).first

    assert_equal 1, project[:total_heartbeats]
    assert_equal formatted_time(in_range_time), project[:most_recent_heartbeat]
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

  def formatted_time(time_value)
    Time.at(time_value).utc.strftime("%Y-%m-%dT%H:%M:%SZ")
  end
end

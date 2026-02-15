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

require "test_helper"

class ProjectRepoMappingTest < ActiveSupport::TestCase
  test "archive and unarchive toggle archived state" do
    user = User.create!
    mapping = user.project_repo_mappings.create!(project_name: "hackatime")

    assert_not mapping.archived?

    mapping.archive!
    assert mapping.reload.archived?

    mapping.unarchive!
    assert_not mapping.reload.archived?
  end

  test "project name must be unique per user" do
    user = User.create!
    user.project_repo_mappings.create!(project_name: "same-project")

    duplicate = user.project_repo_mappings.build(project_name: "same-project")

    assert_not duplicate.valid?
    assert_includes duplicate.errors[:project_name], "has already been taken"
  end
end

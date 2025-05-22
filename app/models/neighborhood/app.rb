class Neighborhood::App < ApplicationRecord
  self.table_name = "neighborhood_apps"

  include HasTableSync

  has_table_sync base: "appnsN4MzbnfMY0ai",
                 table: "tbls2fHyQYCtCbYbl",
                 pat: ENV["NEIGHBORHOOD_AIRTABLE_PAT"]

  def posts
    return [] unless airtable_fields["app"]&.first
    Neighborhood::Post.where(airtable_id: airtable_fields["app"])
  end

  def projects
    return [] unless airtable_fields["hackatimeProjects"]&.any?
    Neighborhood::Project.where(airtable_id: airtable_fields["hackatimeProjects"])
  end
end

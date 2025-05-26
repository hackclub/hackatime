class Neighborhood::App < ApplicationRecord
  self.table_name = "neighborhood_apps"

  include HasTableSync

  has_table_sync base: "appnsN4MzbnfMY0ai",
                 table: "tbls2fHyQYCtCbYbl",
                 pat: ENV["NEIGHBORHOOD_AIRTABLE_PAT"]

  def posts
    return [] unless airtable_fields["devlog"]&.any?
    Neighborhood::Post.where(airtable_id: airtable_fields["devlog"])
  end

  def projects
    return [] unless airtable_fields["hackatimeProjects"]&.any?
    Neighborhood::Project.where(airtable_id: airtable_fields["hackatimeProjects"])
  end

  def ysws_submission
    return nil unless airtable_fields["YSWS Project Submission"]&.first
    Neighborhood::YswsSubmission.find_by(airtable_id: airtable_fields["YSWS Project Submission"].first)
  end
end

class Neighborhood::Project < ApplicationRecord
  self.table_name = "neighborhood_projects"

  include HasTableSync

  has_table_sync base: "appnsN4MzbnfMY0ai",
                 table: "tblIqliBgKvoNT3uD",
                 pat: ENV["NEIGHBORHOOD_AIRTABLE_PAT"]
end

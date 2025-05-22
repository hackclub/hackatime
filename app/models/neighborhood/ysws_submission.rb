class Neighborhood::YswsSubmission < ApplicationRecord
  self.table_name = "neighborhood_ysws_submissions"

  include HasTableSync

  has_table_sync base: "appnsN4MzbnfMY0ai",
                 table: "tblbyu0FABZJ0wvaJ",
                 pat: ENV["NEIGHBORHOOD_AIRTABLE_PAT"]

  def app
    return nil unless airtable_fields["app"]&.first
    Neighborhood::App.find_by(airtable_id: airtable_fields["app"].first)
  end
end

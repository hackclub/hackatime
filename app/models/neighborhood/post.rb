class Neighborhood::Post < ApplicationRecord
  self.table_name = "neighborhood_posts"

  include HasTableSync

  has_table_sync base: "appnsN4MzbnfMY0ai",
                 table: "tbl0iKxglbySiEbB4",
                 pat: ENV["NEIGHBORHOOD_AIRTABLE_PAT"]

  def app
    return nil unless airtable_fields["app"]&.first
    Neighborhood::App.find_by(airtable_id: airtable_fields["app"].first)
  end
end

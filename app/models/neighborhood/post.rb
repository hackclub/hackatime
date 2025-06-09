class Neighborhood::Post < ApplicationRecord
  self.table_name = "neighborhood_posts"

  include HasTableSync

  BASE_ID = "appnsN4MzbnfMY0ai"
  TABLE_ID = "tbl0iKxglbySiEbB4"

  has_table_sync base: BASE_ID,
                 table: TABLE_ID,
                 pat: ENV["NEIGHBORHOOD_AIRTABLE_PAT"]

  def app
    return nil unless airtable_fields["app"]&.first
    Neighborhood::App.find_by(airtable_id: airtable_fields["app"].first)
  end

  def push_to_airtable!(fields)
    response = HTTP.patch(
      "https://api.airtable.com/v0/#{BASE_ID}/#{TABLE_ID}/#{airtable_id}",
      headers: {
        "Authorization" => "Bearer #{ENV["NEIGHBORHOOD_AIRTABLE_PAT"]}",
        "Content-Type" => "application/json"
      },
      json: { fields: fields }
    )
    new_fields = JSON.parse(response.body)["fields"]
    if response.status.success?
      update(airtable_fields: new_fields)
    else
      raise "Failed to push to Airtable: #{response.body}"
    end
  end
end

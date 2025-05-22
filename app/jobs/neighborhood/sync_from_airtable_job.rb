class Neighborhood::SyncFromAirtableJob < ApplicationJob
  queue_as :literally_whenever

  def perform
    Neighborhood::App.pull_all_from_airtable!
    Neighborhood::Project.pull_all_from_airtable!
    Neighborhood::Post.pull_all_from_airtable!
    Neighborhood::YswsSubmission.pull_all_from_airtable!
  end
end

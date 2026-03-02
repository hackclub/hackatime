class AddPublicProfileFieldsToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :display_name_override, :string
    add_column :users, :profile_bio, :text
    add_column :users, :profile_github_url, :string
    add_column :users, :profile_twitter_url, :string
    add_column :users, :profile_bluesky_url, :string
    add_column :users, :profile_linkedin_url, :string
    add_column :users, :profile_discord_url, :string
    add_column :users, :profile_website_url, :string
  end
end

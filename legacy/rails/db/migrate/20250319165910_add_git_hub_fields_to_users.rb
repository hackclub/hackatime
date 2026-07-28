class AddGitHubFieldsToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :github_uid, :string
    add_column :users, :github_avatar_url, :string
    add_column :users, :github_access_token, :text
    add_column :users, :github_username, :string
  end
end

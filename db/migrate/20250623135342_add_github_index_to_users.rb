class AddGithubIndexToUsers < ActiveRecord::Migration[8.0]
  def change
    add_index :users, [ :github_uid, :github_access_token ],
              name: "index_users_on_github_uid_and_access_token"
  end
end

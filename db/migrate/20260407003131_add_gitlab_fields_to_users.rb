class AddGitlabFieldsToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :gitlab_uid, :string
    add_column :users, :gitlab_avatar_url, :string
    add_column :users, :gitlab_access_token, :text
    add_column :users, :gitlab_username, :string

    add_index :users, [ :gitlab_uid, :gitlab_access_token ],
              name: "index_users_on_gitlab_uid_and_access_token"
    add_index :users, :gitlab_uid, name: "index_users_on_gitlab_uid"
  end
end

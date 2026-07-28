class RenameAvatarUrlToSlackAvatarUrlOnUsers < ActiveRecord::Migration[8.1]
  def change
    rename_column :users, :avatar_url, :slack_avatar_url
  end
end

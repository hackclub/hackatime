class AddSlackUsernameToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :slack_username, :string
  end
end

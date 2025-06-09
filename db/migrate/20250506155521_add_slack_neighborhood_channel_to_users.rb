class AddSlackNeighborhoodChannelToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :slack_neighborhood_channel, :string, null: true
  end
end

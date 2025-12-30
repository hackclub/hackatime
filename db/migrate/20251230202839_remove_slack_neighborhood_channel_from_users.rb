class RemoveSlackNeighborhoodChannelFromUsers < ActiveRecord::Migration[8.1]
  def change
    remove_column :users, :slack_neighborhood_channel, :string
  end
end

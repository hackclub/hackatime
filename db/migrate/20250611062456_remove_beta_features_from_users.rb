class RemoveBetaFeaturesFromUsers < ActiveRecord::Migration[8.0]
  def change
    remove_column :users, :beta_features, :text
  end
end
